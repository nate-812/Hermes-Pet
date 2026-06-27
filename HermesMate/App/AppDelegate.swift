import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Core Services（单例，全生命周期）
    let agentBridge = AgentBridge()

    // MARK: - UI Controllers
    private(set) var menuBarController: MenuBarController?
    private(set) var chatWindowController: ChatWindowController?
    
    // Notch Components
    private(set) var notchCoordinator: NotchStateCoordinator?
    private(set) var notchWindow: NotchWindow?
    
    // Desktop Pet Components
    private(set) var desktopPetPanel: DesktopPetPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 不显示 Dock 图标
        NSApp.setActivationPolicy(.accessory)

        // 初始化菜单栏
        let mbController = MenuBarController(agentBridge: agentBridge)
        mbController.onOpenChat = { [weak self] in
            self?.openChatWindow()
        }
        menuBarController = mbController

        // 初始化聊天窗口（懒加载，首次打开时才 show）
        chatWindowController = ChatWindowController(agentBridge: agentBridge)
        
        // 初始化灵动岛 Notch
        setupNotchWindow()
        
        // 初始化桌面悬浮宠物
        setupDesktopPet()

        // 启动 Hermes 连接
        Task {
            await agentBridge.start()
        }
    }
    
    private func setupNotchWindow() {
        let coordinator = NotchStateCoordinator(eventBus: agentBridge.eventBus)
        self.notchCoordinator = coordinator
        
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        let notchWidth: CGFloat = 500 // 扩大窗口以防阴影或边角被裁剪
        let notchHeight: CGFloat = 300 // 扩大窗口以防详情面板被裁剪
        
        let rect = NSRect(
            x: screenFrame.midX - (notchWidth / 2),
            y: screenFrame.maxY - notchHeight,
            width: notchWidth,
            height: notchHeight
        )
        
        let window = NotchWindow(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 彻底透明化背景，消除任何默认的系统窗口底色阴影和棱角
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        
        window.contentView = NSHostingView(rootView: NotchContentView(coordinator: coordinator))
        window.orderFrontRegardless()
        self.notchWindow = window
        
        // 监听全局点击事件，当点击刘海外部（其他应用或桌面）时自动收起
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak coordinator] _ in
            guard let coord = coordinator, coord.notchSize != .closed else { return }
            Task { @MainActor in
                coord.closeNotch()
            }
        }
        
        // 监听应用内点击事件，当点击自身应用的其他窗口（如聊天窗口）时也收起
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, let coord = self.notchCoordinator, coord.notchSize != .closed {
                // 如果点击的不是刘海窗口本身，则收起刘海
                if event.window != self.notchWindow {
                    Task { @MainActor in
                        coord.closeNotch()
                    }
                }
            }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await agentBridge.stop()
        }
    }

    private func setupDesktopPet() {
        guard let coordinator = self.notchCoordinator else { return }
        
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.frame
        let petSize: CGFloat = 125
        
        let rect = NSRect(
            // 默认放在右下角
            x: screenFrame.maxX - petSize - 50,
            y: screenFrame.minY + 50,
            width: petSize,
            height: petSize
        )
        
        let panel = DesktopPetPanel(contentRect: rect)
        panel.contentView = PetHostingView(rootView: DesktopPetView(coordinator: coordinator))
        panel.onTap = { [weak self] in
            self?.openChatWindow()
        }
        panel.orderFrontRegardless()

        self.desktopPetPanel = panel
    }

    // MARK: - Public API

    func openChatWindow() {
        chatWindowController?.showWindow()
    }
}
