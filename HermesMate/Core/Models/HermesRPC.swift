import Foundation

// MARK: - JSON-RPC 2.0 消息模型

/// 向 Hermes tui_gateway 发送的请求
struct RPCRequest: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: JSONValue

    init(id: String = UUID().uuidString, method: String, params: JSONValue = .object([:])) {
        self.id = id
        self.method = method
        self.params = params
    }
}

/// 从 Hermes 收到的响应（可能是成功响应、错误响应或服务器推送事件）
enum RPCMessage {
    case response(id: String, result: JSONValue)
    case error(id: String?, code: Int, message: String)
    case event(type: String, sessionId: String?, payload: JSONValue)

    init?(from dict: [String: JSONValue]) {
        let method = dict["method"]?.stringValue
        let id = dict["id"]?.stringValue

        if method == "event" {
            // 服务器推送事件
            guard case .object(let params) = dict["params"] else { return nil }
            let eventType = params["type"]?.stringValue ?? "unknown"
            let sessionId = params["session_id"]?.stringValue
                         ?? params["params"]?["session_id"]?.stringValue
            self = .event(type: eventType, sessionId: sessionId, payload: dict["params"] ?? .null)
        } else if let resultVal = dict["result"] {
            // 成功响应
            self = .response(id: id ?? "", result: resultVal)
        } else if case .object(let errObj) = dict["error"] {
            // 错误响应
            let code = errObj["code"]?.intValue ?? -1
            let msg = errObj["message"]?.stringValue ?? "unknown error"
            self = .error(id: id, code: code, message: msg)
        } else {
            return nil
        }
    }
}

// MARK: - 通用 JSON 值类型（避免引入 AnyCodable 依赖）

indirect enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    // MARK: Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(Bool.self) { self = .bool(v); return }
        if let v = try? container.decode(Int.self) { self = .int(v); return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? container.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown JSON type"))
    }

    // MARK: Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:            try container.encodeNil()
        case .bool(let v):    try container.encode(v)
        case .int(let v):     try container.encode(v)
        case .double(let v):  try container.encode(v)
        case .string(let v):  try container.encode(v)
        case .array(let v):   try container.encode(v)
        case .object(let v):  try container.encode(v)
        }
    }

    // MARK: Convenience Accessors

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var intValue: Int? {
        if case .int(let v) = self { return v }
        if case .double(let v) = self { return Int(v) }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let v) = self { return v }
        if case .int(let v) = self { return Double(v) }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let v) = self { return v }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let v) = self { return v }
        return nil
    }

    subscript(key: String) -> JSONValue? {
        objectValue?[key]
    }
}
