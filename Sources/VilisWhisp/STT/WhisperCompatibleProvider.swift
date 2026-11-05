import Foundation

/// Provider per endpoint compatibili con OpenAI `/audio/transcriptions` (Groq, OpenAI).
struct WhisperCompatibleProvider: TranscriptionProvider {
    let name: String
    let endpoint: URL
    let apiKey: String
    let model: String
    let responseFormat: String
    var timeout: TimeInterval = 30

    func transcribe(wav: Data, languageHint: String?, prompt: String?) async throws -> TranscriptionResult {
        var form = MultipartForm()
        form.addFile("file", filename: "audio.wav", mimeType: "audio/wav", data: wav)
        form.addField("model", value: model)
        form.addField("response_format", value: responseFormat)
        form.addField("temperature", value: "0")
        if let languageHint, !languageHint.isEmpty {
            form.addField("language", value: languageHint)
        }
        if let prompt, !prompt.isEmpty {
            form.addField("prompt", value: prompt)
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.finalize()

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
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw WhispError.badResponse(String(decoding: data.prefix(200), as: UTF8.self))
        }
        let language = json["language"] as? String
        Log.net.info("\(name, privacy: .public) STT ok in \(Date().timeIntervalSince(started), privacy: .public)s, lang=\(language ?? "?", privacy: .public)")
        return TranscriptionResult(text: text.trimmingCharacters(in: .whitespacesAndNewlines), language: language)
    }
}
