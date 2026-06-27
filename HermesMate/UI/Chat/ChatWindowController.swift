import AppKit
import SwiftUI

// MARK: - ChatWindowController
// 管理聊天窗口的显示/隐藏，持有 NSWindow

@MainActor
final class ChatWindowController {

    private var window: NSWindow?
    private let agentBridge: AgentBridge

    init(agentBridge: AgentBridge) {
        self.agentBridge = agentBridge
    }

    func showWindow() {
        // nonactivatingPanel 点击时 App 不会被激活，
        // 必须先 activate 再 makeKeyAndOrderFront
        NSApp.activate(ignoringOtherApps: true)

        if let window = window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let chatView = ChatView(agentBridge: agentBridge)
        let hostingController = NSHostingController(rootView: chatView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "HermesMate"
        window.setContentSize(NSSize(width: 910, height: 560))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.minSize = NSSize(width: 700, height: 350)
        window.level = .normal
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }
}
