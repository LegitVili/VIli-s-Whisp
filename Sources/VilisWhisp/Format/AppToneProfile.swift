import Foundation

/// Mappa l'app attiva a un tono di scrittura, come fa Wispr Flow (chat informale, email formale, editor letterale).
enum AppToneProfile {
    static let defaults: [String: Tone] = [
        // Chat / messaggistica → informale
        "com.tinyspeck.slackmacgap": .casual,
        "net.whatsapp.WhatsApp": .casual,
        "ru.keepcoder.Telegram": .casual,
        "org.telegram.desktop": .casual,
        "com.apple.MobileSMS": .casual,
        "com.hnc.Discord": .casual,
        "com.microsoft.teams2": .casual,
        "com.facebook.archon": .casual,
        // Email → formale
        "com.apple.mail": .formal,
        "com.microsoft.Outlook": .formal,
        "com.readdle.smartemail-Mac": .formal,
        "com.superhuman.electron": .formal,
        "com.airmail.mac": .formal,
        // Editor di codice / terminali → letterale
        "com.apple.dt.Xcode": .literal,
        "com.microsoft.VSCode": .literal,
        "com.todesktop.230313mzl4w4u92": .literal, // Cursor
        "com.jetbrains.intellij": .literal,
        "com.jetbrains.pycharm": .literal,
        "com.jetbrains.WebStorm": .literal,
        "com.sublimetext.4": .literal,
        "com.apple.Terminal": .literal,
        "com.googlecode.iterm2": .literal,
        "dev.warp.Warp-Stable": .literal,
        "com.github.wez.wezterm": .literal,
        "net.kovidgoyal.kitty": .literal,
        "org.alacritty": .literal,
        // Documenti / note → neutro strutturato
        "com.apple.Notes": .neutral,
        "com.apple.iWork.Pages": .neutral,
        "com.microsoft.Word": .neutral,
        "notion.id": .neutral,
        "md.obsidian": .neutral,
        "com.apple.TextEdit": .neutral,
    ]

    static func tone(for bundleId: String, settings: SettingsData) -> Tone {
        if let override = settings.toneOverrides.first(where: { $0.bundleId.caseInsensitiveCompare(bundleId) == .orderedSame }) {
            return override.tone
        }
        if let t = defaults[bundleId] { return t }
        let lower = bundleId.lowercased()
        if lower.contains("jetbrains") || lower.contains("terminal") || lower.contains("code") { return .literal }
        if lower.contains("mail") { return .formal }
        return settings.defaultTone
    }

    static func instructions(for tone: Tone) -> String {
        switch tone {
        case .casual:
            return "Tone: conversational and relaxed, as in a chat message. Short sentences are fine. Keep emojis only if the speaker explicitly says them. No greeting or sign-off unless spoken."
        case .formal:
            return "Tone: polished and professional, as in a business email. Complete sentences, proper paragraphs. Do not invent greetings or signatures that were not spoken."
        case .literal:
            return "Tone: literal. The user is in a code editor or terminal. Keep wording exactly as spoken after removing fillers; do not rephrase, do not add punctuation beyond what is clearly implied, keep technical terms, identifiers and symbols verbatim (e.g. 'underscore', 'dot' may be spoken literally: write them as symbols only when it is obvious)."
        case .neutral:
            return "Tone: clear and neutral, as in a note or document. Use paragraphs and lists where the structure of the speech suggests them."
        }
    }
}
