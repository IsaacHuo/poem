import SwiftUI

struct RadioRow: View {
    let collection: PoemCollection
    let poems: [Poem]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [collection.accent.primary, collection.accent.secondary, collection.accent.tertiary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PaperTexture().opacity(0.18))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(18)
                }

            LinearGradient(
                colors: [.clear, .black.opacity(0.58)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack(alignment: .bottom, spacing: 14) {
                Text(collection.accent.glyph)
                    .font(PoemeryTheme.chineseFont(size: 52, relativeTo: .largeTitle))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(width: 66, height: 66)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("连续诵读")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text(collection.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text(collection.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(2)
                    Text("\(poems.count) 首诗词")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(18)
        }
        .frame(height: 170)
        .shadow(color: collection.accent.primary.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}
