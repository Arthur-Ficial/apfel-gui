// ============================================================================
// MultilineInputField.swift — Chat input that grows to multiple lines
// ============================================================================
// Return alone        → submit (calls onSubmit)
// Shift+Return        → newline
// Option+Return       → newline
// The field grows from 1 line up to `maxLines`, then scrolls.
// ============================================================================

import SwiftUI
import AppKit

struct MultilineInputField: View {
    @Binding var text: String
    let placeholder: String
    let isEnabled: Bool
    let maxLines: Int
    let onSubmit: () -> Void

    @State private var measuredHeight: CGFloat = 30

    init(
        text: Binding<String>,
        placeholder: String,
        isEnabled: Bool = true,
        maxLines: Int = 6,
        onSubmit: @escaping () -> Void
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isEnabled = isEnabled
        self.maxLines = maxLines
        self.onSubmit = onSubmit
    }

    var body: some View {
        MultilineInputRepresentable(
            text: $text,
            placeholder: placeholder,
            isEnabled: isEnabled,
            maxLines: maxLines,
            measuredHeight: $measuredHeight,
            onSubmit: onSubmit
        )
        .frame(height: measuredHeight)
    }
}

struct MultilineInputRepresentable: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isEnabled: Bool
    let maxLines: Int
    @Binding var measuredHeight: CGFloat
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true

        let textView = ChatInputTextView()
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 4, height: 6)
        textView.delegate = context.coordinator
        textView.coordinator = context.coordinator
        textView.placeholderString = placeholder
        textView.string = text
        textView.isEditable = isEnabled
        textView.isSelectable = true
        textView.translatesAutoresizingMaskIntoConstraints = true

        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: 0, height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        scroll.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scroll
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ChatInputTextView else { return }
        context.coordinator.parent = self
        if textView.string != text {
            let selected = textView.selectedRange()
            textView.string = text
            let length = (text as NSString).length
            let newRange = NSRange(
                location: min(selected.location, length),
                length: 0
            )
            textView.setSelectedRange(newRange)
        }
        textView.placeholderString = placeholder
        textView.isEditable = isEnabled
        context.coordinator.recomputeHeight()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineInputRepresentable
        weak var textView: ChatInputTextView?
        weak var scrollView: NSScrollView?

        init(_ parent: MultilineInputRepresentable) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
            recomputeHeight()
        }

        func submitNow() {
            parent.onSubmit()
        }

        func recomputeHeight() {
            guard let tv = textView,
                  let layoutManager = tv.layoutManager,
                  let container = tv.textContainer else { return }
            layoutManager.ensureLayout(for: container)
            let used = layoutManager.usedRect(for: container)
            let lh = tv.lineHeight
            let maxLines = CGFloat(parent.maxLines)
            let inset = tv.textContainerInset.height * 2
            let minH = lh + inset
            let maxH = lh * maxLines + inset
            let measured = ceil(used.height) + inset
            // Add 4pt for scroll view bezel padding to avoid clipping.
            let target = min(max(measured, minH), maxH) + 4
            if abs(parent.measuredHeight - target) > 0.5 {
                let newHeight = target
                DispatchQueue.main.async { [weak self] in
                    self?.parent.measuredHeight = newHeight
                }
            }
        }
    }
}

// MARK: - NSTextView subclass with placeholder + Return handling

final class ChatInputTextView: NSTextView {
    weak var coordinator: MultilineInputRepresentable.Coordinator?
    var placeholderString: String = "" {
        didSet { needsDisplay = true }
    }

    var lineHeight: CGFloat {
        let f = font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
        return ceil(f.ascender - f.descender + f.leading)
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        // 0x24 = Return, 0x4C = numpad Enter.
        if event.keyCode == 0x24 || event.keyCode == 0x4C {
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Shift+Return or Option+Return → newline.
            if mods.contains(.shift) || mods.contains(.option) {
                super.keyDown(with: event)
                return
            }
            // Plain Return / Cmd+Return → submit.
            coordinator?.submitNow()
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholderString.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.placeholderTextColor,
        ]
        let origin = NSPoint(
            x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0),
            y: textContainerInset.height
        )
        (placeholderString as NSString).draw(at: origin, withAttributes: attrs)
    }
}
