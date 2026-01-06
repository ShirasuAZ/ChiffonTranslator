import SwiftUI

struct FloatingBarView: View {
    @StateObject private var manager = TranslationManager.shared
    @ObservedObject private var windowController = FloatingWindowController.shared
    @State private var isHovering = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Drag Handle
            ZStack {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 4, height: 24)
                
                // Put DragHandle on TOP so it captures the clicks
                DragHandle()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 24)
            .contentShape(Rectangle())
            
            // Main Content
            VStack(alignment: .leading, spacing: 4) {
                Text(manager.originalText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                Text(manager.translatedText)
                    .font(.system(size: 24, weight: .bold, design: .rounded)) // San Francisco Pro Rounded
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black.opacity(windowController.backgroundOpacity))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .frame(minWidth: 200, maxWidth: .infinity, minHeight: 80, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        Color.blue // Background to test transparency
        FloatingBarView()
            .padding()
    }
}
