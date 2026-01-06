import Foundation
import Combine
import AVFoundation

@MainActor
class TranslationManager: ObservableObject {
    static let shared = TranslationManager()
    
    @Published var originalText: String = "Waiting for audio..."
    @Published var translatedText: String = ""
    @Published var isRunning: Bool = false
    
    private let audioCapture = AudioCaptureService()
    private let speechRecognizer = SpeechRecognizerService()
    private let llmService = LLMService()
    
    private var currentConfig: TranslationConfig?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Bind Audio Capture -> Speech Recognizer
        audioCapture.onAudioBuffer = { [weak self] buffer in
            self?.speechRecognizer.processAudioBuffer(buffer)
        }
        
        // Bind Speech Recognizer -> LLM
        speechRecognizer.onSentenceEnd = { [weak self] sentence in
            guard let self = self else { return }
            self.handleNewSentence(sentence)
        }
        
        // Observe real-time partial results for UI
        speechRecognizer.$recognizedText
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                // Only update if not empty to avoid clearing the previous sentence 
                // while waiting for the next one
                if !text.isEmpty {
                    self?.originalText = text
                }
            }
            .store(in: &cancellables)
    }
    
    func start(app: AppInfo, config: TranslationConfig) async {
        self.currentConfig = config
        self.isRunning = true
        self.originalText = "Listening to \(app.name)..."
        self.translatedText = ""
        
        do {
            try await audioCapture.startCapture(app: app)

            // Use the 2-letter code directly (e.g. "en", "zh", "ja") as preferred by newer system APIs
            let languageCode = config.sourceLanguage.code
            
            print("Starting ASR with language: \(languageCode)")
            speechRecognizer.startRecognition(language: languageCode)
        } catch {
            self.originalText = "Error: \(error.localizedDescription)"
            self.isRunning = false
        }
    }
    
    func stop() async {
        await audioCapture.stopCapture()
        speechRecognizer.stopRecognition()
        self.isRunning = false
        self.originalText = "Stopped."
    }
    
    private func handleNewSentence(_ text: String) {
        guard let config = currentConfig else { return }
        
        // Update UI with the full sentence captured
        DispatchQueue.main.async {
            self.originalText = text
            self.translatedText = "" // Clear previous translation for new sentence
        }
        
        // Trigger LLM Translation
        Task {
            await llmService.streamTranslation(text: text, config: config, onChunk: { chunk in
                self.translatedText += chunk
            }, onComplete: {
                // Translation done for this sentence
            }, onError: { errorMsg in
                DispatchQueue.main.async {
                    self.translatedText = "Translation Error: \(errorMsg)"
                }
            })
        }
    }
}
