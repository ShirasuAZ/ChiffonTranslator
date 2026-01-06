import SwiftUI

struct LanguageConfigView: View {
    @Binding var sourceLanguage: Language
    @Binding var targetLanguage: Language
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("Source")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $sourceLanguage) {
                    ForEach(Language.all) { lang in
                        Text(lang.name).tag(lang)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
            
            Image(systemName: "arrow.right")
                .foregroundStyle(.secondary)
                .padding(.top, 16)
            
            VStack(alignment: .leading) {
                Text("Target")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $targetLanguage) {
                    ForEach(Language.all) { lang in
                        Text(lang.name).tag(lang)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.05))
        .cornerRadius(12)
    }
}
