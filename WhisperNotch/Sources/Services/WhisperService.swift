import Foundation
import WhisperKit

/// Wraps WhisperKit for local on-device speech-to-text with streaming support
class WhisperService: ObservableObject {
    @Published var isModelLoaded = false
    @Published var modelName: String = "openai_whisper-base"
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0

    private var whisperKit: WhisperKit?

    /// Download (if needed) and load the Whisper model
    func loadModel(name: String? = nil) async throws {
        let selectedModel = name ?? modelName

        await MainActor.run {
            self.isDownloading = true
            self.isModelLoaded = false
        }

        let kit = try await WhisperKit(
            model: selectedModel,
            verbose: false,
            logLevel: .none
        )

        self.whisperKit = kit

        await MainActor.run {
            self.isModelLoaded = true
            self.isDownloading = false
            self.modelName = selectedModel
        }
    }

    /// Transcribe a Float audio buffer (16 kHz mono) → text
    func transcribe(audioData: [Float]) async throws -> String {
        guard let kit = whisperKit else {
            throw WhisperError.modelNotLoaded
        }

        let results = try await kit.transcribe(audioArray: audioData)
        let text = results.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    /// Interim transcription for real-time preview (runs on partial audio)
    /// Returns quickly with a best-effort result
    func interimTranscribe(audioData: [Float]) async -> String? {
        guard let kit = whisperKit else { return nil }
        // Need at least 0.5s of audio (8000 samples at 16kHz)
        guard audioData.count >= 8000 else { return nil }

        do {
            let results = try await kit.transcribe(audioArray: audioData)
            let text = results.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    /// Available model variants (smallest → largest)
    static let availableModels = [
        "openai_whisper-tiny",
        "openai_whisper-tiny.en",
        "openai_whisper-base",
        "openai_whisper-base.en",
        "openai_whisper-small",
        "openai_whisper-small.en",
    ]
}

enum WhisperError: LocalizedError {
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded yet"
        }
    }
}
