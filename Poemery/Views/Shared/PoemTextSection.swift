import SwiftUI

struct PoemTextSection: View {
    let poem: Poem
    let highlightedLineID: PoemLine.ID?
    @Binding var selectedAnnotation: PoemAnnotation?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "正文")

            VStack(alignment: .leading, spacing: 14) {
                ForEach(poem.lines) { line in
                    let annotations = poem.annotations(for: line.id)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(line.text)
                            .font(PoemeryTheme.chineseFont(size: 24, relativeTo: .title3))
                            .foregroundStyle(line.id == highlightedLineID ? PoemeryTheme.accent : PoemeryTheme.primaryText)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)

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
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        line.id == highlightedLineID ? PoemeryTheme.accentSoft : PoemeryTheme.surface,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
            }
        }
    }
}
