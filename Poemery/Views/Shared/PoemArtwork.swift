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

            VStack(alignment: .leading) {
                Spacer()
                Text(poem.title)
                    .font(.system(size: max(13, size * 0.15), weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(size < 70 ? 1 : 3)
                    .minimumScaleFactor(0.62)
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
