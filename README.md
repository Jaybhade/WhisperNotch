# WhisperNotch

A macOS native app that uses a local Whisper model to convert speech to text — displayed beautifully around your Mac's notch.

Hold **⌥ Option** in any text field, speak, and release. Your words appear in a floating UI hugging the notch, then get inserted into the active input.

---

## How It Works

1. **Hold ⌥ Option** — the notch UI appears with an animated waveform
2. **Speak** — audio is captured at 16 kHz via AVAudioEngine
3. **Release ⌥** — WhisperKit transcribes locally on-device
4. **Text is pasted** into whatever input field is focused

All processing happens locally. No data leaves your Mac.

---

## Requirements

- macOS 14.0+ (Sonoma or later)
- MacBook with Apple Silicon (M1/M2/M3) recommended
- Xcode 15.0+
- ~75 MB disk space for the base Whisper model (downloaded on first launch)

---

## Build & Run

### Option A: Xcode

1. Open `WhisperNotch.xcodeproj` in Xcode
2. Xcode will automatically resolve the WhisperKit Swift package
3. Select the **WhisperNotch** scheme and your Mac as the target
4. Press **⌘R** to build and run

### Option B: Swift Package Manager (command line)

```bash
cd WhisperNotch
swift build
swift run WhisperNotch
```

---

## Permissions

On first launch you'll be prompted for two permissions:

| Permission | Why | Where to grant |
|---|---|---|
| **Microphone** | Capture speech audio | System Settings → Privacy & Security → Microphone |
| **Accessibility** | Global hotkey detection + text injection | System Settings → Privacy & Security → Accessibility |

Both are required for the app to function. The app runs as a **menu bar item** (no Dock icon).

---

## Settings

Click the waveform icon in the menu bar → **Settings** to:

- **Switch Whisper models** — tiny (~39 MB, fastest), base (~74 MB, balanced), or small (~244 MB, most accurate)
- English-only variants (`.en`) are available for better performance on English speech

---

## Architecture

```
WhisperNotch/
├── Sources/
│   ├── App/
│   │   ├── WhisperNotchApp.swift    # @main entry point
│   │   └── AppDelegate.swift        # Menu bar, panel, bindings
│   ├── Models/
│   │   └── NotchState.swift         # Observable UI state
│   ├── Services/
│   │   ├── AudioEngine.swift        # Mic capture → 16kHz Float[]
│   │   ├── WhisperService.swift     # WhisperKit wrapper
│   │   ├── HotkeyManager.swift      # Global ⌥ key listener
│   │   └── TextInjector.swift       # Cmd+V paste simulation
│   └── Views/
│       ├── NotchPanel.swift         # Floating NSPanel near notch
│       ├── NotchContentView.swift   # SwiftUI notch UI + waveform
│       └── SettingsView.swift       # Model picker & permissions
├── Info.plist
├── WhisperNotch.entitlements
└── Assets.xcassets/
```

---

## Key Dependencies

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) — Apple-optimized Whisper inference using Core ML

---

## Troubleshooting

**"Failed to create event tap"**
→ Grant Accessibility permission in System Settings → Privacy & Security → Accessibility. You may need to remove and re-add the app.

**No audio captured**
→ Check microphone permission. Ensure your mic isn't muted or in use by another app.

**Model download slow**
→ The model downloads once on first launch. Subsequent launches use the cached model.

---

## License

MIT
