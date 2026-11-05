import AppKit
import Combine
import Foundation

enum PillState: Equatable {
    case hidden
    case listening(handsFree: Bool)
    case transcribing
    case formatting
    case inserting
    case done
    case error(String)

    var isActive: Bool {
        if case .hidden = self { return false }
        return true
    }
}

/// Orchestra il flusso: hotkey → registrazione → STT → Claude → inserimento → cronologia.
@MainActor
final class DictationController: ObservableObject {
    @Published private(set) var state: PillState = .hidden
    @Published private(set) var handsFree = false

    let recorder = AudioRecorder()
    let settings = Settings.shared
    let history = HistoryStore.shared
    private let pill: RecordingPill

    private var snapshot: FocusSnapshot = .empty
    private var pressDate: Date?
    private var lastTapDate: Date?
    private var pipelineTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private let tapThreshold: TimeInterval = 0.3
    private let doubleTapWindow: TimeInterval = 0.5

    init() {
        pill = RecordingPill()
        pill.attach(controller: self)
    }

    // MARK: - Hotkey events (chiamati dal main run loop tramite il tap)

    func hotkeyDown() {
        if handsFree {
            // Un tap mentre si e' in mani libere chiude la registrazione.
            handsFree = false
            finishRecording()
            return
        }
        if pipelineTask != nil {
            // Una nuova dettatura mentre la precedente e' in elaborazione: la mettiamo in coda ignorandola per semplicita'.
            Log.app.info("Pipeline in corso, pressione ignorata")
            return
        }
        pressDate = Date()
        beginRecording()
    }

    func hotkeyUp() {
        guard recorder.isRecording, !handsFree else { return }
        let held = pressDate.map { Date().timeIntervalSince($0) } ?? 0
        if held < tapThreshold {
            let now = Date()
            if settings.data.handsFreeDoubleTap, let last = lastTapDate, now.timeIntervalSince(last) < doubleTapWindow {
                handsFree = true
                lastTapDate = nil
                state = .listening(handsFree: true)
                Log.app.info("Modalita' mani libere attiva")
                return
            }
            lastTapDate = now
            cancelRecording()
            return
        }
        finishRecording()
    }

    /// Esc durante la registrazione: annulla. Ritorna true se gestito.
    func escape() -> Bool {
        guard recorder.isRecording else { return false }
        handsFree = false
        cancelRecording()
        return true
    }

    func toggleHandsFree() {
        if recorder.isRecording {
            handsFree = false
            finishRecording()
        } else {
            handsFree = true
            beginRecording()
        }
    }

    // MARK: - Recording

    private func beginRecording() {
        hideTask?.cancel()
        snapshot = FocusContext.capture()
        do {
            try recorder.start()
        } catch {
            show(.error(error.localizedDescription))
            return
        }
        if settings.data.playSounds { NSSound(named: "Tink")?.play() }
        show(.listening(handsFree: handsFree))
    }

    private func cancelRecording() {
        recorder.cancel()
        hide()
    }

    private func finishRecording() {
        let recording = recorder.stop()
        if recording.duration < settings.data.minimumDuration || recording.isSilent {
            Log.app.info("Registrazione scartata (durata \(recording.duration, privacy: .public)s, silenzio=\(recording.isSilent, privacy: .public))")
            hide()
            return
        }
        if settings.data.playSounds { NSSound(named: "Pop")?.play() }
        let snap = snapshot
        pipelineTask = Task { [weak self] in
            await self?.runPipeline(recording: recording, snapshot: snap)
            self?.pipelineTask = nil
        }
    }

    // MARK: - Pipeline

    private func runPipeline(recording: Recording, snapshot: FocusSnapshot) async {
        let data = settings.data
        show(.transcribing)

        let raw: String
        let detectedLanguage: String?
        do {
            let provider = try TranscriptionProviderFactory.make(from: data)
            let prompt = PromptBuilder.sttPrompt(dictionary: settings.dictionaryTerms, languageMode: data.languageMode)
            let result = try await provider.transcribe(wav: recording.wav, languageHint: data.languageMode.isoCode, prompt: prompt)
            raw = result.text
            detectedLanguage = result.language
        } catch {
            Log.net.error("STT fallito: \(error.localizedDescription, privacy: .public)")
            show(.error(error.localizedDescription))
            return
        }

        guard !raw.isEmpty else {
            show(.error("Non ho capito nulla."))
            return
        }

        let context = FormatContext(
            appName: snapshot.appName,
            bundleId: snapshot.bundleId,
            windowTitle: snapshot.windowTitle,
            selectedText: snapshot.selectedText,
            tone: AppToneProfile.tone(for: snapshot.bundleId, settings: data),
            dictionary: settings.dictionaryTerms,
            snippets: data.snippets,
            languageMode: data.languageMode,
            detectedLanguage: detectedLanguage
        )

        var clean = raw
        var softError: String?
        if data.skipFormatting {
            clean = LocalCleaner.clean(raw)
        } else {
            show(.formatting)
            if let key = Keychain.get(.anthropic), !key.isEmpty {
                let formatter = ClaudeFormatter(apiKey: key, model: data.claudeModel)
                do {
                    clean = try await formatter.format(raw: raw, context: context)
                } catch {
                    Log.net.error("Claude fallito: \(error.localizedDescription, privacy: .public)")
                    softError = "Formattazione non riuscita, inserito il testo grezzo."
                    clean = LocalCleaner.clean(raw)
                }
            } else {
                softError = "Manca la chiave Anthropic: inserito il testo grezzo."
                clean = LocalCleaner.clean(raw)
            }
        }

        guard !clean.isEmpty else {
            show(.error("Nessun testo da inserire."))
            return
        }

        show(.inserting)
        await TextInserter.insert(clean, snapshot: snapshot, preferAccessibility: data.useAccessibilityInsert)

        history.append(HistoryEntry(
            date: Date(),
            appName: snapshot.appName,
            bundleId: snapshot.bundleId,
            language: detectedLanguage,
            raw: raw,
            clean: clean,
            commandMode: context.isCommandMode
        ))

        if let softError {
            show(.error(softError), autoHide: 2.5)
        } else {
            show(.done, autoHide: 0.9)
        }
    }

    // MARK: - Pill

    private func show(_ newState: PillState, autoHide: TimeInterval? = nil) {
        hideTask?.cancel()
        state = newState
        pill.show()
        if case .error = newState, autoHide == nil {
            hideTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                self?.hide()
            }
        } else if let autoHide {
            hideTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(autoHide * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.hide()
            }
        }
    }

    private func hide() {
        state = .hidden
        pill.hide()
    }
}

// MARK: - HotkeyManagerDelegate (chiamato sul main run loop dall'event tap)

extension DictationController: HotkeyManagerDelegate {
    nonisolated func hotkeyPressed() {
        Task { @MainActor in self.hotkeyDown() }
    }

    nonisolated func hotkeyReleased() {
        Task { @MainActor in self.hotkeyUp() }
    }

    nonisolated func escapePressed() -> Bool {
        // L'event tap gira sul main run loop: possiamo assumere l'isolamento al main actor.
        MainActor.assumeIsolated { self.escape() }
    }
}
