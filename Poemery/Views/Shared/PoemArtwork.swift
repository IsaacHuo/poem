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

    private var style: ArtworkStyle {
        poem.displayArtworkStyle
    }
}
