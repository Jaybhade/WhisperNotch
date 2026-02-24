import Cocoa

/// Injects transcribed text into the currently focused text field.
struct TextInjector {

    static func injectText(_ text: String) {
        print("📋 WhisperNotch: Injecting text: \"\(text)\"")

        // Step 1: Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        print("📋 WhisperNotch: Clipboard setString success = \(success)")

        // Verify it's actually on the clipboard
        let verify = pasteboard.string(forType: .string)
        print("📋 WhisperNotch: Clipboard verify = \"\(verify ?? "NIL")\"")

        // Step 2: Try to auto-paste via CGEvent after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let source = CGEventSource(stateID: .combinedSessionState)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)

            print("📋 WhisperNotch: Cmd+V posted. Text stays on clipboard — ⌘V manually if auto-paste didn't work.")
        }

        // NOTE: We intentionally do NOT restore the previous clipboard.
        // The transcribed text stays on the clipboard so the user can always ⌘V manually.
    }
}
