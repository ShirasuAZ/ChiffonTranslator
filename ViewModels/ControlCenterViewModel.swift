import SwiftUI
import Combine

class ControlCenterViewModel: ObservableObject {
    @Published var runningApps: [AppInfo] = []
    @Published var selectedApp: AppInfo?
    @Published var config = TranslationConfig.load()
    @Published var isFloatingBarVisible: Bool = false
    
    init() {
        // Initial empty state, will be populated by refreshApps()
    }
    
    func saveConfig() {
        config.save()
    }
    
    @MainActor
    func refreshApps() async {
        do {
            let apps = try await AppDiscoveryService.shared.getRunningApplications()
            self.runningApps = apps
            
            // If no app is selected, or the selected app is no longer running, select the first one
            if selectedApp == nil || !apps.contains(where: { $0.id == selectedApp?.id }) {
                self.selectedApp = apps.first
            }
        } catch {
            print("Failed to fetch running apps: \(error)")
            // Clear apps on error or permission denied
            self.runningApps = []
            self.selectedApp = nil
        }
    }
    
    func toggleFloatingBar() {
        isFloatingBarVisible.toggle()
        
        Task {
            if isFloatingBarVisible {
                if let app = selectedApp {
                    await TranslationManager.shared.start(app: app, config: config)
                }
            } else {
                await TranslationManager.shared.stop()
            }
        }
    }
}
