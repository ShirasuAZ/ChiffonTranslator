import Foundation
import ScreenCaptureKit
import AppKit

class AppDiscoveryService {
    static let shared = AppDiscoveryService()
    
    func getRunningApplications() async throws -> [AppInfo] {
        // Fetch shareable content (apps and windows)
        // onScreenWindowsOnly: false allows us to capture minimized or background apps (like Spotify/Music)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        
        let apps = content.applications.compactMap { scApp -> AppInfo? in
            // Filter by checking NSRunningApplication properties
            guard let runningApp = NSRunningApplication(processIdentifier: scApp.processID) else { return nil }
            
            // Only include "Regular" apps (apps that appear in the Dock)
            // This filters out background processes, menu bar apps, and system daemons
            guard runningApp.activationPolicy == .regular else { return nil }
            
            // Filter out our own app
            guard scApp.bundleIdentifier != Bundle.main.bundleIdentifier else { return nil }
            
            return AppInfo(
                processID: scApp.processID,
                name: scApp.applicationName,
                icon: runningApp.icon,
                bundleIdentifier: scApp.bundleIdentifier
            )
        }
        
        // Remove duplicates (sometimes SC returns multiple entries for same app if multiple windows?)
        // Actually SCShareableContent.applications returns list of SCRunningApplication, which are unique by pid.
        // But we might want to sort them.
        return apps.sorted { $0.name < $1.name }
    }
}
