#if false
import SwiftUI

struct PoemCardSheet: View {
    let poem: Poem
    let focusedLineIndex: Int
    let namespace: Namespace.ID
    let onClose: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                sheetContent
                    .glassEffect(.regular.tint(PoemeryTheme.paper.opacity(0.12)).interactive(), in: .rect(cornerRadius: 34))
                    .glassEffectID("control-island", in: namespace)
            }
        } else {
            AdaptiveGlassSurface(cornerRadius: 34, isInteractive: true) {
                sheetContent
            }
        }
    }

    private var sheetContent: some View {
        VStack(spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("诗笺")
                        .font(PoemeryTheme.chineseFont(size: 18, relativeTo: .headline))
                        .foregroundStyle(PoemeryTheme.ink)
                    Text("poemery")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(PoemeryTheme.ink.opacity(0.50))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PoemeryTheme.ink.opacity(0.78))
                        .frame(width: 34, height: 34)
                        .background(PoemeryTheme.paper.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭诗笺")
            }

            cardPreview
        }
        .padding(20)
    }

    private var cardPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            PoemeryTheme.paper.opacity(0.96),
                            Color(red: 0.82, green: 0.78, blue: 0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PaperFibers().opacity(0.22))

            HStack(alignment: .top, spacing: 16) {
                SealMark()
                    .padding(.top, 16)

                Spacer(minLength: 8)

                ForEach(Array(poem.lines.enumerated().reversed()), id: \.element.id) { index, line in
                    VerticalLineText(
                        text: line.text,
                        isFocused: index == focusedLineIndex
                    )
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .frame(height: 286)
        .shadow(color: .black.opacity(0.26), radius: 22, x: 0, y: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("诗笺预览，\(poem.fullText)")
    }
}
#endif

private struct VerticalLineText: View {
    let text: String
    let isFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(text.enumerated()), id: \.offset) { _, char in
                Text(String(char))
                    .font(PoemeryTheme.chineseFont(size: isFocused ? 21 : 20, relativeTo: .body))
                    .foregroundStyle(PoemeryTheme.deepInk.opacity(isFocused ? 0.88 : 0.58))
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(width: 28)
    }
}

private struct SealMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(PoemeryTheme.cinnabar.opacity(0.88), lineWidth: 1.4)
                .frame(width: 42, height: 42)

            VStack(spacing: 0) {
                Text("诗")
                Text("境")
            }
            .font(PoemeryTheme.chineseFont(size: 13, relativeTo: .caption))
            .foregroundStyle(PoemeryTheme.cinnabar.opacity(0.90))
        }
    }
}

private struct PaperFibers: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<120 {
                let seed = CGFloat(index)
                let x = (seed * 37).truncatingRemainder(dividingBy: size.width)
                let y = (seed * 71).truncatingRemainder(dividingBy: size.height)
                var path = Path()
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x + 12 + seed.truncatingRemainder(dividingBy: 18), y: y + 1))
                context.stroke(path, with: .color(PoemeryTheme.deepInk.opacity(0.18)), lineWidth: 0.4)
            }
        }
    }
}
