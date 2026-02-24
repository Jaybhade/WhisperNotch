import SwiftUI
import Combine

/// Observable state driving the notch UI
class NotchState: ObservableObject {
    @Published var isListening: Bool = false
    @Published var transcribedText: String = ""
    @Published var statusMessage: String = ""
    @Published var isTranscribing: Bool = false

    /// Rolling buffer of recent audio levels (used to drive per-bar waveform)
    /// Each value is 0…1. The array holds the last N samples for N waveform bars.
    static let barCount = 28
    @Published var audioLevels: [CGFloat] = Array(repeating: 0, count: NotchState.barCount)

    /// Push a new audio level sample; shifts the array left
    func pushAudioLevel(_ level: CGFloat) {
        audioLevels.removeFirst()
        audioLevels.append(level)
    }

    /// Clear all levels to zero
    func clearLevels() {
        audioLevels = Array(repeating: 0, count: NotchState.barCount)
    }
}
