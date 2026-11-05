import AppKit
import Carbon.HIToolbox

protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyPressed()
    func hotkeyReleased()
    /// Ritorna true se l'evento Esc va consumato (es. durante una registrazione).
    func escapePressed() -> Bool
}

/// Event tap globale che rileva pressione/rilascio del tasto di dettatura (fn o alternativi).
final class HotkeyManager {
    weak var delegate: HotkeyManagerDelegate?
    var choice: HotkeyChoice

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDown = false

    init(choice: HotkeyChoice) {
        self.choice = choice
    }

    var isRunning: Bool { tap != nil }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handle(type: type, event: event)
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        var created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                        options: .defaultTap, eventsOfInterest: mask,
                                        callback: callback, userInfo: userInfo)
        if created == nil {
            // Senza permesso di modifica eventi si ripiega su un tap in sola lettura (Esc non verra' consumato).
            created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                        options: .listenOnly, eventsOfInterest: mask,
                                        callback: callback, userInfo: userInfo)
        }
        guard let tap = created else {
            Log.hotkey.error("Impossibile creare l'event tap (permessi Accessibility/Input Monitoring?)")
            return false
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.runLoopSource = source
        Log.hotkey.info("Event tap attivo per \(self.choice.rawValue, privacy: .public)")
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        tap = nil
        runLoopSource = nil
        isDown = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        switch type {
        case .flagsChanged:
            guard let spec = modifierSpec() else { break }
            let (code, flag) = spec
            guard keyCode == code else { break }
            let nowDown = event.flags.contains(flag)
            if nowDown != isDown {
                isDown = nowDown
                notify(down: nowDown)
            }
        case .keyDown:
            if keyCode == Int(kVK_Escape), let delegate, delegate.escapePressed() {
                return nil
            }
            if let code = plainKeyCode(), keyCode == code {
                let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
                if !isRepeat, !isDown {
                    isDown = true
                    notify(down: true)
                }
                return nil
            }
        case .keyUp:
            if let code = plainKeyCode(), keyCode == code {
                if isDown {
                    isDown = false
                    notify(down: false)
                }
                return nil
            }
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    private func notify(down: Bool) {
        guard let delegate else { return }
        if down { delegate.hotkeyPressed() } else { delegate.hotkeyReleased() }
    }

    /// Per i modificatori: (keyCode, flag da osservare).
    private func modifierSpec() -> (Int, CGEventFlags)? {
        switch choice {
        case .fn: return (Int(kVK_Function), .maskSecondaryFn)
        case .rightOption: return (Int(kVK_RightOption), .maskAlternate)
        case .rightCommand: return (Int(kVK_RightCommand), .maskCommand)
        case .f13, .f18: return nil
        }
    }

    /// Per i tasti normali: keyCode.
    private func plainKeyCode() -> Int? {
        switch choice {
        case .f13: return Int(kVK_F13)
        case .f18: return Int(kVK_F18)
        default: return nil
        }
    }
}
