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

        let dashboardView = DashboardView(agentBridge: agentBridge)
        let hostingController = NSHostingController(rootView: dashboardView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        let panel = NSPanel(contentViewController: hostingController)
        panel.title = "HermesMate Dashboard"
        panel.setContentSize(NSSize(width: 910, height: 560))
        panel.styleMask = [.nonactivatingPanel, .fullSizeContentView, .closable, .resizable, .titled]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isOpaque = false
        panel.minSize = NSSize(width: 800, height: 500)
        panel.level = .floating
        panel.hidesOnDeactivate = true // Light dismiss: hide when clicking outside
        
        // Add Esc key monitor for explicit close (from frontend skill guidance)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak panel] event in
            if event.keyCode == 53 { // 53 is Esc key
                panel?.close()
                return nil
            }
            return event
        }

        panel.center()
        panel.makeKeyAndOrderFront(nil)

        self.window = panel
    }
}
