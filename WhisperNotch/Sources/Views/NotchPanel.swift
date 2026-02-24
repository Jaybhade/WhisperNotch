import SwiftUI

/// A borderless floating panel that hugs the Mac's notch area.
/// Smoothly expands/collapses from the notch with spring animation.
class NotchPanel {
    private var panel: NSPanel?
    private let notchState: NotchState

    // Notch-aligned dimensions
    private let collapsedWidth: CGFloat = 240
    private let expandedWidth: CGFloat = 520
    private let collapsedHeight: CGFloat = 36
    private let expandedHeight: CGFloat = 120

    private var isShowing = false

    init(notchState: NotchState) {
        self.notchState = notchState
        setupPanel()
    }

    private func setupPanel() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        // Start collapsed at notch position
        let x = screenFrame.midX - expandedWidth / 2
        let y = screenFrame.maxY - expandedHeight

        let contentRect = NSRect(x: x, y: y, width: expandedWidth, height: expandedHeight)

        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .screenSaver  // Above everything including menu bar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none

        let hostingView = NSHostingView(
            rootView: NotchContentView(notchState: notchState)
                .frame(width: expandedWidth, height: expandedHeight)
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: expandedWidth, height: expandedHeight)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.panel = panel
    }

    func showPanel() {
        guard let panel, !isShowing else { return }
        guard let screen = NSScreen.main else { return }
        isShowing = true

        let screenFrame = screen.frame
        let x = screenFrame.midX - expandedWidth / 2
        let y = screenFrame.maxY - expandedHeight

        panel.setFrame(
            NSRect(x: x, y: y, width: expandedWidth, height: expandedHeight),
            display: true
        )
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        // Fade in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func hidePanel() {
        guard let panel, isShowing else { return }
        isShowing = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}
