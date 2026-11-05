import AppKit
import ApplicationServices

/// Fotografia dell'app e del campo di testo attivi al momento in cui parte la dettatura.
struct FocusSnapshot {
    let appName: String
    let bundleId: String
    let pid: pid_t
    let windowTitle: String
    let selectedText: String?
    let focusedElement: AXUIElement?
    let focusedRole: String?

    static let empty = FocusSnapshot(appName: "", bundleId: "", pid: 0, windowTitle: "", selectedText: nil, focusedElement: nil, focusedRole: nil)
}

enum FocusContext {
    static func capture() -> FocusSnapshot {
        guard let app = NSWorkspace.shared.frontmostApplication else { return .empty }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        let focused = copyElement(appElement, kAXFocusedUIElementAttribute)
        let role = focused.flatMap { copyString($0, kAXRoleAttribute) }
        var selected = focused.flatMap { copyString($0, kAXSelectedTextAttribute) }
        if let s = selected, s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { selected = nil }

        var title = ""
        if let window = copyElement(appElement, kAXFocusedWindowAttribute) {
            title = copyString(window, kAXTitleAttribute) ?? ""
        }

        return FocusSnapshot(
            appName: app.localizedName ?? app.bundleIdentifier ?? "App",
            bundleId: app.bundleIdentifier ?? "",
            pid: pid,
            windowTitle: title,
            selectedText: selected,
            focusedElement: focused,
            focusedRole: role
        )
    }

    static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let v = value, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    static func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let v = value else { return nil }
        return v as? String
    }

    static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable: DarwinBoolean = false
        let status = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return status == .success && settable.boolValue
    }
}
