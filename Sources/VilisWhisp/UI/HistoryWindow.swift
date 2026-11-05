import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSWindowController {
    static let shared = HistoryWindowController()

    private init() {
        let hosting = NSHostingController(rootView: HistoryView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Vili's Whisp — Cronologia"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 640, height: 480))
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

struct HistoryView: View {
    @ObservedObject private var history = HistoryStore.shared
    @State private var query = ""
    @State private var showRaw = false

    private var filtered: [HistoryEntry] {
        guard !query.isEmpty else { return history.entries }
        return history.entries.filter {
            $0.clean.localizedCaseInsensitiveContains(query) || $0.raw.localizedCaseInsensitiveContains(query) || $0.appName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Cerca…", text: $query).textFieldStyle(.roundedBorder)
                Toggle("Mostra trascritto grezzo", isOn: $showRaw).toggleStyle(.checkbox)
                Button("Svuota") { history.clear() }.disabled(history.entries.isEmpty)
            }
            .padding(12)
            Divider()
            if filtered.isEmpty {
                Spacer()
                Text(history.entries.isEmpty ? "Ancora nessuna dettatura." : "Nessun risultato.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(filtered) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(entry.appName).font(.caption).bold()
                            if entry.commandMode {
                                Text("comando").font(.caption2).padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                            }
                            if let lang = entry.language {
                                Text(lang.uppercased()).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.date, format: .dateTime.day().month().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.clean, forType: .string)
                            } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.borderless)
                            .help("Copia")
                            Button {
                                history.delete(entry)
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                        }
                        Text(entry.clean).textSelection(.enabled)
                        if showRaw {
                            Text(entry.raw).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}
