import SwiftUI

struct FeaturedCollectionCard: View {
    let collection: PoemCollection
    let poems: [Poem]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            coverBase
            coverLayers
            bottomGradient
            titleBlock
        }
        .frame(width: 320, height: 420)
        .shadow(color: collection.accent.primary.opacity(0.22), radius: 24, x: 0, y: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title)，\(collection.subtitle)，\(poems.count) 首")
    }

    private var coverBase: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        collection.accent.primary,
                        collection.accent.secondary,
                        collection.accent.tertiary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(PaperTexture().opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var coverLayers: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.12))
                .frame(width: 132, height: 188)
                .rotationEffect(.degrees(-9))
                .offset(x: -68, y: -78)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
                .frame(width: 178, height: 260)
                .rotationEffect(.degrees(7))
                .offset(x: 68, y: -16)

            Text(collection.accent.glyph)
                .font(PoemeryTheme.chineseFont(size: 150, relativeTo: .largeTitle))
                .foregroundStyle(.white.opacity(0.22))
                .offset(x: 42, y: -54)

            VStack(spacing: 4) {
                Text("诗")
                Text("境")
            }
            .font(PoemeryTheme.chineseFont(size: 20, relativeTo: .title3))
            .foregroundStyle(.white.opacity(0.82))
            .frame(width: 54, height: 54)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 1)
            }
            .offset(x: 112, y: -154)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var bottomGradient: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.58)],
            startPoint: .center,
            endPoint: .bottom
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Text("\(poems.count) 首作品")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.76))
                .padding(.top, 4)
        }
        .padding(20)
    }

    private var label: String {
        switch collection.kind {
        case .featured: "精选诗单"
        case .mood: "主题诗单"
        case .author: "诗人精选"
        case .era: "朝代精选"
        case .chart: "作品合集"
        }
    }
}
