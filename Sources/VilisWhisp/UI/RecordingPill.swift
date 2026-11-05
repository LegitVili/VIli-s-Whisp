import AppKit
import SwiftUI

/// Pannello flottante non attivante che mostra lo stato della dettatura in basso al centro dello schermo.
@MainActor
final class RecordingPill {
    private var panel: NSPanel?
    private weak var controller: DictationController?

    func attach(controller: DictationController) {
        self.controller = controller
    }

    func show() {
        if panel == nil { build() }
        position()
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func build() {
        guard let controller else { return }
        let hosting = NSHostingView(rootView: PillView(controller: controller, recorder: controller.recorder))
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.ignoresMouseEvents = true
        p.isMovableByWindowBackground = false
        p.contentView = hosting
        panel = p
    }

    private func position() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.minY + 14)
        panel.setFrameOrigin(origin)
    }
}
