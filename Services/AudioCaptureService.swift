import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine

class AudioCaptureService: NSObject, ObservableObject {
    private var stream: SCStream?
    
    // Callback to deliver audio buffers
    var onAudioBuffer: ((CMSampleBuffer) -> Void)?
    
    func startCapture(app: AppInfo) async throws {
        // 1. Get shareable content to find the specific window/app
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        
        guard let targetApp = content.applications.first(where: { $0.processID == app.processID }) else {
            throw NSError(domain: "AudioCapture", code: 404, userInfo: [NSLocalizedDescriptionKey: "Target app not found"])
        }
        
        // 2. Create filter
        let filter = SCContentFilter(display: content.displays.first!, including: [targetApp], exceptingWindows: [])
        
        // 3. Create configuration
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.sampleRate = 44100
        config.channelCount = 1
        config.excludesCurrentProcessAudio = true // Don't capture our own TTS if we add it later
        
        // Minimize video capture overhead since we only need audio
        config.width = 100
        config.height = 100
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1) // 1 FPS
        
        // 4. Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        // 5. Add output
        // Start catching both audio and screen to prevent "stream output not found" errors, 
        // even though we ignore video frames
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "audio.capture.queue"))
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "video.capture.queue"))
        
        // 6. Start capture
        try await stream?.startCapture()
    }
    
    func stopCapture() async {
        try? await stream?.stopCapture()
        stream = nil
    }
}

extension AudioCaptureService: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return } // Ignore video frames
        onAudioBuffer?(sampleBuffer)
    }
}
