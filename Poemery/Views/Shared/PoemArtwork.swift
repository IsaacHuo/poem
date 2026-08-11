import SwiftUI

struct PoemArtwork: View {
    let title: String
    let author: String
    let displayArtworkStyle: ArtworkStyle
    let size: CGFloat
    let cornerRadius: CGFloat

    init(poem: Poem, size: CGFloat, cornerRadius: CGFloat) {
        self.title = poem.title
        self.author = poem.author
        self.displayArtworkStyle = poem.displayArtworkStyle
        self.size = size
        self.cornerRadius = cornerRadius
    }

    init(item: PoemListItem, size: CGFloat, cornerRadius: CGFloat) {
        self.title = item.title
        self.author = item.author
        self.displayArtworkStyle = item.displayArtworkStyle
        self.size = size
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.primary, style.secondary, style.tertiary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.22), .clear, .black.opacity(0.24)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                }
                .overlay {
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.12), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(-35))
                    .offset(x: size * 0.18)
                }
                .overlay(PaperTexture().opacity(0.20))

            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: size * 0.72, height: size * 0.72)
                .blur(radius: size * 0.08)
                .offset(x: size * 0.18, y: -size * 0.20)

            Text(style.glyph)
                .font(PoemeryTheme.chineseFont(size: max(24, size * 0.42), relativeTo: .largeTitle).weight(.bold))
                .foregroundStyle(.white.opacity(0.94))
                .minimumScaleFactor(0.85)
                .shadow(color: .black.opacity(0.18), radius: size * 0.04, x: 0, y: size * 0.025)
                .padding(size * 0.14)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(author)")
    }

    private var style: ArtworkStyle {
        displayArtworkStyle
    }
}
