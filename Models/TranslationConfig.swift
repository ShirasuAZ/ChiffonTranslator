import Foundation

enum ASREngine: String, CaseIterable, Identifiable, Codable {
    case apple = "Apple Native"
    
    var id: String { self.rawValue }
}

enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case api = "OpenAI Compatible API"
    
    var id: String { self.rawValue }
}

struct TranslationConfig: Codable {
    var sourceLanguage: Language = .english
    var targetLanguage: Language = .chinese
    var asrEngine: ASREngine = .apple
    var llmProvider: LLMProvider = .api
    
    var apiUrl: String = ""
    var apiKey: String = ""
    var modelName: String = ""
    
    var windowOpacity: Double = 0.9
    
    // Persistence
    private static let userDefaultsKey = "savedTranslationConfig"
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
    
    static func load() -> TranslationConfig {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           var config = try? JSONDecoder().decode(TranslationConfig.self, from: data) {
            
            // Migration for legacy language codes
            if let fixedSource = Language.all.first(where: { $0.name == config.sourceLanguage.name }) {
                config.sourceLanguage = fixedSource
            }
            if let fixedTarget = Language.all.first(where: { $0.name == config.targetLanguage.name }) {
                config.targetLanguage = fixedTarget
            }
            
            return config
        }
        return TranslationConfig()
    }
}
