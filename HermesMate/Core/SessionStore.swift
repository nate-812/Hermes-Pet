import Foundation
import Observation

// MARK: - SessionStore
// @Observable：所有 SwiftUI 视图直接观察，无需手动 @Published

@Observable
@MainActor
final class SessionStore {

    // MARK: - 状态

    private(set) var sessions: [HermesSession] = []
    private(set) var activeSessionId: String?

    var activeSession: HermesSession? {
        sessions.first { $0.id == activeSessionId }
    }

    var activeMessages: [ChatMessage] {
        activeSession?.messages ?? []
    }

    // MARK: - Agent 状态（驱动 UI 动画）

    enum AgentState: Equatable {
        case idle
        case thinking
        case working(toolName: String)
        case waitingApproval(toolName: String, approvalId: String)
        case success
        case failed
        case needsInput
    }

    private(set) var agentState: AgentState = .idle

    // MARK: - Session 管理

    func setActiveSession(id: String) {
        if sessions.first(where: { $0.id == id }) == nil {
            sessions.append(HermesSession(id: id))
        }
        activeSessionId = id
    }

    func addMessage(_ message: ChatMessage, to sessionId: String) {
        guard let idx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[idx].messages.append(message)
        sessions[idx].updatedAt = Date()
    }

    /// 追加流式文字到最后一条 streaming 消息
    func appendStreamingText(_ text: String, sessionId: String) {
        guard let sessionIdx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let msgs = sessions[sessionIdx].messages
        if let lastIdx = msgs.indices.last, msgs[lastIdx].isStreaming {
            sessions[sessionIdx].messages[lastIdx].content += text
        }
    }

    /// 流式结束，固化最后一条消息
    func finalizeStreamingMessage(_ finalText: String, sessionId: String) {
        guard let sessionIdx = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let msgs = sessions[sessionIdx].messages
        if let lastIdx = msgs.indices.last, msgs[lastIdx].isStreaming {
            if !finalText.isEmpty {
                sessions[sessionIdx].messages[lastIdx].content = finalText
            }
            sessions[sessionIdx].messages[lastIdx].isStreaming = false
        }
    }

    // MARK: - AgentState 更新（由 AgentBridge 事件驱动）

    func updateAgentState(from event: HermesEvent) {
        switch event.type {
        case .agentThinkingStarted:
            agentState = .thinking
        case .agentThinkingEnded:
            agentState = .idle
        case .toolCallStarted(let name):
            agentState = .working(toolName: name)
        case .toolCallNeedsApproval(let name, let params):
            let aid = params["approval_id"]?.stringValue ?? UUID().uuidString
            agentState = .waitingApproval(toolName: name, approvalId: aid)
        case .toolCallSucceeded, .toolCallApproved, .toolCallRejected, .toolCallFailed:
            agentState = .idle
        case .taskCompleted, .assistantMessageCompleted:
            agentState = .success
            // 2 秒后回到 idle
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(2))
                if case .success = self?.agentState { self?.agentState = .idle }
            }
        case .taskFailed, .error:
            agentState = .failed
        case .taskNeedsUserInput:
            agentState = .needsInput
        default:
            break
        }
    }
}
