import Cocoa

class NotchWindow: NSPanel {
    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )
        
        configureWindow()
    }
    
    private func configureWindow() {
        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        // Places window in front of menu bar
        level = .mainMenu + 3
        hasShadow = false
        isReleasedWhenClosed = false
        
        // Force dark appearance
        appearance = NSAppearance(named: .darkAqua)
        
        // Key behaviors for floating above fullscreen apps and all spaces
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle
        ]
        
        // Optionally hide from screen sharing/recording (like Boring Notch did optionally)
        // sharingType = .none 
    }
    
    // Do not steal focus
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
