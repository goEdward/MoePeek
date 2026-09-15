import AppKit
import Testing
@testable import MoePeek

@Suite @MainActor struct OCRCopyTests {
    @Test func copiesOriginalTextAndLineBreaks() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("previous", forType: .string)
        try ScreenCaptureOCR.copyRecognizedText("Hello\n第二行", to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "Hello\n第二行")
    }

    @Test func emptyRecognitionPreservesClipboard() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("previous", forType: .string)
        #expect(throws: (any Error).self) {
            try ScreenCaptureOCR.copyRecognizedText(" \n", to: pasteboard)
        }
        #expect(pasteboard.string(forType: .string) == "previous")
    }

    @Test func cancelledCopyPreservesClipboard() async {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("previous", forType: .string)
        let task = Task { @MainActor in
            #expect(throws: CancellationError.self) {
                try ScreenCaptureOCR.copyRecognizedText("replacement", to: pasteboard)
            }
        }
        task.cancel()
        await task.value
        #expect(pasteboard.string(forType: .string) == "previous")
    }
}
