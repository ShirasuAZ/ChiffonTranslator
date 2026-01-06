import Foundation

struct Language: Identifiable, Hashable, Codable {
    let code: String
    let name: String
    
    var id: String { code }
    
    static let all: [Language] = [
        Language(code: "en-US", name: "English"),
        Language(code: "zh-CN", name: "Chinese"),
        Language(code: "ja-JP", name: "Japanese"),
        Language(code: "ko-KR", name: "Korean"),
        Language(code: "es-ES", name: "Spanish"),
        Language(code: "fr-FR", name: "French"),
        Language(code: "de-DE", name: "German")
    ]
    
    static let english = Language(code: "en-US", name: "English")
    static let chinese = Language(code: "zh-CN", name: "Chinese")
    static let japanese = Language(code: "ja-JP", name: "Japanese")
    static let korean = Language(code: "ko-KR", name: "Korean")
    static let spanish = Language(code: "es-ES", name: "Spanish")
    static let french = Language(code: "fr-FR", name: "French")
    static let german = Language(code: "de-DE", name: "German")
    
}
