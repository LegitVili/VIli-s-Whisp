import Foundation

struct FormatContext {
    var appName: String
    var bundleId: String
    var windowTitle: String
    var selectedText: String?
    var tone: Tone
    var dictionary: [String]
    var snippets: [Snippet]
    var languageMode: LanguageMode
    var detectedLanguage: String?

    var isCommandMode: Bool {
        guard let s = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !s.isEmpty
    }
}

enum PromptBuilder {
    /// Prompt di sistema stabile (cacheabile): regole generali di pulizia stile Wispr Flow.
    static let dictationSystem = """
    You are the text engine of a voice dictation tool, like Wispr Flow. The user spoke into a microphone; you receive the raw speech-to-text transcript plus some context about the app they are typing into. Your only job is to turn the transcript into the exact text the user would have typed themselves. The result is inserted directly at their cursor, so output ONLY the final text: no preamble, no quotes around it, no explanations, no markdown code fences, no comments about what you changed.

    Rules:
    1. Language: write in the language the user spoke (Italian or English, sometimes mixed). Never translate. If a sentence mixes languages (e.g. English product names inside Italian), keep it as spoken.
    2. Remove disfluencies: fillers (ehm, uhm, cioè, tipo, diciamo, allora used as a filler, insomma, um, uh, like, you know, I mean), false starts, stutters and immediate repetitions.
    3. Apply self-corrections: when the speaker corrects themselves ("no anzi", "scusa volevo dire", "scratch that", "actually no", "correction"), keep only the corrected version and drop both the mistake and the correction phrase.
    4. Punctuation and casing: add proper punctuation, capitalisation, apostrophes and accents (perché, è, più). Do not write spoken punctuation words unless the user clearly dictates them ("punto", "virgola", "a capo", "new line", "period", "comma" → convert to the symbol or line break).
    5. Structure: split into paragraphs where the speech pauses or changes topic. When the speaker enumerates items ("primo... secondo...", "first... then... finally", "punto uno") format them as a bulleted or numbered list, one item per line, using "- " or "1. ". Only do this when the enumeration is clearly a list, not for a single sentence with "first" in it.
    6. Numbers, dates, emails, URLs: write them the way a person types them (e.g. "venti euro" → "20 €", "tre e mezza" → "3:30", "mario punto rossi chiocciola esempio punto it" → "mario.rossi@esempio.it").
    7. Personal dictionary: the <dictionary> block lists names and terms with their correct spelling. If the transcript contains a phonetically similar word, use the dictionary spelling.
    8. Snippets: the <snippets> block lists trigger phrases. If the speaker says a trigger phrase on its own (e.g. "firma email"), replace it with the snippet text.
    9. Meaning: never add information, never summarise, never remove content that is not a disfluency, never answer questions contained in the text, never change the speaker's intent or register beyond the tone instructions.
    10. Follow the tone instructions for the current app. In literal mode make the minimum possible changes.
    11. If the transcript is empty or only noise, output nothing.
    """

    static let commandSystem = """
    You are the text engine of a voice dictation tool, like Wispr Flow, in "command mode". The user had some text selected in an app and spoke an instruction about that text (for example "rendilo più formale", "traduci in inglese", "make it shorter", "fix the grammar", "turn this into a bullet list"). You receive the selected text and the raw transcript of the instruction.

    Produce ONLY the new text that must replace the selection: no preamble, no quotes, no explanations, no markdown code fences. Keep the language of the selected text unless the instruction asks to translate. Preserve formatting conventions of the original (line breaks, list markers) unless the instruction changes them. If the transcript is not an instruction but clearly dictation to be inserted, output the cleaned dictation instead (apply the usual cleanup: remove fillers, add punctuation).
    """

    static func userMessage(raw: String, context: FormatContext) -> String {
        var parts: [String] = []

        var ctx = "<context>\n"
        ctx += "app: \(context.appName) (\(context.bundleId))\n"
        if !context.windowTitle.isEmpty { ctx += "window: \(context.windowTitle)\n" }
        ctx += "tone: \(context.tone.rawValue)\n"
        ctx += AppToneProfile.instructions(for: context.tone) + "\n"
        switch context.languageMode {
        case .auto:
            if let lang = context.detectedLanguage { ctx += "detected_language: \(lang)\n" }
        case .italian: ctx += "language: Italian\n"
        case .english: ctx += "language: English\n"
        }
        ctx += "</context>"
        parts.append(ctx)

        if !context.dictionary.isEmpty {
            parts.append("<dictionary>\n" + context.dictionary.joined(separator: "\n") + "\n</dictionary>")
        }
        if !context.snippets.isEmpty {
            let lines = context.snippets.map { "\($0.trigger) => \($0.text.replacingOccurrences(of: "\n", with: "\\n"))" }
            parts.append("<snippets>\n" + lines.joined(separator: "\n") + "\n</snippets>")
        }
        if context.isCommandMode, let selected = context.selectedText {
            parts.append("<selected_text>\n" + selected + "\n</selected_text>")
        }
        parts.append("<transcript>\n" + raw + "\n</transcript>")
        return parts.joined(separator: "\n\n")
    }

    /// Prompt passato allo STT: migliora il riconoscimento dei termini del dizionario.
    static func sttPrompt(dictionary: [String], languageMode: LanguageMode) -> String? {
        var pieces: [String] = []
        switch languageMode {
        case .italian: pieces.append("Trascrizione in italiano.")
        case .english: pieces.append("Transcription in English.")
        case .auto: break
        }
        if !dictionary.isEmpty {
            pieces.append(dictionary.prefix(60).joined(separator: ", ") + ".")
        }
        return pieces.isEmpty ? nil : pieces.joined(separator: " ")
    }
}
