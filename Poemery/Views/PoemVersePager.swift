#if false
import SwiftUI

struct PoemVersePager: View {
    let poem: Poem

    @Binding var selectedLineID: PoemLine.ID
    @Binding var selectedAnnotation: PoemAnnotation?
    @Binding var scrollPosition: PoemLine.ID?

    let highlightedLineID: PoemLine.ID?
    let isMemorizing: Bool

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 34) {
                ForEach(poem.lines) { line in
                    PoemLinePanel(
                        line: line,
                        isSelected: line.id == selectedLineID,
                        isHighlighted: line.id == highlightedLineID,
                        isMemorizing: isMemorizing,
                        selectedAnnotation: $selectedAnnotation
                    )
                    .id(line.id)
                    .containerRelativeFrame(.vertical)
                    .scrollTransition(axis: .vertical) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.28)
                            .scaleEffect(phase.isIdentity ? 1 : 0.92)
                            .blur(radius: phase.isIdentity ? 0 : 2)
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $scrollPosition)
        .safeAreaPadding(.horizontal, 26)
        .onAppear {
            if scrollPosition == nil {
                scrollPosition = selectedLineID
            }
        }
    }
}
#endif

private struct PoemLinePanel: View {
    let line: PoemLine
    let isSelected: Bool
    let isHighlighted: Bool
    let isMemorizing: Bool

    @Binding var selectedAnnotation: PoemAnnotation?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var chars: [String] {
        line.text.map(String.init)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            VStack(spacing: 18) {
                Text(lineCaption)
                    .font(PoemeryTheme.chineseFont(size: 13, relativeTo: .caption))
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(PoemeryTheme.ink.opacity(isSelected ? 0.50 : 0.24))

                lineText
                    .accessibilityLabel(line.text)
                    .padding(.horizontal, 10)

                annotationChips
                    .opacity(isSelected ? 1 : 0)
                    .offset(y: isSelected ? 0 : 8)
            }
            .padding(.vertical, 18)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var lineCaption: String {
        switch line.mood {
        case .fadedStudy:
            "暮色入斋"
        case .eveningWind:
            "晚风独啸"
        case .pearlInk:
            "笔底微光"
        case .wildVine:
            "野藤收束"
        }
    }

    private var lineText: some View {
        HStack(spacing: dynamicTypeSize.isAccessibilitySize ? 8 : 10) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                Text(char)
                    .font(PoemeryTheme.chineseFont(size: dynamicTypeSize.isAccessibilitySize ? 36 : 43, relativeTo: .largeTitle))
                    .minimumScaleFactor(0.66)
                    .foregroundStyle(characterStyle(for: index))
                    .opacity(characterOpacity(for: index))
                    .shadow(color: isHighlighted ? PoemeryTheme.pearl.opacity(0.36) : .clear, radius: 14, x: 0, y: 0)
                    .offset(y: isMemorizing && index.isMultiple(of: 3) ? -2 : 0)
                    .animation(PoemeryTheme.motion.delay(Double(index) * 0.035), value: isMemorizing)
                    .animation(PoemeryTheme.quickMotion, value: isHighlighted)
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder
    private var annotationChips: some View {
        if line.annotations.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: 10) {
                ForEach(line.annotations) { annotation in
                    Button {
                        withAnimation(PoemeryTheme.motion) {
                            selectedAnnotation = annotation
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 12, weight: .semibold))
                            Text(annotation.term)
                                .font(PoemeryTheme.chineseFont(size: 13, relativeTo: .caption))
                        }
                        .foregroundStyle(PoemeryTheme.ink.opacity(0.82))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(PoemeryTheme.paper.opacity(0.08), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(PoemeryTheme.paper.opacity(0.12), lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("注解 \(annotation.term)")
                }
            }
        }
    }

    private func characterStyle(for index: Int) -> some ShapeStyle {
        if isHighlighted {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [PoemeryTheme.pearl, PoemeryTheme.ink],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }

        if isSelected {
            return AnyShapeStyle(PoemeryTheme.ink)
        }

        return AnyShapeStyle(PoemeryTheme.ink.opacity(0.44))
    }

    private func characterOpacity(for index: Int) -> Double {
        guard isMemorizing else { return 1 }
        if index.isMultiple(of: 3) || index == chars.count - 2 {
            return 0.16
        }
        return 0.72
    }
}
