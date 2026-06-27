import Foundation

// MARK: - AgentBridge
// 统一主交互通道（HermesProvider）和事件监听通道
// 负责：归一化事件 → 推送 EventBus → 维护 SessionStore

@MainActor
final class AgentBridge: ObservableObject {

    // MARK: - 子层

    let provider = HermesProvider()
    let eventBus = EventBus()
    let sessionStore: SessionStore

    // MARK: - 连接状态（UI 可观察）

    @Published private(set) var connectionState: BridgeConnectionState = .disconnected
    @Published private(set) var lastError: String?

    enum BridgeConnectionState: Equatable {
        case disconnected
        case connecting
        case connected(modelName: String?, contextUsed: Int?, contextMax: Int?, contextPercent: Double?)
        case failed(String)

        var displayText: String {
            switch self {
            case .disconnected:     return "未连接"
            case .connecting:       return "连接中…"
            case .connected(let model, let used, let max, let percent): 
                // Return just the model name here, as the progress bar will handle the rest in ChatView
                return model ?? "已连接"
            case .failed(let msg):  return "连接失败：\(msg)"
            }
        }

        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }

    // MARK: - 私有状态

    private var eventListenerTask: Task<Void, Never>?
    private var currentSessionId: String?

    // MARK: - 初始化

    init() {
        self.sessionStore = SessionStore()
    }

    // MARK: - 生命周期

    func start() async {
        connectionState = .connecting
        do {
            try await provider.connect()

            // 启动事件监听循环
            eventListenerTask = Task { [weak self] in
                await self?.listenForEvents()
            }

            // 等待 gateway.ready 事件（在 listenForEvents 里处理）
            // 创建初始 session
            let sessionId = try await provider.createSession()
            currentSessionId = sessionId
            await sessionStore.setActiveSession(id: sessionId)
            connectionState = .connected(modelName: nil, contextUsed: nil, contextMax: nil, contextPercent: nil)

        } catch {
            connectionState = .failed(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    func stop() async {
        eventListenerTask?.cancel()
        await provider.disconnect()
        connectionState = .disconnected
    }

    // MARK: - 消息发送（UI 调用此方法）

    func sendMessage(_ text: String) async throws {
        guard connectionState.isConnected else {
            throw HermesError.notConnected
        }

        // 确保有 active session
        let sessionId: String
        if let sid = currentSessionId {
            sessionId = sid
        } else {
            sessionId = try await provider.createSession()
            currentSessionId = sessionId
            await sessionStore.setActiveSession(id: sessionId)
        }

        // 添加用户消息到 UI（立即显示）
        let userMsg = ChatMessage(role: .user, content: text)
        await sessionStore.addMessage(userMsg, to: sessionId)

        // 发送到 Hermes
        try await provider.submitPrompt(text, sessionId: sessionId)

        // 发布事件到 EventBus
        let event = HermesEvent(
            id: UUID().uuidString,
            sessionId: sessionId,
            timestamp: Date(),
            source: .hermesmate,
            type: .userPromptSubmitted,
            title: "用户发送消息",
            summary: text,
            riskLevel: .none,
            payload: .string(text)
        )
        await eventBus.publish(event)
    }

    /// 响应工具调用审批
    func respondApproval(approvalId: String, approved: Bool) async throws {
        try await provider.respondApproval(approvalId: approvalId, approved: approved)

        let event = HermesEvent(
            id: UUID().uuidString,
            sessionId: currentSessionId,
            timestamp: Date(),
            source: .hermesmate,
            type: approved ? .toolCallApproved : .toolCallRejected,
            title: approved ? "已批准工具调用" : "已拒绝工具调用",
            summary: "",
            riskLevel: .none,
            payload: .object(["approval_id": .string(approvalId), "approved": .bool(approved)])
        )
        await eventBus.publish(event)
    }

    // MARK: - Private: 事件监听循环

    private func listenForEvents() async {
        for await rpcMsg in await provider.eventStream {
            await handleRPCMessage(rpcMsg)
            if Task.isCancelled { break }
        }
    }

    private func handleRPCMessage(_ msg: RPCMessage) async {
        guard case .event(let typeStr, let sid, let payload) = msg else { return }

        let sessionId = sid ?? currentSessionId
        let event = HermesEvent(
            id: UUID().uuidString,
            sessionId: sessionId,
            timestamp: Date(),
            source: .hermes,
            type: HermesEvent.EventType(rawString: typeStr, payload: payload),
            title: typeStr,
            summary: extractSummary(from: payload),
            riskLevel: riskLevel(for: typeStr),
            payload: payload
        )

        // 推送到 EventBus
        await eventBus.publish(event)

        // 更新 SessionStore 状态
        await updateSessionStore(for: event)
    }

    // MARK: - Private: SessionStore 更新

    private func updateSessionStore(for event: HermesEvent) async {
        switch event.type {

        case .assistantMessageStarted:
            // 开始一条流式回复消息
            if let sid = event.sessionId {
                let msg = ChatMessage(
                    id: UUID().uuidString,
                    role: .assistant,
                    content: "",
                    isStreaming: true
                )
                await sessionStore.addMessage(msg, to: sid)
            }

        case .assistantMessageDelta(let text):
            // 追加流式文本
            if let sid = event.sessionId {
                await sessionStore.appendStreamingText(text, sessionId: sid)
            }

        case .assistantMessageCompleted(let text):
            // 流式结束，固化消息
            if let sid = event.sessionId {
                await sessionStore.finalizeStreamingMessage(text, sessionId: sid)
            }

        case .gatewayReady:
            // gateway 已就绪
            if !connectionState.isConnected {
                connectionState = .connected(modelName: nil, contextUsed: nil, contextMax: nil, contextPercent: nil)
            }
            
        case .sessionInfo(let model, let used, let max, let percent):
            connectionState = .connected(modelName: model, contextUsed: used, contextMax: max, contextPercent: percent)

        case .gatewayDisconnected:
            connectionState = .failed("Hermes 进程已退出")

        case .error(let msg):
            if let sid = event.sessionId {
                let chatMsg = ChatMessage(id: UUID().uuidString, role: .system, content: "⚠️ 报错: \(msg)")
                await sessionStore.addMessage(chatMsg, to: sid)
            }

        default:
            break
        }
    }

    // MARK: - Private: 辅助函数

    private func extractSummary(from payload: JSONValue) -> String {
        payload["summary"]?.stringValue
            ?? payload["text"]?.stringValue
            ?? payload["content"]?.stringValue
            ?? payload["delta"]?.stringValue
            ?? ""
    }

    private func riskLevel(for eventType: String) -> HermesEvent.RiskLevel {
        switch eventType {
        case "tool.call.needs_approval": return .high
        case "tool.call.started":        return .medium
        case "memory.update.proposed":   return .low
        default:                         return .none
        }
    }
}


