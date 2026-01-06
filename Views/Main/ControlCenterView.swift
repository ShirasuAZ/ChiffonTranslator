import SwiftUI

struct ControlCenterView: View {
    @StateObject private var viewModel = ControlCenterViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 8) {
                    // Top: App Selector
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Select Application")
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                Task { await viewModel.refreshApps() }
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.plain)
                            .help("Refresh App List")
                        }
                        .padding(.horizontal, 8)
                        
                        AppSelectorView(selectedApp: $viewModel.selectedApp, apps: viewModel.runningApps)
                            .padding(.horizontal, 0) // ScrollView inside handles padding
                    }
                    
                    Divider()
                        .padding(.horizontal, 8)
                    
                    // Middle: Language Config
                    LanguageConfigView(
                        sourceLanguage: $viewModel.config.sourceLanguage,
                        targetLanguage: $viewModel.config.targetLanguage
                    )
                    .padding(.horizontal, 8)
                    
                    // Bottom: Model Settings
                    ModelSettingsView(config: $viewModel.config, onSave: viewModel.saveConfig)
                        .padding(.horizontal, 8)
                    
                    // Window Opacity
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Label("Window Opacity", systemImage: "slider.horizontal.3")
                            Spacer()
                            Text("\(Int(viewModel.config.windowOpacity * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        
                        Slider(value: $viewModel.config.windowOpacity, in: 0.2...1.0)
                            .onChange(of: viewModel.config.windowOpacity) { _, newValue in
                                FloatingWindowController.shared.setOpacity(newValue)
                            }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 0)
                }
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Action Button
            Button(action: {
                viewModel.toggleFloatingBar()
            }) {
                HStack {
                    Image(systemName: viewModel.isFloatingBarVisible ? "stop.fill" : "play.fill")
                    Text(viewModel.isFloatingBarVisible ? "Stop Translation" : "Start Translation")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(viewModel.isFloatingBarVisible ? Color.red.opacity(0.8) : Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
        .frame(width: 320, height: 400)
        .background(.ultraThinMaterial) // Frosted glass effect
        .task {
            await viewModel.refreshApps()
        }
        .onChange(of: viewModel.isFloatingBarVisible) { _, isVisible in
            if isVisible {
                FloatingWindowController.shared.setOpacity(viewModel.config.windowOpacity)
                FloatingWindowController.shared.show()
            } else {
                FloatingWindowController.shared.hide()
            }
        }
    }
}

#Preview {
    ControlCenterView()
}
