import AppKit
import Defaults
import SwiftUI
import Testing
@testable import MoePeek

@Suite(.serialized) @MainActor struct TranslationCoordinatorPronunciationTests {
    @Test func pronunciationDoesNotLeakIntoCopyOrNextRequest() async throws {
        let previousEnabled = Defaults[.enabledProviders]
        Defaults[.enabledProviders] = ["test-pronunciation"]
        defer { Defaults[.enabledProviders] = previousEnabled }
        let provider = StubPronunciationProvider()
        let coordinator = TranslationCoordinator(
            permissionManager: PermissionManager(),
            registry: TranslationProviderRegistry(providers: [provider])
        )
        defer { coordinator.dismiss() }

        coordinator.translate("hello")
        try await waitForCompletion(coordinator)
        #expect(coordinator.providerStates[provider.id] == .completed(text: "translation"))
        #expect(coordinator.providerPronunciations[provider.id]?.count == 1)

        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        #expect(coordinator.copyResult(forProviderID: provider.id, to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "translation")

        coordinator.retryProvider(provider)
        #expect(coordinator.providerPronunciations[provider.id] == nil)
        try await waitForCompletion(coordinator)
        #expect(coordinator.providerPronunciations[provider.id]?.count == 1)

        coordinator.translate("a sentence")
        #expect(coordinator.providerPronunciations.isEmpty)
        try await waitForCompletion(coordinator)
        #expect(coordinator.providerPronunciations[provider.id]?.isEmpty == true)
        coordinator.prepareInputMode()
        #expect(coordinator.providerPronunciations.isEmpty)
    }

    @Test func plainStreamAdapterStillReturnsOnlyTranslation() async throws {
        var text = ""
        for try await chunk in StubPronunciationProvider().translateStream("hello", from: "en", to: "zh-Hans") {
            text += chunk
        }
        #expect(text == "translation")
    }

    private func waitForCompletion(_ coordinator: TranslationCoordinator) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !coordinator.allFinished, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(coordinator.allFinished)
    }
}

private struct StubPronunciationProvider: PronunciationTranslationProvider {
    let id = "test-pronunciation"
    let displayName = "Test"
    let iconSystemName = "text.book.closed"
    let supportsStreaming = false
    let isAvailable = true
    @MainActor var isConfigured: Bool { true }

    func translateResult(_ text: String, from: String?, to: String) async throws -> TranslationResult {
        TranslationResult(text: "translation", pronunciations: text == "hello" ? [WordPronunciation(kind: .source, text: "test pronunciation")!] : [])
    }

    @MainActor func makeSettingsView() -> AnyView { AnyView(EmptyView()) }
}
