import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Inserisce il testo al cursore dell'app attiva: Accessibility sui controlli nativi, altrimenti incolla simulando ⌘V.
enum TextInserter {
    /// Ruoli AX per i quali l'impostazione di kAXSelectedText e' affidabile.
    private static let nativeTextRoles: Set<String> = [kAXTextFieldRole as String, kAXTextAreaRole as String, kAXComboBoxRole as String]

    @MainActor
    static func insert(_ text: String, snapshot: FocusSnapshot, preferAccessibility: Bool) async {
        guard !text.isEmpty else { return }

        if preferAccessibility, insertViaAccessibility(text, snapshot: snapshot) {
            Log.insert.info("Inserted via Accessibility into \(snapshot.bundleId, privacy: .public)")
            return
        }
        await insertViaPaste(text, snapshot: snapshot)
    }

    private static func insertViaAccessibility(_ text: String, snapshot: FocusSnapshot) -> Bool {
        // Ricalcola l'elemento focalizzato: l'utente potrebbe aver spostato il cursore durante la dettatura.
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier == snapshot.pid else { return false }
        let appElement = AXUIElementCreateApplication(snapshot.pid)
        guard let element = FocusContext.copyElement(appElement, kAXFocusedUIElementAttribute) else { return false }
        guard let role = FocusContext.copyString(element, kAXRoleAttribute), nativeTextRoles.contains(role) else { return false }
        guard FocusContext.isSettable(element, kAXSelectedTextAttribute) else { return false }
        let status = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return status == .success
    }

    @MainActor
    private static func insertViaPaste(_ text: String, snapshot: FocusSnapshot) async {
        let pasteboard = NSPasteboard.general
        let saved = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChangeCount = pasteboard.changeCount

        // Breve attesa perche' il pasteboard sia pronto, poi ⌘V.
        try? await Task.sleep(nanoseconds: 30_000_000)
        sendCommandV(to: snapshot.pid)
        Log.insert.info("Pasted into \(snapshot.bundleId, privacy: .public)")

        // Ripristina la clipboard dell'utente dopo che l'app ha consumato l'incolla.
        try? await Task.sleep(nanoseconds: 400_000_000)
        if pasteboard.changeCount == ourChangeCount {
            restorePasteboard(pasteboard, saved)
        }
    }

    private static func sendCommandV(to pid: pid_t) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKey = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        if pid > 0 {
            down.postToPid(pid)
            up.postToPid(pid)
        } else {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Pasteboard save/restore

    private struct SavedItem {
        let types: [(NSPasteboard.PasteboardType, Data)]
    }

    private static func savePasteboard(_ pb: NSPasteboard) -> [SavedItem] {
        (pb.pasteboardItems ?? []).map { item in
            SavedItem(types: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            })
        }
    }

    private static func restorePasteboard(_ pb: NSPasteboard, _ saved: [SavedItem]) {
        pb.clearContents()
        guard !saved.isEmpty else { return }
        let items: [NSPasteboardItem] = saved.map { s in
            let item = NSPasteboardItem()
            for (type, data) in s.types { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(items)
    }
}
