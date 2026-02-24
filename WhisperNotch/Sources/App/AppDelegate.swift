import SwiftUI
import Combine
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var notchPanel: NotchPanel?
    private var audioEngine = AudioEngine()
    private var whisperService = WhisperService()
    private var hotkeyManager = HotkeyManager()
    private var notchState = NotchState()
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?

    // Interim transcription timer
    private var interimTimer: Timer?
    private var isInterimRunning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 WhisperNotch: App launching...")
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupNotchPanel()
        setupAudioLevelPipeline()
        setupBindings()
        requestMicrophonePermission()
        loadWhisperModel()
        print("🚀 WhisperNotch: App launch complete.")
    }

    // MARK: - Microphone Permission

    private func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("🎙 WhisperNotch: Microphone permission already granted.")
        case .notDetermined:
            print("🎙 WhisperNotch: Requesting microphone permission...")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("🎙 WhisperNotch: Microphone permission \(granted ? "granted" : "denied").")
                if !granted {
                    DispatchQueue.main.async {
                        self.notchState.statusMessage = "Microphone access denied"
                    }
                }
            }
        case .denied, .restricted:
            print("🎙 WhisperNotch: Microphone permission denied/restricted.")
            DispatchQueue.main.async {
                self.notchState.statusMessage = "Microphone access denied"
            }
        @unknown default:
            break
        }
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "WhisperNotch")?
                .withSymbolConfiguration(config)
            button.image = image
            button.toolTip = "WhisperNotch — Hold ⌥ Option to dictate"
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "WhisperNotch", action: nil, keyEquivalent: "")
        menu.items.first?.isEnabled = false
        menu.addItem(NSMenuItem.separator())

        let statusMenuItem = NSMenuItem(title: "Status: Loading model…", action: nil, keyEquivalent: "")
        statusMenuItem.tag = 100
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit WhisperNotch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(
                whisperService: whisperService,
                hotkeyManager: hotkeyManager
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.contentView = NSHostingView(rootView: settingsView)
            window.title = "WhisperNotch Settings"
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Notch Panel

    private func setupNotchPanel() {
        notchPanel = NotchPanel(notchState: notchState)
        print("🖥 WhisperNotch: Notch panel created.")
    }

    // MARK: - Audio Level → Waveform Pipeline

    private func setupAudioLevelPipeline() {
        audioEngine.onAudioLevel = { [weak self] level in
            guard let self else { return }
            self.notchState.pushAudioLevel(level)
        }
    }

    // MARK: - Bindings

    private func setupBindings() {
        // ── Hotkey pressed → start recording ──
        hotkeyManager.onHotkeyDown = { [weak self] in
            guard let self else { return }
            print("🔑 WhisperNotch: ⌥ Option PRESSED")

            guard self.whisperService.isModelLoaded else {
                print("⏳ WhisperNotch: Model not loaded yet, showing status...")
                self.notchState.statusMessage = "Model still loading…"
                self.notchPanel?.showPanel()
                return
            }

            // Reset state
            self.notchState.isListening = true
            self.notchState.isTranscribing = false
            self.notchState.transcribedText = ""
            self.notchState.statusMessage = ""
            self.notchState.clearLevels()

            print("🎙 WhisperNotch: Showing panel and starting recording...")
            self.notchPanel?.showPanel()
            self.audioEngine.startRecording()

            // Start interim transcription every ~1.5s for real-time text preview
            self.startInterimTranscription()
        }

        // ── Hotkey released → stop recording, final transcribe, inject text ──
        hotkeyManager.onHotkeyUp = { [weak self] in
            guard let self else { return }
            print("🔑 WhisperNotch: ⌥ Option RELEASED")

            self.audioEngine.stopRecording()
            self.stopInterimTranscription()
            self.notchState.isListening = false
            self.notchState.isTranscribing = true

            let audioData = self.audioEngine.getRecordedAudio()
            print("🎙 WhisperNotch: Captured \(audioData.count) audio samples (\(String(format: "%.1f", Float(audioData.count) / 16000.0))s)")

            guard audioData.count > 1600 else {  // At least 0.1s of audio
                print("⚠️ WhisperNotch: Too little audio, skipping transcription.")
                self.notchState.isTranscribing = false
                self.notchState.statusMessage = "Too short — hold ⌥ longer"
                self.dismissPanelAfterDelay()
                return
            }

            Task { @MainActor in
                do {
                    print("🧠 WhisperNotch: Starting transcription...")
                    let text = try await self.whisperService.transcribe(audioData: audioData)
                    print("🧠 WhisperNotch: Transcription result: \"\(text)\"")
                    self.notchState.isTranscribing = false
                    self.notchState.transcribedText = text

                    if !text.isEmpty {
                        TextInjector.injectText(text)
                    }

                    self.dismissPanelAfterDelay()
                } catch {
                    print("❌ WhisperNotch: Transcription error: \(error)")
                    self.notchState.isTranscribing = false
                    self.notchState.statusMessage = "Error: \(error.localizedDescription)"
                    self.dismissPanelAfterDelay(delay: 2.0)
                }
            }
        }

        print("🔑 WhisperNotch: Starting hotkey listener...")
        hotkeyManager.startListening()
    }

    // MARK: - Interim (Real-time) Transcription

    private func startInterimTranscription() {
        interimTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, self.notchState.isListening, !self.isInterimRunning else { return }
            self.isInterimRunning = true

            let audio = self.audioEngine.peekRecordedAudio()
            guard audio.count > 8000 else {
                self.isInterimRunning = false
                return
            }

            Task { @MainActor in
                if let text = await self.whisperService.interimTranscribe(audioData: audio) {
                    if self.notchState.isListening {
                        self.notchState.transcribedText = text
                    }
                }
                self.isInterimRunning = false
            }
        }
    }

    private func stopInterimTranscription() {
        interimTimer?.invalidate()
        interimTimer = nil
        isInterimRunning = false
    }

    // MARK: - Dismiss

    private func dismissPanelAfterDelay(delay: TimeInterval = 1.8) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.notchPanel?.hidePanel()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.notchState.transcribedText = ""
                self?.notchState.statusMessage = ""
                self?.notchState.isTranscribing = false
                self?.notchState.clearLevels()
            }
        }
    }

    // MARK: - Load Model

    private func loadWhisperModel() {
        Task {
            do {
                print("📦 WhisperNotch: Loading Whisper model...")
                try await whisperService.loadModel()
                print("✅ WhisperNotch: Model loaded successfully!")
                await MainActor.run {
                    if let item = self.statusItem.menu?.item(withTag: 100) {
                        item.title = "Status: Ready — Hold ⌥ to dictate"
                    }
                }
            } catch {
                print("❌ WhisperNotch: Failed to load model: \(error)")
                await MainActor.run {
                    if let item = self.statusItem.menu?.item(withTag: 100) {
                        item.title = "Status: Failed to load model"
                    }
                }
            }
        }
    }
}
