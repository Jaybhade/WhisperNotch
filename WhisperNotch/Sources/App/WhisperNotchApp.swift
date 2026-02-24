import SwiftUI

@main
struct WhisperNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only app — no main window.
        // Settings window is opened manually from the menu bar.
        Settings {
            EmptyView()
        }
    }
}
