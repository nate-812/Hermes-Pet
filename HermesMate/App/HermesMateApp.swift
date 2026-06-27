import SwiftUI
import AppKit

@main
struct HermesMateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // LSUIElement = true，无 Dock 图标，无主窗口
        // 所有 UI 由 AppDelegate 管理（MenuBar / NSPanel）
        Settings {
            EmptyView()
        }
    }
}
