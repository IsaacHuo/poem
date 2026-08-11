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
            HStack {
                SectionTitle(title: script.converted("正文"), showsChevron: false)

                Spacer()

                Button {
                    UIPasteboard.general.string = poem.lines.map(\.text).joined(separator: "\n")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(script.converted("复制全文"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ViewThatFits(in: .horizontal) {
                poemLines(using: .whole, allowsTextWrapping: false)
                    .fixedSize(horizontal: true, vertical: false)

                poemLines(using: .balanced, allowsTextWrapping: true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 680, alignment: .leading)
    }

    private func poemLines(using layout: PoemLineLayout, allowsTextWrapping: Bool) -> some View {
        VStack(alignment: .center, spacing: 12) {
            ForEach(poem.lines) { line in
                PoemLineTextBlock(
                    line: line,
                    displayedLines: layout.displayLines(for: line),
                    allowsTextWrapping: allowsTextWrapping,
                    fontSize: CGFloat(PoemTextSizePreference.clamped(poemTextSize)),
                    isHighlighted: line.id == highlightedLineID,
                    pronunciation: showPinyin ? poem.supplement?.pronunciation(for: line.id) : nil,
                    annotations: poem.annotations(for: line.id),
                    selectedAnnotation: $selectedAnnotation,
                    isSelectingText: $isSelectingText
                )
                .id(line.id)
                .onAppear { onVisibleLine(line.id) }
            }
        }
    }
}

private struct PoemLineTextBlock: View {
    let line: PoemLine
    let displayedLines: [String]
    let allowsTextWrapping: Bool
    let fontSize: CGFloat
    let isHighlighted: Bool
    let pronunciation: String?
    let annotations: [PoemAnnotation]
    @Binding var selectedAnnotation: PoemAnnotation?
    @Binding var isSelectingText: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            lineContent

            if let pronunciation, !pronunciation.isEmpty {
                Text(pronunciation)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .accessibilityLabel("拼音：\(pronunciation)")
            }

            if !annotations.isEmpty {
                annotationChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var lineContent: some View {
        VStack(alignment: .center, spacing: 10) {
            ForEach(Array(displayedLines.enumerated()), id: \.offset) { _, text in
                poemText(text)
                    .fixedSize(horizontal: !allowsTextWrapping, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var annotationChips: some View {
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
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func poemText(_ text: String) -> some View {
        SelectablePoemLineText(
            text: text,
            fontSize: fontSize,
            allowsTextWrapping: allowsTextWrapping,
            isHighlighted: isHighlighted,
            isSelectingText: $isSelectingText
        )
    }
}

private struct SelectablePoemLineText: UIViewRepresentable {
    let text: String
    let fontSize: CGFloat
    let allowsTextWrapping: Bool
    let isHighlighted: Bool
    @Binding var isSelectingText: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isSelectingText: $isSelectingText)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.maximumNumberOfLines = allowsTextWrapping ? 0 : 1
        textView.textContainer.lineBreakMode = allowsTextWrapping ? .byWordWrapping : .byClipping
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.tintColor = .systemRed
        textView.accessibilityTraits = .staticText
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.isSelectingText = $isSelectingText
        textView.textContainer.maximumNumberOfLines = allowsTextWrapping ? 0 : 1
        textView.textContainer.lineBreakMode = allowsTextWrapping ? .byWordWrapping : .byClipping
        let attributedText = makeAttributedText()
        if !textView.attributedText.isEqual(to: attributedText) {
            textView.attributedText = attributedText
        }
        textView.accessibilityLabel = text
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
        let baseFont = UIFont(name: PoemeryTheme.chineseFontName, size: fontSize)
            ?? UIFont.systemFont(ofSize: fontSize)
        let font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: baseFont)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = max(8, fontSize * 0.42)
        paragraphStyle.lineBreakMode = allowsTextWrapping ? .byWordWrapping : .byClipping

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: isHighlighted ? UIColor.systemRed : UIColor.label,
                .paragraphStyle: paragraphStyle
            ]
        )
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
