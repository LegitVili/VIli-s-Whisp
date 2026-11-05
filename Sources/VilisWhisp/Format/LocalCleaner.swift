import Foundation

/// Pulizia locale minima usata quando Claude non e' disponibile o e' disattivato.
enum LocalCleaner {
    private static let fillers: [String] = [
        // italiano
        "ehm", "ehmm", "ehmmm", "uhm", "uhmm", "mmm", "mh", "ah", "eh", "cioè", "cioe", "tipo", "diciamo", "insomma", "niente", "praticamente", "allora",
        // inglese
        "um", "umm", "uh", "uhh", "hmm", "like", "you know", "i mean", "sort of", "kind of", "basically", "actually", "literally",
    ]

    static func clean(_ raw: String) -> String {
        var text = raw
        for filler in fillers {
            let pattern = "(?i)(?<![\\p{L}])" + NSRegularExpression.escapedPattern(for: filler) + "(?![\\p{L}])[,.]?\\s*"
            if let re = try? NSRegularExpression(pattern: pattern) {
                text = re.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
            }
        }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "^[,.;:\\s]+", with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = text.first else { return "" }
        text = first.uppercased() + text.dropFirst()
        if let last = text.last, !".!?…\"')".contains(last) {
            text += "."
        }
        return text
    }
}
