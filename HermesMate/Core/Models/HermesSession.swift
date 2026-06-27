import Foundation

// MARK: - Session 数据模型

struct HermesSession: Identifiable, Sendable, Equatable {
    let id: String          // Hermes session_id
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var isActive: Bool
    var messages: [ChatMessage]

    init(id: String, title: String = "新对话", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isActive = true
        self.messages = []
    }

    static func from(rpcResult: JSONValue) -> HermesSession? {
        guard let obj = rpcResult.objectValue,
              let sid = obj["session_id"]?.stringValue else { return nil }
        let title = obj["title"]?.stringValue ?? obj["goal"]?.stringValue ?? "对话"
        return HermesSession(id: sid, title: title)
    }
}

// MARK: - 消息模型

struct ChatMessage: Identifiable, Sendable, Equatable {
    let id: String
    var role: Role
    var content: String
    let timestamp: Date
    var isStreaming: Bool

    enum Role: String, Sendable {
        case user
        case assistant
        case system
        case tool
    }

    init(id: String = UUID().uuidString, role: Role, content: String, timestamp: Date = Date(), isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }
}
