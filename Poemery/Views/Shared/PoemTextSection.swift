import SwiftUI
import UIKit

struct PoemTextSection: View {
    let poem: Poem
    let highlightedLineID: PoemLine.ID?
    @Binding var selectedAnnotation: PoemAnnotation?
    @Binding var isSelectingText: Bool
    let onVisibleLine: (PoemLine.ID) -> Void

    @AppStorage(PoemTextSizePreference.storageKey) private var poemTextSize = PoemTextSizePreference.defaultValue
    @AppStorage("poemery.display.showPinyin") private var showPinyin = true
    @Environment(\.chineseScriptPreference) private var script

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(title: script.converted("正文"), showsChevron: false)

            ViewThatFits(in: .horizontal) {
                selectableText(using: .whole, allowsTextWrapping: false)
                    .fixedSize(horizontal: true, vertical: false)

                selectableText(using: .balanced, allowsTextWrapping: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if !poem.annotations.isEmpty {
                annotationChips
            }
        }
        .frame(maxWidth: 680, alignment: .leading)
        .onAppear {
            if let firstLineID = poem.lines.first?.id {
                onVisibleLine(firstLineID)
            }
        }
    }

    private func selectableText(
        using layout: PoemLineLayout,
        allowsTextWrapping: Bool
    ) -> some View {
        SelectablePoemText(
            paragraphs: poem.lines.map { line in
                SelectablePoemParagraph(
                    id: line.id,
                    displayedLines: layout.displayLines(for: line),
                    pronunciation: showPinyin ? poem.supplement?.pronunciation(for: line.id) : nil,
                    isHighlighted: line.id == highlightedLineID
                )
            },
            fontSize: CGFloat(PoemTextSizePreference.clamped(poemTextSize)),
            allowsTextWrapping: allowsTextWrapping,
            isSelectingText: $isSelectingText
        )
    }

    private var annotationChips: some View {
        VStack(spacing: 10) {
            ForEach(poem.lines) { line in
                let annotations = poem.annotations(for: line.id)
                if !annotations.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(annotations) { annotation in
                            Button {
                                selectedAnnotation = annotation
                            } label: {
                                Text(annotation.term)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PoemeryTheme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(PoemeryTheme.accentSoft, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct SelectablePoemParagraph: Hashable {
    let id: PoemLine.ID
    let displayedLines: [String]
    let pronunciation: String?
    let isHighlighted: Bool
}

private struct SelectablePoemText: UIViewRepresentable {
    let paragraphs: [SelectablePoemParagraph]
    let fontSize: CGFloat
    let allowsTextWrapping: Bool
    @Binding var isSelectingText: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isSelectingText: $isSelectingText)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = PoemSelectableTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.maximumNumberOfLines = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.tintColor = .systemRed
        textView.adjustsFontForContentSizeCategory = true
        textView.accessibilityTraits = .staticText
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.isSelectingText = $isSelectingText
        textView.textContainer.lineBreakMode = allowsTextWrapping ? .byWordWrapping : .byClipping
        textView.textContainer.widthTracksTextView = allowsTextWrapping

        let attributedText = makeAttributedText()
        if !textView.attributedText.isEqual(to: attributedText) {
            textView.attributedText = attributedText
        }
        textView.accessibilityLabel = paragraphs
            .flatMap(\.displayedLines)
            .joined(separator: "\n")
    }

    static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
        coordinator.isSelectingText.wrappedValue = false
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        if allowsTextWrapping {
            guard let width = proposal.width, width > 0 else {
                return nil
            }
            return uiView.sizeThatFits(
                CGSize(width: width, height: .greatestFiniteMagnitude)
            )
        }

        let bounds = makeAttributedText().boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return CGSize(width: ceil(bounds.width) + 2, height: ceil(bounds.height) + 2)
    }

    private func makeAttributedText() -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseFont = UIFont(name: PoemeryTheme.chineseFontName, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)
        let poemFont = UIFontMetrics(forTextStyle: .title3).scaledFont(for: baseFont)
        let pronunciationFont = UIFontMetrics(forTextStyle: .caption1).scaledFont(
            for: .systemFont(ofSize: 12, weight: .medium)
        )

        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            for (lineIndex, text) in paragraph.displayedLines.enumerated() {
                result.append(
                    NSAttributedString(
                        string: text,
                        attributes: poemAttributes(font: poemFont, isHighlighted: paragraph.isHighlighted)
                    )
                )
                if lineIndex < paragraph.displayedLines.count - 1 {
                    result.append(NSAttributedString(string: "\n"))
                }
            }

            if let pronunciation = paragraph.pronunciation, !pronunciation.isEmpty {
                result.append(
                    NSAttributedString(
                        string: "\n\(pronunciation)",
                        attributes: pronunciationAttributes(font: pronunciationFont)
                    )
                )
            }

            if paragraphIndex < paragraphs.count - 1 {
                result.append(NSAttributedString(string: "\n\n"))
            }
        }
        return result
    }

    private func poemAttributes(font: UIFont, isHighlighted: Bool) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = max(8, fontSize * 0.42)
        paragraphStyle.lineBreakMode = allowsTextWrapping ? .byWordWrapping : .byClipping

        return [
            .font: font,
            .foregroundColor: isHighlighted ? UIColor.systemRed : UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
    }

    private func pronunciationAttributes(font: UIFont) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 3
        paragraphStyle.lineBreakMode = .byWordWrapping

        return [
            .font: font,
            .foregroundColor: UIColor.tertiaryLabel,
            .paragraphStyle: paragraphStyle,
            .poemeryPronunciation: true
        ]
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var isSelectingText: Binding<Bool>

        init(isSelectingText: Binding<Bool>) {
            self.isSelectingText = isSelectingText
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            isSelectingText.wrappedValue = textView.selectedRange.length > 0
        }
    }
}

private extension NSAttributedString.Key {
    static let poemeryPronunciation = NSAttributedString.Key("PoemeryPronunciation")
}

private final class PoemSelectableTextView: UITextView {
    override func copy(_ sender: Any?) {
        guard selectedRange.length > 0,
              NSMaxRange(selectedRange) <= attributedText.length
        else {
            super.copy(sender)
            return
        }

        let selection = attributedText.attributedSubstring(from: selectedRange)
        var copiedText = ""
        selection.enumerateAttributes(
            in: NSRange(location: 0, length: selection.length)
        ) { attributes, range, _ in
            guard attributes[.poemeryPronunciation] == nil else {
                return
            }
            copiedText += selection.attributedSubstring(from: range).string
        }

        UIPasteboard.general.string = copiedText
    }
}

private enum PoemLineLayout {
    case whole
    case balanced

    private static let punctuation = Set("，。！？；、,.;!?")

    func displayLines(for line: PoemLine) -> [String] {
        switch self {
        case .whole:
            return [line.text]
        case .balanced:
            return splitAtReadablePunctuation(line.text)
        }
    }

    private func splitAtReadablePunctuation(_ text: String) -> [String] {
        var pieces: [String] = []
        var current = ""

        for character in text {
            current.append(character)
            if Self.punctuation.contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    pieces.append(trimmed)
                }
                current = ""
            }
        }

        let remainder = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remainder.isEmpty {
            pieces.append(remainder)
        }

        return pieces.isEmpty ? [text] : pieces
    }
}
