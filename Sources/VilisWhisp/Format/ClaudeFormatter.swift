import Foundation

/// Chiama la Claude Messages API via HTTP per trasformare il trascritto grezzo nel testo finale.
struct ClaudeFormatter {
    let apiKey: String
    let model: String
    var timeout: TimeInterval = 20

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2026-10-21"

    func format(raw: String, context: FormatContext) async throws -> String {
        let system = context.isCommandMode ? PromptBuilder.commandSystem : PromptBuilder.dictationSystem
        let user = PromptBuilder.userMessage(raw: raw, context: context)

        var body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": [
                ["type": "text", "text": system, "cache_control": ["type": "ephemeral"]],
            ],
            "messages": [
                ["role": "user", "content": user],
            ],
            "output_config": ["effort": "low"],
        ]
        // Sui modelli Haiku la disattivazione del thinking e' accettata a effort basso e riduce la latenza.
        // Sugli altri modelli (Opus/Sonnet 5.x) "disabled" e' rifiutato: si lascia l'adaptive thinking con effort low.
        if model.hasPrefix("claude-haiku") {
            body["thinking"] = ["type": "disabled"]
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let started = Date()
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WhispError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw WhispError.badResponse("no HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            throw WhispError.http(http.statusCode, String(decoding: data, as: UTF8.self))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WhispError.badResponse("JSON non valido")
        }
        if let stop = json["stop_reason"] as? String, stop == "refusal" {
            throw WhispError.refusal
        }
        guard let content = json["content"] as? [[String: Any]] else {
            throw WhispError.badResponse("campo content mancante")
        }
        let text = content
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        Log.net.info("Claude \(model, privacy: .public) ok in \(Date().timeIntervalSince(started), privacy: .public)s")
        return Self.strip(text)
    }

    /// Rimuove eventuali virgolette o fence che il modello potrebbe aggiungere nonostante le istruzioni.
    private static func strip(_ text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```") {
            t = t.replacingOccurrences(of: "^```[a-zA-Z]*\\n?", with: "", options: .regularExpression)
            t = t.replacingOccurrences(of: "\\n?```$", with: "", options: .regularExpression)
            t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return t
    }

    /// Verifica rapida della chiave (usata dal pulsante "Testa connessione").
    static func test(apiKey: String, model: String) async throws -> String {
        let f = ClaudeFormatter(apiKey: apiKey, model: model, timeout: 15)
        let ctx = FormatContext(appName: "Test", bundleId: "it.vili.whisp", windowTitle: "", selectedText: nil,
                                tone: .neutral, dictionary: [], snippets: [], languageMode: .auto, detectedLanguage: nil)
        return try await f.format(raw: "ciao ehm questa è una prova cioè funziona", context: ctx)
    }
}
