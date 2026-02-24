import AVFoundation
import Accelerate

/// Manages microphone capture and produces Float arrays for WhisperKit.
/// Publishes high-frequency audio levels for waveform visualization.
class AudioEngine: ObservableObject {
    private var audioEngine = AVAudioEngine()
    private var audioBuffer: [Float] = []
    private let bufferLock = NSLock()

    /// Called ~30 times/sec with a 0…1 audio level
    var onAudioLevel: ((CGFloat) -> Void)?

    /// Start capturing microphone audio at 16 kHz mono (Whisper's expected format)
    func startRecording() {
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.outputFormat(forBus: 0)
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        // Remove any existing taps
        inputNode.removeTap(onBus: 0)

        // Reset buffer
        bufferLock.lock()
        audioBuffer = []
        bufferLock.unlock()

        // Install tap — use a small buffer for responsive level metering
        let converter = AVAudioConverter(from: nativeFormat, to: recordingFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) {
            [weak self] buffer, _ in
            guard let self, let converter else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * 16000.0 / buffer.format.sampleRate
            )
            guard frameCount > 0 else { return }

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: recordingFormat,
                frameCapacity: frameCount
            ) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else { return }

            if let channelData = convertedBuffer.floatChannelData?[0] {
                let frames = Int(convertedBuffer.frameLength)
                let samples = Array(UnsafeBufferPointer(start: channelData, count: frames))

                // Compute RMS for level meter
                var rms: Float = 0
                vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frames))

                // Compute peak for more responsive visual
                var peak: Float = 0
                vDSP_maxmgv(samples, 1, &peak, vDSP_Length(frames))

                // Blend RMS and peak for a responsive but smooth level
                let blended = (rms * 0.4 + peak * 0.6)
                // Apply a curve to make quiet sounds more visible
                let normalized = min(pow(CGFloat(blended) * 3.5, 0.7), 1.0)

                DispatchQueue.main.async {
                    self.onAudioLevel?(normalized)
                }

                self.bufferLock.lock()
                self.audioBuffer.append(contentsOf: samples)
                self.bufferLock.unlock()
            }
        }

        do {
            try audioEngine.start()
        } catch {
            print("AudioEngine: Failed to start — \(error)")
        }
    }

    /// Stop recording and tear down the tap
    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
    }

    /// Retrieve the recorded audio as a Float array (16 kHz, mono)
    func getRecordedAudio() -> [Float] {
        bufferLock.lock()
        let copy = audioBuffer
        bufferLock.unlock()
        return copy
    }

    /// Get audio captured so far WITHOUT clearing the buffer (for interim transcription)
    func peekRecordedAudio() -> [Float] {
        bufferLock.lock()
        let copy = audioBuffer
        bufferLock.unlock()
        return copy
    }
}
