import Foundation

// MARK: - 标准事件模型
// 所有 UI 只消费此模型，不直接接触 Hermes 原始 payload

struct HermesEvent: Identifiable, Sendable {
    let id: String
    let sessionId: String?
    let timestamp: Date
    let source: EventSource
    let type: EventType
    let title: String
    let summary: String
    let riskLevel: RiskLevel
    let payload: JSONValue

    // MARK: - 嵌套类型

    enum EventSource: String, Sendable {
        case hermes
        case hermesmate
    }

    enum RiskLevel: String, Sendable {
        case none, low, medium, high, critical
    }

    // MARK: - 事件类型枚举（覆盖 final_architecture_plan 所有类型）

    enum EventType: Sendable, Equatable {
        // Session 生命周期
        case sessionStarted
        case sessionEnded
        case sessionInfo(model: String, contextUsed: Int?, contextMax: Int?, contextPercent: Double?)

        // 用户输入
        case userPromptSubmitted

        // Agent 思考
        case agentThinkingStarted
        case agentThinkingEnded

        // 消息流
        case assistantMessageStarted
        case assistantMessageDelta(text: String)
        case assistantMessageCompleted(text: String)

        // 工具调用
        case toolCallStarted(toolName: String)
        case toolCallStreaming
        case toolCallNeedsApproval(toolName: String, params: JSONValue)
        case toolCallApproved
        case toolCallRejected
        case toolCallSucceeded
        case toolCallFailed(error: String)

        // 记忆
        case memoryUpdateProposed
        case memoryUpdateApproved
        case memoryUpdateRejected
        case memoryUpdated

        // 技能
        case skillUpdateProposed
        case skillUpdateApproved
        case skillUpdateRejected
        case skillUpdated

        // 任务
        case taskStarted
        case taskCompleted
        case taskFailed
        case taskNeedsUserInput

        // 文件
        case fileDraggedToPet
        case fileAttachedToSession

        // UI 事件
        case notchExpanded
        case notchCollapsed
        case petClicked
        case petDragged
        case petStateChanged

        // 网关
        case gatewayReady
        case gatewayDisconnected

        // 未知/错误
        case error(message: String)
        case unknown(rawType: String)
    }
}

// MARK: - 工厂方法：从 RPCMessage 构建标准事件

extension HermesEvent {
    static func from(rpcEvent: RPCMessage, sessionId: String?) -> HermesEvent? {
        guard case .event(let typeStr, let sid, let payload) = rpcEvent else { return nil }
        return HermesEvent(
            id: UUID().uuidString,
            sessionId: sid ?? sessionId,
            timestamp: Date(),
            source: .hermes,
            type: EventType(rawString: typeStr, payload: payload),
            title: typeStr.humanReadable,
            summary: "",
            riskLevel: .none,
            payload: payload
        )
    }
}

// MARK: - EventType 从字符串构建

extension HermesEvent.EventType {
    init(rawString: String, payload: JSONValue) {
        // `payload` 实际上是 RPC 报文中的 `params` 对象
        // 真正的业务数据通常包裹在 `params["payload"]` 内部
        let data = payload["payload"] ?? payload

        switch rawString {
        // Gateway
        case "gateway.ready":             self = .gatewayReady
        case "gateway.disconnected":      self = .gatewayDisconnected
        // Session
        case "session.started":           self = .sessionStarted
        case "session.ended":             self = .sessionEnded
        case "session.info":
            let usage = data["usage"]
            let used = usage?["context_used"]?.intValue
            let max = usage?["context_max"]?.intValue
            let percent = usage?["context_percent"]?.doubleValue
            self = .sessionInfo(model: data["model"]?.stringValue ?? "Hermes Agent", contextUsed: used, contextMax: max, contextPercent: percent)
        // Thinking
        case "thinking.started":          self = .agentThinkingStarted
        case "thinking.ended":            self = .agentThinkingEnded
        // Message
        case "message.start":             self = .assistantMessageStarted
        case "message.delta":
            let text = data["delta"]?.stringValue
                    ?? data["text"]?.stringValue
                    ?? data["content"]?.stringValue ?? ""
            self = .assistantMessageDelta(text: text)
        case "message.complete":
            let text = data["text"]?.stringValue
                    ?? data["content"]?.stringValue ?? ""
            self = .assistantMessageCompleted(text: text)
        // Tool calls
        case "tool.start", "tool.generating":
            let name = data["tool"]?.stringValue ?? data["name"]?.stringValue ?? "tool"
            self = .toolCallStarted(toolName: name)
        case "approval.request":
            let name = data["tool"]?.stringValue ?? "tool"
            self = .toolCallNeedsApproval(toolName: name, params: data)
        case "tool.call.approved":        self = .toolCallApproved
        case "tool.call.rejected":        self = .toolCallRejected
        case "tool.complete":             self = .toolCallSucceeded
        case "tool.call.failed":
            let err = data["error"]?.stringValue ?? "unknown"
            self = .toolCallFailed(error: err)
        // Memory
        case "memory.update.proposed":    self = .memoryUpdateProposed
        case "memory.updated":            self = .memoryUpdated
        // Task
        case "task.started":              self = .taskStarted
        case "task.completed":            self = .taskCompleted
        case "task.failed":               self = .taskFailed
        case "task.needs_user_input":     self = .taskNeedsUserInput
        // File
        case "file.dragged_to_pet":       self = .fileDraggedToPet
        case "file.attached_to_session":  self = .fileAttachedToSession
        // Error
        case "error":
            let err = payload["message"]?.stringValue ?? "unknown error"
            self = .error(message: err)
        // Default
        default:                          self = .unknown(rawType: rawString)
        }
    }
}

private extension String {
    var humanReadable: String {
        self.replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
