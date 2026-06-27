import Foundation
import SwiftUI
import Combine
import os

enum NotchSizeState {
    case closed
    case hovering
    case openSummary
    case openDetail
}

enum AgentActivityState {
    case idle
    case thinking
    case speaking
    case toolRunning
    case waitingApproval
}

@MainActor
class NotchStateCoordinator: ObservableObject {
    private let logger = Logger(subsystem: "com.hermesmate.app", category: "NotchStateCoordinator")
    
    @Published var notchSize: NotchSizeState = .closed {
        didSet {
            logger.debug("DEBUG: notchSize changed to \(String(describing: self.notchSize))")
        }
    }
    @Published var activityState: AgentActivityState = .idle {
        didSet {
            logger.debug("DEBUG: activityState changed to \(String(describing: self.activityState))")
        }
    }
    @Published var currentText: String = ""
    @Published var currentToolName: String = ""
    @Published var isManuallyExpanded: Bool = false
    
    private var eventStreamTask: Task<Void, Never>?
    private var closeDelayTask: Task<Void, Never>?
    private var isHoveringArea: Bool = false
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    init(eventBus: EventBus) {
        startListening(to: eventBus)
        setupEventMonitors()
    }
    
    private func startListening(to eventBus: EventBus) {
        eventStreamTask = Task {
            for await event in await eventBus.subscribe() {
                self.handleEvent(event)
            }
        }
    }
    
    private func setupEventMonitors() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.handleOutsideClick()
        }
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let window = event.window, window.level == .mainMenu + 3 {
                // Clicked inside Notch Window, ignore
            } else {
                self?.handleOutsideClick()
            }
            return event
        }
    }
    
    private func handleOutsideClick() {
        Task { @MainActor in
            if self.isManuallyExpanded {
                self.isManuallyExpanded = false
                self.closeNotch()
            }
        }
    }
    
    // MARK: - Interactions
    
    func handleHover(isHovering: Bool) {
        self.isHoveringArea = isHovering
        
        if isHovering {
            if !isManuallyExpanded {
                closeDelayTask?.cancel()
            }
            
            if notchSize == .closed {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    notchSize = .hovering
                }
            }
        } else {
            // Mouse left the area
            if notchSize == .hovering {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    notchSize = .closed
                }
            } else if notchSize != .closed {
                if !isManuallyExpanded {
                    scheduleClose(after: 3.0)
                }
            }
        }
    }
    
    func handleTap() {
        // Expand and keep open permanently until clicked outside
        isManuallyExpanded = true
        closeDelayTask?.cancel()
        
        withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
            if notchSize != .openDetail {
                notchSize = .openDetail
            }
        }
    }
    
    func closeNotch() {
        if notchSize != .closed {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                notchSize = .closed
            }
        }
    }
    
    // MARK: - Event Handling
    
    private func handleEvent(_ event: HermesEvent) {
        logger.debug("DEBUG: Received event type: \(String(describing: event.type)), current notchSize: \(String(describing: self.notchSize)), activityState: \(String(describing: self.activityState))")
        
        switch event.type {
        case .userPromptSubmitted:
            closeDelayTask?.cancel() // 思考开始，无限期等待，不要自动收起
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                activityState = .thinking
                currentText = "思考中..."
                if notchSize != .closed { notchSize = .closed }
            }
            
        case .agentThinkingStarted:
            closeDelayTask?.cancel() // 思考中，无限期等待
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                activityState = .thinking
                currentText = "思考中..."
                if notchSize != .openSummary { notchSize = .openSummary }
            }
            
        case .assistantMessageStarted:
            // 收到 start 时，模型其实还在思考，还没真正吐出文字
            // 保持 thinking 状态，灵动岛继续显示 summary，直到有 delta 过来
            closeDelayTask?.cancel()
            break
            
        case .assistantMessageDelta(let text):
            withAnimation(.smooth) {
                // 真正有文字出来时，才变蓝灯并拉下灵动岛
                if activityState != .speaking {
                    activityState = .speaking
                    currentText = ""
                }
                currentText += text
                if notchSize != .openSummary && notchSize != .openDetail { notchSize = .openSummary }
            }
            scheduleClose(after: 4.0) // 每次更新文字，重置4秒倒计时
            
        case .assistantMessageCompleted:
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                activityState = .idle
            }
            scheduleClose(after: 4.0) // 完成后，4秒强制收回
            
        case .toolCallStarted(let name):
            closeDelayTask?.cancel() // 工具运行中，不自动收起
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                activityState = .toolRunning // 仍保留内部状态为 toolRunning
                currentToolName = name
                if notchSize != .openSummary { notchSize = .openSummary }
            }
            
        case .toolCallNeedsApproval:
            closeDelayTask?.cancel() // 等待审批，绝对不能自动收起
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                activityState = .waitingApproval
                // 需要用户确认时才拉下来显示详细信息
                if notchSize != .openDetail { notchSize = .openSummary }
            }
            
        case .toolCallSucceeded, .toolCallFailed:
            // 工具执行完毕，如果在思考，可以保持，或者等待下一个事件
            break
            
        case .sessionEnded, .taskCompleted, .taskFailed:
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                activityState = .idle
            }
            scheduleClose(after: 4.0)
            
        default:
            // 忽略其他事件，不干扰现有的倒计时
            break
        }
    }
    
    private func scheduleClose(after seconds: TimeInterval) {
        guard !isManuallyExpanded else { return }
        closeDelayTask?.cancel()
        
        closeDelayTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.45, dampingFraction: 1.0)) {
                self.activityState = .idle
                if !self.isHoveringArea {
                    self.notchSize = .closed
                } else {
                    self.notchSize = .hovering
                }
            }
        }
    }
    
    deinit {
        eventStreamTask?.cancel()
        closeDelayTask?.cancel()
    }
}
