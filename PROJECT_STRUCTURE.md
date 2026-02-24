# WhisperNotch Xcode Project Structure

## Project Configuration
- **Project Path**: `/sessions/affectionate-zen-brown/mnt/dev/WhisperNotch/WhisperNotch.xcodeproj`
- **Bundle ID**: `com.whispernotch.app`
- **Deployment Target**: macOS 14.0+
- **Swift Version**: 5.9
- **Product Type**: macOS Application

## Build Phases

### 1. Sources Build Phase
Includes all Swift source files:
- **App Group**
  - WhisperNotchApp.swift
  - AppDelegate.swift
- **Models Group**
  - NotchState.swift
- **Services Group**
  - AudioEngine.swift
  - WhisperService.swift
  - HotkeyManager.swift
  - TextInjector.swift
- **Views Group**
  - NotchPanel.swift
  - NotchContentView.swift
  - SettingsView.swift

### 2. Frameworks Build Phase
- AVFoundation
- Accelerate
- Carbon

### 3. Resources Build Phase
- Assets.xcassets
- Info.plist
- WhisperNotch.entitlements

## Entitlements Configuration
- **LSUIElement**: `true` (Menu bar application)
- **Sandbox**: Disabled (enables Accessibility + Microphone access)
- **NSMicrophoneUsageDescription**: "WhisperNotch needs access to the microphone for speech-to-text functionality"
- **NSAccessibilityUsageDescription**: "WhisperNotch needs accessibility access to inject text into other applications"

## Package Dependencies
- **WhisperKit**: 0.9.0+ (from https://github.com/argmaxinc/WhisperKit.git)

## Build Configurations
- **Debug**: Development build with optimization disabled
- **Release**: Production build with optimizations enabled

## Key Settings
- Code signing style: Automatic
- Enable hardened runtime: Yes
- Combine HiDPI images: Yes
- Support for macOS 14.0 and later

## File Hierarchy
```
WhisperNotch.xcodeproj/
└── project.pbxproj

Sources/
├── App/
│   ├── WhisperNotchApp.swift
│   └── AppDelegate.swift
├── Models/
│   └── NotchState.swift
├── Services/
│   ├── AudioEngine.swift
│   ├── WhisperService.swift
│   ├── HotkeyManager.swift
│   └── TextInjector.swift
└── Views/
    ├── NotchPanel.swift
    ├── NotchContentView.swift
    └── SettingsView.swift

Resources/
├── Assets.xcassets
├── Info.plist
└── WhisperNotch.entitlements
```

## Notes
- The project is configured with Xcode 15.0 compatibility
- All source files use Swift 5.9 syntax
- The menu bar app configuration is properly set via LSUIElement
- Sandbox is disabled to allow accessibility and microphone access
- Framework linking is configured for AVFoundation, Accelerate, and Carbon
