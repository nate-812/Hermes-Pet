import AppKit
import SwiftUI

// MARK: - MenuBarController
// NSStatusItem 菜单栏常驻入口

@MainActor
final class MenuBarController {

    private var statusItem: NSStatusItem?
    private var contextMenu: NSMenu?
    private let agentBridge: AgentBridge
    private var stateObserverTask: Task<Void, Never>?

    init(agentBridge: AgentBridge) {
        self.agentBridge = agentBridge
        setup()
        observeConnectionState()
    }

    deinit {
        stateObserverTask?.cancel()
    }

    // MARK: - Setup

    private func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }
        button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "HermesMate")
        button.image?.isTemplate = true

        let menu = NSMenu()

        // 连接状态（动态更新）
        let stateItem = NSMenuItem(title: "未连接", action: nil, keyEquivalent: "")
        stateItem.tag = MenuTag.connectionState.rawValue
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        menu.addItem(.separator())

        // 打开聊天窗口
        let chatItem = NSMenuItem(
            title: "打开聊天窗口",
            action: #selector(openChat),
            keyEquivalent: "k"
        )
        chatItem.keyEquivalentModifierMask = [.command, .shift]
        chatItem.target = self
        menu.addItem(chatItem)

        menu.addItem(.separator())

        // 退出
        let quitItem = NSMenuItem(
            title: "退出 HermesMate",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.contextMenu = menu
        
        button.action = #selector(statusBarButtonClicked(sender:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: - 观察连接状态

    private func observeConnectionState() {
        stateObserverTask = Task { [weak self] in
            guard let self else { return }
            // 使用 withObservationTracking 或直接订阅
            // 由于 AgentBridge 是 @MainActor + @Published，用轮询观察
            while !Task.isCancelled {
                let state = self.agentBridge.connectionState
                self.updateStatusItem(state: state)
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func updateStatusItem(state: AgentBridge.BridgeConnectionState) {
        guard let menu = contextMenu,
              let stateItem = menu.item(withTag: MenuTag.connectionState.rawValue)
        else { return }

        stateItem.title = state.displayText

        // 图标随状态变化
        let iconName: String
        switch state {
        case .connected:     iconName = "sparkles"
        case .connecting:    iconName = "sparkle"
        case .disconnected:  iconName = "moon.zzz"
        case .failed:        iconName = "exclamationmark.triangle"
        }
        statusItem?.button?.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "HermesMate")
        statusItem?.button?.image?.isTemplate = true
    }

    // MARK: - Actions

    var onOpenChat: (() -> Void)?

    @objc private func statusBarButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            if let menu = contextMenu {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
            }
        } else {
            openChat()
        }
    }

    @objc private func openChat() {
        onOpenChat?()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - 枚举

    private enum MenuTag: Int {
        case connectionState = 100
    }
}
