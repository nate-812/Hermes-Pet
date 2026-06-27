import SwiftUI
import AppKit

// MARK: - Desktop Pet Panel
//
// 使用 NSPanel (.nonactivatingPanel) 而非 NSWindow 的原因：
// - 专为悬浮辅助窗口设计，点击时不激活 App、不抢夺其他 App 焦点
// - PetHostingView 通过 mouseDownCanMoveWindow 配合 isMovableByWindowBackground 实现拖拽
// - 单击通过 mouseUp.clickCount > 0 检测，由 onTap 回调通知外部
class DesktopPetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// 单击回调，由 AppDelegate 在创建时注入，避免跨 actor 直接调用
    var onTap: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        // clickCount > 0：点击（非拖拽结束）；clickCount == 0：拖拽结束
        if event.clickCount > 0 {
            onTap?()
        }
    }
}

// MARK: - PetHostingView
// 子类化 NSHostingView，在 contentView 层直接拦截鼠标事件，
// 确保事件在 SwiftUI gesture 系统之前被处理。
class PetHostingView: NSHostingView<DesktopPetView> {

    // 应用非 active 时也能响应第一次点击（nonactivatingPanel 配套）
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // 配合 isMovableByWindowBackground，让系统内置拖拽生效
    override var mouseDownCanMoveWindow: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        window?.mouseDragged(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        window?.mouseUp(with: event)
    }
}

// MARK: - Desktop Pet View
struct DesktopPetView: View {
    @ObservedObject var coordinator: NotchStateCoordinator

    var body: some View {
        VideoPetEngine(state: coordinator.activityState)
            .frame(width: 310, height: 175)
            // 禁止 SwiftUI 内部 gesture recognizer 竞争事件
            .allowsHitTesting(false)
    }
}
