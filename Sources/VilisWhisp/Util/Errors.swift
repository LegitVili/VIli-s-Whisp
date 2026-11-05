import Foundation

enum WhispError: LocalizedError {
    case missingAPIKey(String)
    case http(Int, String)
    case network(String)
    case badResponse(String)
    case noAudio
    case tooShort
    case refusal
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p): return "Manca la chiave API per \(p). Aprila dalle Impostazioni."
        case .http(let code, let body): return "Errore HTTP \(code): \(body.prefix(200))"
        case .network(let msg): return "Errore di rete: \(msg)"
        case .badResponse(let msg): return "Risposta non valida: \(msg)"
        case .noAudio: return "Nessun audio registrato. Controlla il microfono."
        case .tooShort: return "Registrazione troppo breve."
        case .refusal: return "Il modello ha rifiutato la richiesta."
        case .timeout: return "Tempo scaduto."
        }
    }
}
