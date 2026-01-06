import Foundation
import Speech
import Combine
import AVFoundation

class SpeechRecognizerService: ObservableObject {
    @Published var recognizedText: String = ""
    
    // Callback for sentence end (silence detected)
    var onSentenceEnd: ((String) -> Void)?
    
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "en"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private var silenceTimer: DispatchSourceTimer?
    private let silenceThreshold: TimeInterval = 0.8
    private var currentLanguage: String = "en"
    
    private let queue = DispatchQueue(label: "com.chiffon.speech.queue")
    private var isFinal = false
    
    func startRecognition(language: String = "en") {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                print("ASR Authorized")
                self.queue.async { [weak self] in
                    self?.startRecognitionInternal(language: language)
                }
            case .denied:
                print("ASR Denied")
            case .restricted:
                print("ASR Restricted")
            case .notDetermined:
                print("ASR Not Determined")
            @unknown default:
                print("ASR Unknown Auth Status")
            }
        }
    }
    
    private func startRecognitionInternal(language: String) {
        self.currentLanguage = language
        stopRecognitionInternal()
        
        let newLocale = Locale(identifier: language)
        // Check if we need to switch recognizer
        if speechRecognizer?.locale.identifier != newLocale.identifier {
            if let newRecognizer = SFSpeechRecognizer(locale: newLocale) {
                speechRecognizer = newRecognizer
                print("Switched ASR to locale: \(language)")
            } else {
                print("Failed to enable ASR for locale: \(language). Is it supported?")
                // Fallback or keep existing
                if speechRecognizer == nil {
                    speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en"))
                }
            }
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        
        guard let speechRecognizer = speechRecognizer else {
            print("Speech recognizer is nil")
            return
        }
        
        if !speechRecognizer.isAvailable {
            print("Speech recognizer is not available currently")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        if #available(macOS 10.15, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            self.queue.async {
                self.handleRecognitionResult(result: result, error: error)
            }
        }
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result = result {
            let newText = result.bestTranscription.formattedString
            // We need to check against the last reported text to detect changes
            // But recognizedText is updated on Main, so we can't read it reliably here without sync.
            // However, we only care if it changed *in this session*.
            // Let's just dispatch to main to update and reset timer.
            
            DispatchQueue.main.async {
                if newText != self.recognizedText {
                    self.recognizedText = newText
                }
            }
            
            // Reset timer on our queue
            self.resetSilenceTimer()
            
            self.isFinal = result.isFinal
        }
        
        if error != nil || self.isFinal {
            // Handle error or completion
            if let nsError = error as NSError?, nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 209 {
                return
            }
            
            if error != nil {
                silenceTimer?.cancel()
                silenceTimer = nil
            }
        }
    }
    
    func processAudioBuffer(_ buffer: CMSampleBuffer) {
        // Convert to PCM first
        guard let pcmBuffer = convertToPCMBuffer(from: buffer) else { return }
        
        queue.async { [weak self] in
            self?.recognitionRequest?.append(pcmBuffer)
        }
    }
    
    private func convertToPCMBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }
        
        guard let audioFormat = AVAudioFormat(streamDescription: asbdPtr),
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return nil
        }
        
        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            return nil
        }
        
        pcmBuffer.frameLength = frameCount
        
        var lengthAtOffsetOut: Int = 0
        var totalLengthOut: Int = 0
        var dataPointerOut: UnsafeMutablePointer<Int8>?
        
        let status = CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffsetOut, totalLengthOut: &totalLengthOut, dataPointerOut: &dataPointerOut)
        
        guard status == kCMBlockBufferNoErr, let dataPtr = dataPointerOut else { return nil }

        let bytesToCopy = min(Int(pcmBuffer.frameLength) * Int(audioFormat.streamDescription.pointee.mBytesPerFrame), totalLengthOut)
        
        // Copy data handling different formats
        if let floatChannelData = pcmBuffer.floatChannelData {
            memcpy(floatChannelData.pointee, dataPtr, bytesToCopy)
        } else if let int16ChannelData = pcmBuffer.int16ChannelData {
            memcpy(int16ChannelData.pointee, dataPtr, bytesToCopy)
        } else if let int32ChannelData = pcmBuffer.int32ChannelData {
            memcpy(int32ChannelData.pointee, dataPtr, bytesToCopy)
        }
        
        // If format is already Float32, return it
        if audioFormat.commonFormat == .pcmFormatFloat32 {
            return pcmBuffer
        }
        
        // Otherwise convert to Float32 which is preferred by SFSpeechRecognizer
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: audioFormat.sampleRate,
                                               channels: audioFormat.channelCount,
                                               interleaved: false) else { return nil }
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount),
              let converter = AVAudioConverter(from: audioFormat, to: outputFormat) else {
            return nil // Conversion setup failed
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return pcmBuffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if error != nil {
            return nil
        }
        
        return outputBuffer
    }
    
    func stopRecognition() {
        queue.async { [weak self] in
            self?.stopRecognitionInternal()
        }
    }
    
    private func stopRecognitionInternal() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        silenceTimer?.cancel()
        silenceTimer = nil
    }
    
    private func resetSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = DispatchSource.makeTimerSource(queue: queue)
        silenceTimer?.schedule(deadline: .now() + silenceThreshold)
        silenceTimer?.setEventHandler { [weak self] in
            self?.handleSilence()
        }
        silenceTimer?.resume()
    }
    
    private func handleSilence() {
        // This runs on queue
        // We need to get the text. But recognizedText is on Main.
        // But we have the result in the closure? No.
        // We can capture the text in handleRecognitionResult?
        // Or just read recognizedText from Main?
        // Reading from Main synchronously is deadlock prone.
        
        // Better: Store the latest text in a private var on queue.
        // But I didn't add one.
        
        // Let's assume we can just trigger the end.
        // The TranslationManager uses recognizedText.
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.recognizedText.isEmpty {
                let text = self.recognizedText
                self.onSentenceEnd?(text)
                self.recognizedText = ""
                
                // Restart on queue
                self.queue.async {
                    self.restartRecognitionInternal()
                }
            }
        }
    }
    
    private func restartRecognitionInternal() {
        recognitionRequest?.endAudio()
        startRecognitionInternal(language: currentLanguage)
    }
}
