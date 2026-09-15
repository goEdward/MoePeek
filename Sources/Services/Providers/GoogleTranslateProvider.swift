import Foundation
import SwiftUI

/// Google Translate provider using the free GTX API (no API key required).
struct GoogleTranslateProvider: PronunciationTranslationProvider {
    let id = "google"
    let displayName = "Google Translate"
    let iconSystemName = "g.circle.fill"
    let iconAssetName: String? = "Google"
    let category: ProviderCategory = .freeTranslation
    let supportsStreaming = false
    let isAvailable = true

    @MainActor
    var isConfigured: Bool { true }

    @MainActor
    func makeSettingsView() -> AnyView {
        AnyView(GoogleTranslateSettingsView())
    }

    // MARK: - Translation

    func translateResult(_ text: String, from sourceLang: String?, to targetLang: String) async throws -> TranslationResult {
        let sl = LanguageCodeMapping.resolve(sourceLang, using: LanguageCodeMapping.google) ?? "auto"
        let tl = LanguageCodeMapping.resolveTarget(targetLang, using: LanguageCodeMapping.google)

        guard var components = URLComponents(string: "https://translate.google.com/translate_a/single") else {
            throw TranslationError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sl),
            URLQueryItem(name: "tl", value: tl),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "dj", value: "1"),
            URLQueryItem(name: "ie", value: "UTF-8"),
            URLQueryItem(name: "q", value: text),
        ]
        if WordPronunciation.isSingleWord(text) {
            components.queryItems?.append(URLQueryItem(name: "dt", value: "rm"))
        }

        guard let url = components.url else {
            throw TranslationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, response) = try await translationURLSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw TranslationError.apiError(statusCode: httpResponse.statusCode, message: String(data: data, encoding: .utf8) ?? "")
        }

        let json = try JSONDecoder().decode(GTXResponse.self, from: data)
        return try json.result(for: text)
    }
}

// MARK: - Response Model

struct GTXResponse: Decodable {
    let sentences: [Sentence]

    struct Sentence: Decodable {
        let trans: String?
        let translit: String?
        let srcTranslit: String?

        enum CodingKeys: String, CodingKey {
            case trans, translit
            case srcTranslit = "src_translit"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            trans = try container.decodeIfPresent(String.self, forKey: .trans)
            // Optional pronunciation metadata must never invalidate a usable translation.
            translit = try? container.decodeIfPresent(String.self, forKey: .translit)
            srcTranslit = try? container.decodeIfPresent(String.self, forKey: .srcTranslit)
        }
    }

    func result(for sourceText: String) throws -> TranslationResult {
        let translated = sentences.compactMap(\.trans).joined()
        guard !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranslationError.emptyResult
        }
        guard WordPronunciation.isSingleWord(sourceText) else {
            return TranslationResult(text: translated)
        }

        // Google's romanization is not necessarily IPA; keep its source/target labels explicit.
        var pronunciations = [WordPronunciation(
            kind: .source, text: sentences.compactMap(\.srcTranslit).joined(separator: " ")
        )].compactMap { $0 }
        if WordPronunciation.isSingleWord(translated),
           let target = WordPronunciation(kind: .target, text: sentences.compactMap(\.translit).joined(separator: " ")) {
            pronunciations.append(target)
        }
        return TranslationResult(text: translated, pronunciations: pronunciations)
    }
}

// MARK: - Settings View

private struct GoogleTranslateSettingsView: View {
    var body: some View {
        Form {
            Section("Status") {
                Label("Free, no API key needed.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.callout)
                Text("Uses unofficial Google Translate API, may be rate-limited.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
