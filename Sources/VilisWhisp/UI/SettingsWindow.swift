import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vili's Whisp — Impostazioni"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 600, height: 520))
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) non supportato") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings)
                .tabItem { Label("Generale", systemImage: "gearshape") }
            ProviderSettingsTab(settings: settings)
                .tabItem { Label("Provider", systemImage: "key") }
            DictionaryTab(settings: settings)
                .tabItem { Label("Dizionario", systemImage: "character.book.closed") }
            SnippetsTab(settings: settings)
                .tabItem { Label("Snippet", systemImage: "text.badge.plus") }
            TonesTab(settings: settings)
                .tabItem { Label("Toni per app", systemImage: "app.badge") }
        }
        .padding(16)
        .frame(minWidth: 600, minHeight: 520)
    }
}

// MARK: - Generale

private struct GeneralSettingsTab: View {
    @ObservedObject var settings: Settings
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Dettatura") {
                Picker("Tasto di dettatura", selection: $settings.data.hotkey) {
                    ForEach(HotkeyChoice.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Doppio tocco per la modalità mani libere", isOn: $settings.data.handsFreeDoubleTap)
                Picker("Lingua", selection: $settings.data.languageMode) {
                    ForEach(LanguageMode.allCases) { Text($0.label).tag($0) }
                }
                Picker("Tono predefinito (app sconosciute)", selection: $settings.data.defaultTone) {
                    ForEach(Tone.allCases) { Text($0.label).tag($0) }
                }
                HStack {
                    Text("Durata minima")
                    Slider(value: $settings.data.minimumDuration, in: 0.2...1.5, step: 0.1)
                    Text(String(format: "%.1f s", settings.data.minimumDuration)).monospacedDigit().frame(width: 44)
                }
            }
            Section("Inserimento") {
                Toggle("Usa Accessibility sui campi di testo nativi (altrimenti incolla con ⌘V)", isOn: $settings.data.useAccessibilityInsert)
                Toggle("Suoni di inizio/fine registrazione", isOn: $settings.data.playSounds)
            }
            Section("Sistema") {
                Toggle("Avvia al login", isOn: Binding(
                    get: { settings.data.launchAtLogin },
                    set: { newValue in
                        settings.data.launchAtLogin = newValue
                        do {
                            if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch {
                            loginError = error.localizedDescription
                        }
                    }
                ))
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    Button("Permessi Accessibility…") { Permissions.openAccessibilitySettings() }
                    Button("Permessi Microfono…") { Permissions.openMicrophoneSettings() }
                    Button("Monitoraggio input…") { Permissions.openInputMonitoringSettings() }
                }
                permissionStatus
            }
        }
        .formStyle(.grouped)
    }

    private var permissionStatus: some View {
        HStack(spacing: 14) {
            statusDot("Accessibility", ok: Permissions.accessibilityGranted())
            statusDot("Microfono", ok: Permissions.microphoneStatus() == .authorized)
            statusDot("Input", ok: Permissions.inputMonitoringGranted())
        }
        .font(.caption)
    }

    private func statusDot(_ name: String, ok: Bool) -> some View {
        HStack(spacing: 4) {
            Circle().fill(ok ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(name)
        }
    }
}

// MARK: - Provider

private struct ProviderSettingsTab: View {
    @ObservedObject var settings: Settings
    @State private var groqKey = Keychain.get(.groq) ?? ""
    @State private var openaiKey = Keychain.get(.openai) ?? ""
    @State private var anthropicKey = Keychain.get(.anthropic) ?? ""
    @State private var sttTestResult: String?
    @State private var claudeTestResult: String?
    @State private var testing = false

    var body: some View {
        Form {
            Section("Trascrizione (speech-to-text)") {
                Picker("Provider", selection: $settings.data.sttProvider) {
                    ForEach(STTProvider.allCases) { Text($0.label).tag($0) }
                }
                switch settings.data.sttProvider {
                case .groq:
                    SecureField("Groq API key (gsk_…)", text: $groqKey)
                        .onChange(of: groqKey) { _, v in _ = Keychain.set(v, for: .groq) }
                    TextField("Modello", text: $settings.data.groqModel)
                case .openai:
                    SecureField("OpenAI API key (sk-…)", text: $openaiKey)
                        .onChange(of: openaiKey) { _, v in _ = Keychain.set(v, for: .openai) }
                    TextField("Modello", text: $settings.data.openaiModel)
                }
                HStack {
                    Button("Testa connessione") { testSTT() }.disabled(testing)
                    if let sttTestResult { Text(sttTestResult).font(.caption).foregroundStyle(.secondary) }
                }
            }
            Section("Formattazione (Claude)") {
                SecureField("Anthropic API key (sk-ant-…)", text: $anthropicKey)
                    .onChange(of: anthropicKey) { _, v in _ = Keychain.set(v, for: .anthropic) }
                TextField("Modello", text: $settings.data.claudeModel)
                Text("claude-haiku-5-5 è il più veloce (consigliato per la dettatura); claude-opus-5-5 dà la qualità massima con più latenza.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Salta la formattazione (solo trascrizione + pulizia locale)", isOn: $settings.data.skipFormatting)
                HStack {
                    Button("Testa connessione") { testClaude() }.disabled(testing || settings.data.skipFormatting)
                    if let claudeTestResult { Text(claudeTestResult).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func testSTT() {
        testing = true
        sttTestResult = "Verifico…"
        Task { @MainActor in
            defer { testing = false }
            do {
                let provider = try TranscriptionProviderFactory.make(from: settings.data)
                // mezzo secondo di silenzio: basta a verificare chiave ed endpoint
                let silence = WAVEncoder.encode(samples: [Int16](repeating: 0, count: 8000))
                _ = try await provider.transcribe(wav: silence, languageHint: nil, prompt: nil)
                sttTestResult = "✅ \(provider.name): chiave valida"
            } catch {
                sttTestResult = "❌ \(error.localizedDescription)"
            }
        }
    }

    private func testClaude() {
        testing = true
        claudeTestResult = "Verifico…"
        Task { @MainActor in
            defer { testing = false }
            guard let key = Keychain.get(.anthropic), !key.isEmpty else {
                claudeTestResult = "❌ Inserisci la chiave Anthropic"
                return
            }
            do {
                let out = try await ClaudeFormatter.test(apiKey: key, model: settings.data.claudeModel)
                claudeTestResult = "✅ \(out)"
            } catch {
                claudeTestResult = "❌ \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Dizionario

private struct DictionaryTab: View {
    @ObservedObject var settings: Settings
    @State private var newTerm = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nomi propri, prodotti, termini tecnici: verranno riconosciuti e scritti con questa grafia.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Nuovo termine (es. Fireflow)", text: $newTerm)
                    .onSubmit(add)
                Button("Aggiungi", action: add).disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            List {
                ForEach($settings.data.dictionary) { $entry in
                    HStack {
                        TextField("Termine", text: $entry.term)
                        Spacer()
                        Button {
                            settings.data.dictionary.removeAll { $0.id == entry.id }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 260)
        }
        .padding(.top, 8)
    }

    private func add() {
        let t = newTerm.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        settings.data.dictionary.append(DictionaryEntry(term: t))
        newTerm = ""
    }
}

// MARK: - Snippet

private struct SnippetsTab: View {
    @ObservedObject var settings: Settings
    @State private var trigger = ""
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pronuncia il trigger da solo (es. “firma email”) e verrà sostituito con il testo.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top) {
                TextField("Trigger", text: $trigger).frame(width: 160)
                TextField("Testo (usa ⇧↩ per andare a capo)", text: $text, axis: .vertical).lineLimit(1...4)
                Button("Aggiungi", action: add)
                    .disabled(trigger.trimmingCharacters(in: .whitespaces).isEmpty || text.isEmpty)
            }
            List {
                ForEach($settings.data.snippets) { $snippet in
                    HStack(alignment: .top) {
                        TextField("Trigger", text: $snippet.trigger).frame(width: 160)
                        TextField("Testo", text: $snippet.text, axis: .vertical).lineLimit(1...6)
                        Button {
                            settings.data.snippets.removeAll { $0.id == snippet.id }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 260)
        }
        .padding(.top, 8)
    }

    private func add() {
        settings.data.snippets.append(Snippet(trigger: trigger.trimmingCharacters(in: .whitespaces), text: text))
        trigger = ""
        text = ""
    }
}

// MARK: - Toni per app

private struct TonesTab: View {
    @ObservedObject var settings: Settings
    @State private var bundleId = ""
    @State private var tone: Tone = .neutral

    private var runningApps: [(name: String, bundleId: String)] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> (String, String)? in
                guard let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier else { return nil }
                return (app.localizedName ?? id, id)
            }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Chat → informale, email → formale, editor/terminale → letterale. Qui puoi sovrascrivere il tono per singola app.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                TextField("Bundle id (es. com.apple.mail)", text: $bundleId)
                Menu("App aperte") {
                    ForEach(runningApps, id: \.bundleId) { app in
                        Button("\(app.name) — \(app.bundleId)") { bundleId = app.bundleId }
                    }
                }
                .frame(width: 120)
                Picker("", selection: $tone) {
                    ForEach(Tone.allCases) { Text($0.label).tag($0) }
                }
                .frame(width: 190)
                Button("Aggiungi") {
                    let id = bundleId.trimmingCharacters(in: .whitespaces)
                    guard !id.isEmpty else { return }
                    settings.data.toneOverrides.removeAll { $0.bundleId == id }
                    settings.data.toneOverrides.append(AppToneOverride(bundleId: id, tone: tone))
                    bundleId = ""
                }
            }
            List {
                ForEach($settings.data.toneOverrides) { $item in
                    HStack {
                        Text(item.bundleId).font(.system(.body, design: .monospaced))
                        Spacer()
                        Picker("", selection: $item.tone) {
                            ForEach(Tone.allCases) { Text($0.label).tag($0) }
                        }
                        .frame(width: 190)
                        Button {
                            settings.data.toneOverrides.removeAll { $0.id == item.id }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 240)
        }
        .padding(.top, 8)
    }
}
