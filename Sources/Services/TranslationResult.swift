import Foundation

struct TranslationResult: Sendable, Equatable {
    let text: String
    var pronunciations: [WordPronunciation] = []
}

struct WordPronunciation: Sendable, Equatable {
    enum Kind: Sendable, Hashable {
        case british, american, source, target

        var label: String {
            switch self {
            case .british: String(localized: "UK pronunciation")
            case .american: String(localized: "US pronunciation")
            case .source: String(localized: "Source pronunciation")
            case .target: String(localized: "Translation pronunciation")
            }
        }
    }

    let kind: Kind
    let text: String

    init?(kind: Kind, text: String?) {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        self.kind = kind
        self.text = text
    }

    static func isSingleWord(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 64 else { return false }
        return trimmed.range(
            of: #"^\p{L}[\p{L}\p{M}]*(?:[-'\u2019][\p{L}\p{M}]+)*$"#,
            options: .regularExpression
        ) != nil
    }
}
