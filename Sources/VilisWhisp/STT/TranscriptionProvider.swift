import Foundation

struct TranscriptionResult {
    let text: String
    /// Codice lingua rilevato dal provider (es. "it", "en"), se disponibile.
    let language: String?
}

protocol TranscriptionProvider {
    var name: String { get }
    func transcribe(wav: Data, languageHint: String?, prompt: String?) async throws -> TranscriptionResult
}

enum TranscriptionProviderFactory {
    static func make(from settings: SettingsData) throws -> TranscriptionProvider {
        switch settings.sttProvider {
        case .groq:
            guard let key = Keychain.get(.groq), !key.isEmpty else { throw WhispError.missingAPIKey("Groq") }
            return WhisperCompatibleProvider(
                name: "Groq",
                endpoint: URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!,
                apiKey: key,
                model: settings.groqModel,
                responseFormat: "verbose_json"
            )
        case .openai:
            guard let key = Keychain.get(.openai), !key.isEmpty else { throw WhispError.missingAPIKey("OpenAI") }
            // I modelli gpt-4o-*-transcribe accettano solo json/text; whisper-1 accetta anche verbose_json.
            let format = settings.openaiModel.hasPrefix("whisper") ? "verbose_json" : "json"
            return WhisperCompatibleProvider(
                name: "OpenAI",
                endpoint: URL(string: "https://api.openai.com/v1/audio/transcriptions")!,
                apiKey: key,
                model: settings.openaiModel,
                responseFormat: format
            )
        }
    }
}
