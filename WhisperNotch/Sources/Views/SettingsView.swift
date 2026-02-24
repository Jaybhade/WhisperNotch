import SwiftUI

/// Settings window for model selection and hotkey configuration
struct SettingsView: View {
    @ObservedObject var whisperService: WhisperService
    @ObservedObject var hotkeyManager: HotkeyManager

    @State private var selectedModel: String = "openai_whisper-base"
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(alignment: .leading) {
                    Text("WhisperNotch")
                        .font(.title2.bold())
                    Text("Local speech-to-text in your notch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                statusBadge
            }

            Divider()

            // Model Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Whisper Model")
                    .font(.headline)

                Picker("Model", selection: $selectedModel) {
                    ForEach(WhisperService.availableModels, id: \.self) { model in
                        Text(modelDisplayName(model)).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Text(modelDescription(selectedModel))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if selectedModel != whisperService.modelName {
                    Button("Load Model") {
                        loadModel()
                    }
                    .disabled(isLoading)
                }
            }

            Divider()

            // Hotkey
            VStack(alignment: .leading, spacing: 8) {
                Text("Hotkey")
                    .font(.headline)

                HStack {
                    Text("Hold")
                    Text(hotkeyManager.hotkeyLabel)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.secondary.opacity(0.15))
                        )
                        .font(.system(.body, design: .monospaced))
                    Text("to dictate")
                }
                .font(.body)

                Text("Press and hold the key in any text field. Speak, then release to insert the transcribed text.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Permissions
            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions")
                    .font(.headline)

                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "For capturing speech"
                )
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "For auto-pasting text into apps (optional — you can ⌘V manually)"
                )

                Button("Open Accessibility Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 420, height: 480)
        .onAppear {
            selectedModel = whisperService.modelName
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(whisperService.isModelLoaded ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(whisperService.isModelLoaded ? "Ready" : "Loading…")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private func loadModel() {
        isLoading = true
        Task {
            try? await whisperService.loadModel(name: selectedModel)
            await MainActor.run { isLoading = false }
        }
    }

    private func modelDisplayName(_ model: String) -> String {
        model
            .replacingOccurrences(of: "openai_whisper-", with: "")
            .capitalized
    }

    private func modelDescription(_ model: String) -> String {
        if model.contains("tiny") {
            return "Fastest, lowest accuracy (~39 MB). Good for quick notes."
        } else if model.contains("base") {
            return "Balanced speed and accuracy (~74 MB). Recommended."
        } else if model.contains("small") {
            return "Higher accuracy, slower (~244 MB). Best for complex speech."
        }
        return ""
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
            VStack(alignment: .leading) {
                Text(title).font(.body)
                Text(description).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
