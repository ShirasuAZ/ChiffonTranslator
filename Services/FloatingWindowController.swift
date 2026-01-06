import SwiftUI
import AppKit
import Combine

class FloatingWindowController: NSObject, ObservableObject {
    static let shared = FloatingWindowController()
    
    @Published var backgroundOpacity: Double = 0.9
    private var window: NSPanel?
    
    private override init() {
        super.init()
    }
    
    func show() {
        if window == nil {
            createWindow()
        }
        window?.orderFront(nil)
    }
    
    func hide() {
        window?.orderOut(nil)
    }
    
    func setOpacity(_ opacity: Double) {
        self.backgroundOpacity = opacity
        window?.alphaValue = 1.0 // Ensure window itself is opaque
    }
    
    private func createWindow() {
        let floatingView = FloatingBarView()
        let hostingController = NSHostingController(rootView: floatingView)
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 120),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable], 
            backing: .buffered,
            defer: false
        )
        
        panel.contentViewController = hostingController
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true 
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Set min size
        panel.minSize = NSSize(width: 200, height: 80)
        panel.center()
        
        self.window = panel
    }
}
