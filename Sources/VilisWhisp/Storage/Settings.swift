import Foundation
import Combine

enum STTProvider: String, Codable, CaseIterable, Identifiable {
    case groq, openai
    var id: String { rawValue }
    var label: String {
        switch self {
        case .groq: return "Groq (Whisper large-v3-turbo)"
        case .openai: return "OpenAI (gpt-4o-mini-transcribe)"
        }
    }
    var keychainAccount: Keychain.Account {
        switch self {
        case .groq: return .groq
        case .openai: return .openai
        }
    }
}

enum HotkeyChoice: String, Codable, CaseIterable, Identifiable {
    case fn, rightOption, rightCommand, f13, f18
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fn: return "fn (Globe)"
        case .rightOption: return "Option destro (⌥)"
        case .rightCommand: return "Command destro (⌘)"
        case .f13: return "F13"
        case .f18: return "F18"
        }
    }
}

enum LanguageMode: String, Codable, CaseIterable, Identifiable {
    case auto, italian, english
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "Automatica (italiano / inglese)"
        case .italian: return "Solo italiano"
        case .english: return "Solo inglese"
        }
    }
    /// Codice ISO da passare allo STT; nil = rilevamento automatico.
    var isoCode: String? {
        switch self {
        case .auto: return nil
        case .italian: return "it"
        case .english: return "en"
        }
    }
}

enum Tone: String, Codable, CaseIterable, Identifiable {
    case neutral, casual, formal, literal
    var id: String { rawValue }
    var label: String {
        switch self {
        case .neutral: return "Neutro"
        case .casual: return "Informale (chat)"
        case .formal: return "Formale (email)"
        case .literal: return "Letterale (codice / terminale)"
        }
    }
}

struct DictionaryEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var term: String
}

struct Snippet: Codable, Identifiable, Hashable {
    var id = UUID()
    var trigger: String
    var text: String
}

struct AppToneOverride: Codable, Identifiable, Hashable {
    var id = UUID()
    var bundleId: String
    var tone: Tone
}

struct SettingsData: Codable {
    var sttProvider: STTProvider = .groq
    var groqModel: String = "whisper-large-v3-turbo"
    var openaiModel: String = "gpt-4o-mini-transcribe"
    var claudeModel: String = "claude-haiku-5-5"
    var skipFormatting: Bool = false
    var hotkey: HotkeyChoice = .fn
    var handsFreeDoubleTap: Bool = true
    var languageMode: LanguageMode = .auto
    var launchAtLogin: Bool = false
    var playSounds: Bool = true
    var useAccessibilityInsert: Bool = true
    var dictionary: [DictionaryEntry] = []
    var snippets: [Snippet] = []
    var toneOverrides: [AppToneOverride] = []
    var defaultTone: Tone = .neutral
    var minimumDuration: Double = 0.4
}

final class Settings: ObservableObject {
    static let shared = Settings()
    private static let key = "it.vili.whisp.settings.v1"

    @Published var data: SettingsData {
        didSet { persist() }
    }

    private init() {
        if let raw = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(SettingsData.self, from: raw) {
            data = decoded
        } else {
            data = SettingsData()
        }
    }

    private func persist() {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: Self.key)
        }
    }

    var dictionaryTerms: [String] {
        data.dictionary.map { $0.term.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
