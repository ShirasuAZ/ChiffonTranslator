import SwiftUI

struct ModelSettingsView: View {
    @Binding var config: TranslationConfig
    var onSave: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // ASR Engine (Read Only since only one option)
            HStack {
                Label("ASR Engine", systemImage: "waveform")
                Spacer()
                Text(config.asrEngine.rawValue)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // LLM Settings
            VStack(alignment: .leading, spacing: 8) {
                Label("LLM Settings", systemImage: "brain")
                    .font(.headline)
                
                TextField("API URL", text: $config.apiUrl)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("API Key", text: $config.apiKey)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Model Name", text: $config.modelName)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: onSave) {
                    Text("Save Configuration")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
    }
}
