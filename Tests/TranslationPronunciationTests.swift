import Foundation
import Testing
@testable import MoePeek

@Suite struct TranslationPronunciationTests {
    @Test func googleSeparatesPronunciationFromTranslation() throws {
        let response = try JSONDecoder().decode(GTXResponse.self, from: Data(#"{"sentences":[{"trans":"你好","orig":"hello"},{"translit":"Nǐ hǎo","src_translit":"həˈlō"}]}"#.utf8))
        let result = try response.result(for: "hello")
        #expect(result.text == "你好")
        #expect(result.pronunciations == [
            WordPronunciation(kind: .source, text: "həˈlō")!,
            WordPronunciation(kind: .target, text: "Nǐ hǎo")!,
        ])
        #expect(try response.result(for: "hello world").pronunciations.isEmpty)
    }

    @Test func googleKeepsMultiSentenceTranslationWithoutMetadata() throws {
        let response = try JSONDecoder().decode(GTXResponse.self, from: Data(#"{"sentences":[{"trans":"First. "},{"trans":"Second.","translit":42,"src_translit":{}}]}"#.utf8))
        let result = try response.result(for: "hello")
        #expect(result.text == "First. Second.")
        #expect(result.pronunciations.isEmpty)
    }

    @Test func googleDoesNotAcceptPronunciationAsTranslation() throws {
        let response = try JSONDecoder().decode(GTXResponse.self, from: Data(#"{"sentences":[{"src_translit":"həˈlō"}]}"#.utf8))
        #expect(throws: (any Error).self) { try response.result(for: "hello") }
    }

    @Test func youdaoReturnsBritishAndAmericanPhonetics() throws {
        let response = try JSONDecoder().decode(YoudaoTranslateResponse.self, from: Data(#"{"code":0,"translateResult":[[{"tgt":"你好"}]],"dictResult":{"ec":{"word":{"ukphone":"həˈləʊ","usphone":"həˈloʊ","return-phrase":"hello"}}}}"#.utf8))
        let result = try response.result(for: "Hello")
        #expect(result.text == "你好")
        #expect(result.pronunciations == [
            WordPronunciation(kind: .british, text: "həˈləʊ")!,
            WordPronunciation(kind: .american, text: "həˈloʊ")!,
        ])
        #expect(try response.result(for: "world").pronunciations.isEmpty)
        #expect(try response.result(for: "hello world").pronunciations.isEmpty)
    }

    @Test(arguments: ["null", "{}", #"{"ec":{"word":[]}}"#, #"{"ec":{"word":{"ukphone":42}}}"#])
    func youdaoOptionalDictionaryCannotBreakTranslation(_ dictionary: String) throws {
        let data = Data("{\"code\":0,\"translateResult\":[[{\"tgt\":\"a\"},{\"tgt\":\"b\"}],[{\"tgt\":\"c\"}]],\"dictResult\":\(dictionary)}".utf8)
        let response = try JSONDecoder().decode(YoudaoTranslateResponse.self, from: data)
        let result = try response.result(for: "hello")
        #expect(result.text == "ab\nc")
        #expect(result.pronunciations.isEmpty)
    }

    @Test func youdaoAllowsMissingAccentWithoutAnEmptyLabel() throws {
        let response = try JSONDecoder().decode(YoudaoTranslateResponse.self, from: Data(#"{"code":0,"translateResult":[[{"tgt":"你好"}]],"dictResult":{"ec":{"word":{"ukphone":"  ","usphone":"həˈloʊ"}}}}"#.utf8))
        #expect(try response.result(for: "hello").pronunciations == [WordPronunciation(kind: .american, text: "həˈloʊ")!])
    }

    @Test(arguments: ["hello", " hello\n", "can't", "well-known", "café", "你好"])
    func acceptsWords(_ text: String) {
        #expect(WordPronunciation.isSingleWord(text))
    }

    @Test(arguments: ["", " ", "123", "hello world", "one\ntwo", "https://example.com", "hello!", "**hello**", String(repeating: "a", count: 65)])
    func excludesSentencesAndNonWords(_ text: String) {
        #expect(!WordPronunciation.isSingleWord(text))
    }
}
