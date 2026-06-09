import SwiftUI

struct PoemTextSection: View {
    let poem: Poem
    let highlightedLineID: PoemLine.ID?
    @Binding var selectedAnnotation: PoemAnnotation?
    @Binding var selectedLineID: PoemLine.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionTitle(title: "正文", showsChevron: false)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .center, spacing: 12) {
                ForEach(poem.lines) { line in
                    PoemLineTextBlock(
                        line: line,
                        isHighlighted: line.id == highlightedLineID || line.id == selectedLineID,
                        isSelected: line.id == selectedLineID,
                        annotations: poem.annotations(for: line.id),
                        selectedAnnotation: $selectedAnnotation,
                        onSelectLine: selectLine
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 680, alignment: .leading)
    }

    private func selectLine(_ line: PoemLine) {
        withAnimation(PoemeryTheme.quickMotion) {
            selectedLineID = selectedLineID == line.id ? nil : line.id
        }
    }
}

private struct PoemLineTextBlock: View {
    let line: PoemLine
    let isHighlighted: Bool
    let isSelected: Bool
    let annotations: [PoemAnnotation]
    @Binding var selectedAnnotation: PoemAnnotation?
    let onSelectLine: (PoemLine) -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Button {
                onSelectLine(line)
            } label: {
                lineContent
            }
            .buttonStyle(.plain)
            .accessibilityHint("选择这句生成分享图片")
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])

            if !annotations.isEmpty {
                annotationChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            if isSelected {
                Capsule()
                    .fill(PoemeryTheme.accentSoft)
            }
        }
    }

    private var lineContent: some View {
        ViewThatFits(in: .horizontal) {
            poemText(line.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            wrappedLine
        }
    }

    private var wrappedLine: some View {
        VStack(alignment: .center, spacing: 10) {
            ForEach(Array(splitAtReadablePunctuation(line.text).enumerated()), id: \.offset) { _, text in
                poemText(text)
                    .fixedSize(horizontal: false, vertical: true)
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
            .font(PoemeryTheme.chineseFont(size: 25, relativeTo: .title3))
            .foregroundStyle(isHighlighted ? PoemeryTheme.accent : PoemeryTheme.primaryText)
            .multilineTextAlignment(.center)
            .lineSpacing(11)
    }

    private func splitAtReadablePunctuation(_ text: String) -> [String] {
        let punctuation = Set("，。！？；、,.;!?")
        var pieces: [String] = []
        var current = ""

        for character in text {
            current.append(character)
            if punctuation.contains(character) {
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
