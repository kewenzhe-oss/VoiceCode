import AppKit
import SwiftUI

class IndicatorWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 80),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.hasShadow = false
        self.contentView = NSHostingView(rootView: DesktopIndicatorView(state: TranscriptionState.shared))
        
        // Position at Bottom Right (User Request)
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            // Right aligned with 20pt padding
            let x = frame.maxX - 360 - 20 
            // Bottom aligned with 20pt padding
            let y = frame.minY + 20 
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
