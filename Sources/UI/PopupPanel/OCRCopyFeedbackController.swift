import AppKit
import SwiftUI

/// Brief, non-activating feedback for OCR copies that do not open the translation panel.
@MainActor
final class OCRCopyFeedbackController {
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func showCopied() {
        dismiss()
        let cursor = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cursor) }) ?? NSScreen.main else { return }

        let content = NSHostingView(rootView:
            Label("Recognized text copied", systemImage: "checkmark.circle.fill")
                .font(.body)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        )
        let size = content.fittingSize
        let frame = NSRect(
            x: screen.visibleFrame.midX - size.width / 2,
            y: screen.visibleFrame.minY + 64,
            width: size.width,
            height: size.height
        )
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = content
        self.panel = panel
        panel.orderFront(nil)

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1400))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        panel?.contentView = nil
        panel?.close()
        panel = nil
    }
}
