import SwiftUI

struct PoemTextSection: View {
    let poem: Poem
    let highlightedLineID: PoemLine.ID?
    @Binding var selectedAnnotation: PoemAnnotation?

    private var displayLines: [DisplayLine] {
        poem.lines.flatMap { line in
            formattedTexts(for: line).enumerated().map { index, text in
                DisplayLine(id: "\(line.id)-\(index)", sourceLine: line, text: text)
            }
        }
    }

    private var isRegulatedPoem: Bool {
        poem.form.hasPrefix("五言") || poem.form.hasPrefix("七言")
    }

    private var isCompactPoem: Bool {
        displayLines.count <= 16 && longestLineLength <= 16
    }

    private var longestLineLength: Int {
        displayLines.map { $0.text.count }.max() ?? 0
    }

    private var textAlignment: TextAlignment {
        isCompactPoem ? .center : .leading
    }

    private var horizontalAlignment: HorizontalAlignment {
        isCompactPoem ? .center : .leading
    }

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: 18) {
            SectionTitle(title: "正文", showsChevron: false)

            VStack(alignment: horizontalAlignment, spacing: 12) {
                ForEach(displayLines) { displayLine in
                    let annotations = poem.annotations(for: displayLine.sourceLine.id)
                    VStack(alignment: horizontalAlignment, spacing: 8) {
                        Text(displayLine.text)
                            .font(PoemeryTheme.chineseFont(size: 25, relativeTo: .title3))
                            .foregroundStyle(displayLine.sourceLine.id == highlightedLineID ? PoemeryTheme.accent : PoemeryTheme.primaryText)
                            .multilineTextAlignment(textAlignment)
                            .lineSpacing(11)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: isCompactPoem ? .center : .leading)

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
                            .frame(maxWidth: .infinity, alignment: isCompactPoem ? .center : .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: isCompactPoem ? .center : .leading)
                }
            }
            .padding(.horizontal, isCompactPoem ? 18 : 0)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 680, alignment: isCompactPoem ? .center : .leading)
    }

    private func formattedTexts(for line: PoemLine) -> [String] {
        guard isRegulatedPoem else {
            return [line.text]
        }

        let pieces = line.text
            .replacingOccurrences(of: "，", with: "，\n")
            .replacingOccurrences(of: "、", with: "、\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        return pieces.isEmpty ? [line.text] : pieces
    }
}

private struct DisplayLine: Identifiable {
    let id: String
    let sourceLine: PoemLine
    let text: String
}
