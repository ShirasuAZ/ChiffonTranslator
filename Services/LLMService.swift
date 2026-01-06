import Foundation

class LLMService {
    
    func streamTranslation(
        text: String,
        config: TranslationConfig,
        onChunk: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (String) -> Void
    ) async {
        guard !text.isEmpty else { return }
        guard let url = URL(string: config.apiUrl) else {
            onError("Invalid URL")
            return
        }
        
        // Dynamic Prompt Construction
        let sourceLang = config.sourceLanguage.name
        let targetLang = config.targetLanguage.name
        
        let systemPrompt = """
        You are a professional simultaneous interpreter.
        Translate the following text from \(sourceLang) to \(targetLang).
        Output ONLY the translated text. Do not include notes, explanations, or original text.
        Maintain the tone and nuance of the original speech.
        """
        
        let requestBody: [String: Any] = [
            "model": config.modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "stream": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (result, response) = try await URLSession.shared.bytes(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                onError("Invalid response")
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                var errorText = ""
                for try await line in result.lines {
                    errorText += line
                }
                print("LLM Error Body: \(errorText)")
                
                var displayError = "Server error: \(httpResponse.statusCode) - \(errorText)"
                if httpResponse.statusCode == 404 {
                     displayError += " (Check API URL path)"
                }
                
                onError(displayError)
                return
            }
            
            for try await line in result.lines {
                if line.hasPrefix("data:") {
                    let dataStr = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    
                    if dataStr == "[DONE]" { break }
                    
                    if let data = dataStr.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let delta = choices.first?["delta"] as? [String: Any],
                       let content = delta["content"] as? String {
                        
                        DispatchQueue.main.async {
                            onChunk(content)
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                onComplete()
            }
            
        } catch {
            print("LLM Stream Error: \(error)")
            onError(error.localizedDescription)
        }
    }
}
