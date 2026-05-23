import SwiftUI

struct PoemArtwork: View {
    let poem: Poem
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [poem.artworkStyle.primary, poem.artworkStyle.secondary, poem.artworkStyle.tertiary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PaperTexture().opacity(0.20))

            VStack {
                HStack {
                    Text(poem.dynasty)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Text(poem.form)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.76))
                }
                Spacer()
            }
            .padding(max(8, size * 0.08))

            Text(poem.artworkStyle.glyph)
                .font(PoemeryTheme.chineseFont(size: size * 0.42, relativeTo: .largeTitle))
                .foregroundStyle(.white.opacity(0.86))

            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Text(poem.title)
                    .font(.system(size: max(14, size * 0.13), weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.62)
                Text(poem.author)
                    .font(.system(size: max(11, size * 0.08), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(max(8, size * 0.08))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(poem.title)，\(poem.author)")
    }
}
