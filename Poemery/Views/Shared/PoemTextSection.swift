import SwiftUI

struct PoemTextSection: View {
    let poem: Poem
    let highlightedLineID: PoemLine.ID?
    @Binding var selectedAnnotation: PoemAnnotation?

    @AppStorage(PoemTextSizePreference.storageKey) private var poemTextSize = PoemTextSizePreference.defaultValue
    @Environment(\.chineseScriptPreference) private var script

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(title: script.converted("正文"), showsChevron: false)
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
                    annotations: poem.annotations(for: line.id),
                    selectedAnnotation: $selectedAnnotation
                )
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
    let annotations: [PoemAnnotation]
    @Binding var selectedAnnotation: PoemAnnotation?

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            lineContent

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
                    .lineLimit(allowsTextWrapping ? nil : 1)
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
        Text(text)
            .font(PoemeryTheme.chineseFont(size: fontSize, relativeTo: .title3))
            .foregroundStyle(isHighlighted ? PoemeryTheme.accent : PoemeryTheme.primaryText)
            .multilineTextAlignment(.center)
            .lineSpacing(max(8, fontSize * 0.42))
            .textSelection(.enabled)
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
