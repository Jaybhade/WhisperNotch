import Cocoa
import Carbon.HIToolbox

/// Listens for a global hotkey (default: Option/⌥) press and release.
/// Uses NSEvent monitors for reliable hotkey detection (works without Accessibility).
/// Also attempts a CGEvent tap to enable paste permission for TextInjector.
class HotkeyManager: ObservableObject {
    @Published var isHotkeyPressed = false
    @Published var hotkeyLabel = "⌥ Option"
    @Published var hasCGEventTap = false

    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?

    // NSEvent monitors — always work, handle hotkey detection
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // CGEvent tap — needed to unlock CGEvent paste permission
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var isOptionDown = false

    func startListening() {
        print("🔑 WhisperNotch: Setting up hotkey listener...")

        // 1. NSEvent monitors — these ALWAYS work for hotkey detection
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
        print("✅ WhisperNotch: NSEvent monitors active (hotkey detection)")

        // 2. Try CGEvent tap — this enables paste permission
        attemptCGEventTap()
    }

    /// Try to create a CGEvent tap. If Accessibility isn't granted yet,
    /// poll until it is. The tap itself is a no-op — it just needs to exist
    /// to unlock CGEvent posting permission for TextInjector.
    private func attemptCGEventTap() {
        let trusted = AXIsProcessTrusted()
        print("🔑 WhisperNotch: AXIsProcessTrusted = \(trusted)")

        if !trusted {
            // Prompt user
            AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            )
            print("⚠️ WhisperNotch: Accessibility not granted — auto-paste disabled")
            print("→ Hotkey still works! But text will be copied to clipboard (⌘V to paste)")
            print("→ Grant Accessibility to enable auto-paste into text fields")

            // Keep polling
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    print("✅ WhisperNotch: Accessibility granted!")
                    DispatchQueue.main.async {
                        self?.createCGEventTap()
                    }
                }
            }
            return
        }

        createCGEventTap()
    }

    private func createCGEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, _ in
                // No-op — we use NSEvent monitors for detection.
                // This tap just needs to exist to enable CGEvent posting.
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            print("❌ WhisperNotch: CGEvent tap creation failed")
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        hasCGEventTap = true
        print("✅ WhisperNotch: CGEvent tap active — auto-paste enabled")
    }

    // MARK: - Hotkey handling via NSEvent

    private func handleFlagsChanged(_ event: NSEvent) {
        let optionHeld = event.modifierFlags.contains(.option)
        let otherModifiers: NSEvent.ModifierFlags = [.command, .control, .shift]
        let hasOtherModifiers = !event.modifierFlags.intersection(otherModifiers).isEmpty

        if optionHeld && !hasOtherModifiers && !isOptionDown {
            isOptionDown = true
            DispatchQueue.main.async {
                self.isHotkeyPressed = true
                self.onHotkeyDown?()
            }
        } else if !optionHeld && isOptionDown {
            isOptionDown = false
            DispatchQueue.main.async {
                self.isHotkeyPressed = false
                self.onHotkeyUp?()
            }
        }
    }

    func stopListening() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    deinit {
        stopListening()
    }
}
