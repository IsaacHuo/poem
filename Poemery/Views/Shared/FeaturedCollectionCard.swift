import SwiftUI

struct FeaturedCollectionCard: View {
    let collection: PoemCollection
    let poems: [Poem]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [collection.accent.primary, collection.accent.secondary, collection.accent.tertiary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.trailing, 18)
                        .padding(.top, 18)
                }
                .overlay(alignment: .center) {
                    Text(collection.accent.glyph)
                        .font(PoemeryTheme.chineseFont(size: 132, relativeTo: .largeTitle))
                        .foregroundStyle(.white.opacity(0.24))
                }
                .overlay(PaperTexture().opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            LinearGradient(
                colors: [.clear, .black.opacity(0.56)],
                startPoint: .center,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.82))
                Text(collection.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                Text(collection.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(2)

                Text("\(poems.count) 首诗词")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.76))
                    .padding(.top, 4)
            }
            .padding(20)
        }
        .frame(width: 320, height: 420)
        .shadow(color: collection.accent.primary.opacity(0.22), radius: 24, x: 0, y: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title)，\(collection.subtitle)，\(poems.count) 首")
    }

    private var label: String {
        switch collection.kind {
        case .featured: "专属推荐"
        case .mood: "主题诗单"
        case .author: "诗人精选"
        case .era: "朝代精选"
        case .radio: "阅读流"
        case .chart: "排行榜"
        }
    }
}
