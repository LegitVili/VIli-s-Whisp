import AppKit
import Combine
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller: DictationController
    private var hotkey: HotkeyManager!
    private var cancellables = Set<AnyCancellable>()
    private var permissionTimer: Timer?
    private var handsFreeItem: NSMenuItem!

    override init() {
        controller = DictationController()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()

        hotkey = HotkeyManager(choice: Settings.shared.data.hotkey)
        hotkey.delegate = controller

        Settings.shared.$data
            .map(\.hotkey)
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] choice in self?.restartHotkey(choice) }
            .store(in: &cancellables)

        controller.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in self?.updateIcon(for: state) }
            .store(in: &cancellables)

        Task { await bootstrapPermissions() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkey?.stop()
    }

    // MARK: - Permessi e avvio hotkey

    private func bootstrapPermissions() async {
        if Permissions.microphoneStatus() == .notDetermined {
            _ = await Permissions.requestMicrophone()
        }
        if !Permissions.inputMonitoringGranted() {
            Permissions.requestInputMonitoring()
        }
        if !Permissions.accessibilityGranted(prompt: true) {
            showPermissionsAlert()
        }
        startHotkeyOrWait()
    }

    private func startHotkeyOrWait() {
        if hotkey.start() {
            permissionTimer?.invalidate()
            permissionTimer = nil
            return
        }
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if Permissions.accessibilityGranted(), self.hotkey.start() {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                    Log.app.info("Hotkey attiva dopo concessione permessi")
                }
            }
        }
    }

    private func restartHotkey(_ choice: HotkeyChoice) {
        hotkey.stop()
        hotkey.choice = choice
        startHotkeyOrWait()
    }

    private func showPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Vili's Whisp ha bisogno di due permessi"
        alert.informativeText = """
        1. Accessibilità: per rilevare il tasto di dettatura e inserire il testo nell'app attiva.
        2. Microfono: per registrare la voce mentre tieni premuto il tasto.

        Aggiungi “VilisWhisp” in Impostazioni di Sistema → Privacy e sicurezza → Accessibilità, poi torna qui: l'app si attiverà da sola.
        """
        alert.addButton(withTitle: "Apri Accessibilità")
        alert.addButton(withTitle: "Più tardi")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            Permissions.openAccessibilitySettings()
        }
    }

    // MARK: - Menu principale (invisibile, ma necessario perche' ⌘C/⌘V/⌘A funzionino nelle finestre)

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Esci da Vili's Whisp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Modifica")
        editMenu.addItem(withTitle: "Annulla", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Ripeti", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Taglia", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copia", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Incolla", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Seleziona tutto", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Finestra")
        windowMenu.addItem(withTitle: "Chiudi", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Contrai", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(for: .hidden)

        let menu = NSMenu()
        let title = NSMenuItem(title: "Vili's Whisp — tieni premuto \(Settings.shared.data.hotkey.label)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        handsFreeItem = NSMenuItem(title: "Avvia dettatura mani libere", action: #selector(toggleHandsFree), keyEquivalent: "")
        handsFreeItem.target = self
        menu.addItem(handsFreeItem)

        menu.addItem(.separator())

        let history = NSMenuItem(title: "Cronologia…", action: #selector(openHistory), keyEquivalent: "h")
        history.target = self
        menu.addItem(history)

        let settings = NSMenuItem(title: "Impostazioni…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let perms = NSMenuItem(title: "Permessi", action: nil, keyEquivalent: "")
        let permsMenu = NSMenu()
        let ax = NSMenuItem(title: "Accessibilità…", action: #selector(openAX), keyEquivalent: "")
        ax.target = self
        let mic = NSMenuItem(title: "Microfono…", action: #selector(openMic), keyEquivalent: "")
        mic.target = self
        let input = NSMenuItem(title: "Monitoraggio input…", action: #selector(openInput), keyEquivalent: "")
        input.target = self
        permsMenu.addItem(ax)
        permsMenu.addItem(mic)
        permsMenu.addItem(input)
        perms.submenu = permsMenu
        menu.addItem(perms)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Esci", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        menu.delegate = self
        statusItem.menu = menu
    }

    private func updateIcon(for state: PillState) {
        let name: String
        switch state {
        case .hidden: name = "waveform"
        case .listening: name = "waveform.circle.fill"
        case .transcribing, .formatting, .inserting: name = "ellipsis.circle"
        case .done: name = "checkmark.circle"
        case .error: name = "exclamationmark.circle"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Vili's Whisp")
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func toggleHandsFree() {
        controller.toggleHandsFree()
    }

    @objc private func openHistory() {
        HistoryWindowController.shared.show()
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openAX() { Permissions.openAccessibilitySettings() }
    @objc private func openMic() { Permissions.openMicrophoneSettings() }
    @objc private func openInput() { Permissions.openInputMonitoringSettings() }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let title = menu.items.first {
            title.title = "Vili's Whisp — tieni premuto \(Settings.shared.data.hotkey.label)"
        }
        handsFreeItem.title = controller.recorder.isRecording ? "Termina dettatura mani libere" : "Avvia dettatura mani libere"
    }
}
