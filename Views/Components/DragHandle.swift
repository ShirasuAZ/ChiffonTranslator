import SwiftUI
import AppKit

struct DragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    class DraggableView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        
        // Allow clicking on this view to activate the window and handle the event immediately
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return true
        }
        
        override func mouseDown(with event: NSEvent) {
            // Initiate window dragging
            window?.performDrag(with: event)
        }
    }
}
