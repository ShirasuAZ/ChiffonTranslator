import Foundation
import AppKit
import UniformTypeIdentifiers

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let processID: Int32
    let name: String
    let icon: NSImage?
    let bundleIdentifier: String
    
    // Mock data for preview
    static let mocks: [AppInfo] = [
        AppInfo(processID: 0, name: "Zoom", icon: NSWorkspace.shared.icon(for: .application), bundleIdentifier: "us.zoom.xos"),
        AppInfo(processID: 0, name: "Chrome", icon: NSWorkspace.shared.icon(for: .application), bundleIdentifier: "com.google.Chrome"),
        AppInfo(processID: 0, name: "YouTube", icon: NSWorkspace.shared.icon(for: .application), bundleIdentifier: "com.google.Chrome.app.youtube"),
        AppInfo(processID: 0, name: "Spotify", icon: NSWorkspace.shared.icon(for: .application), bundleIdentifier: "com.spotify.client")
    ]
}
