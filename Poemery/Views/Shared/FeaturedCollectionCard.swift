import SwiftUI

struct FeaturedCollectionCard: View {
    let collection: PoemCollection
    let size: CGSize

    init(
        collection: PoemCollection,
        size: CGSize = CGSize(width: 320, height: 346)
    ) {
        self.collection = collection
        self.size = size
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            coverBase
            coverLayers
            bottomGradient
            titleBlock
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: collection.accent.primary.opacity(0.22), radius: isCompact ? 20 : 24, x: 0, y: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title)，\(collection.subtitle)，\(collection.poemCount) 首")
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
                .frame(width: size.width * 0.41, height: size.height * 0.45)
                .rotationEffect(.degrees(-9))
                .offset(x: -size.width * 0.21, y: -size.height * 0.19)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
                .frame(width: size.width * 0.56, height: size.height * 0.62)
                .rotationEffect(.degrees(7))
                .offset(x: size.width * 0.21, y: -size.height * 0.04)

            Text(collection.accent.glyph)
                .font(PoemeryTheme.chineseFont(size: size.width * 0.42, relativeTo: .largeTitle))
                .foregroundStyle(.white.opacity(0.22))
                .offset(x: size.width * 0.13, y: -size.height * 0.13)

            VStack(spacing: 4) {
                Text("诗")
                Text("境")
            }
            .font(PoemeryTheme.chineseFont(size: size.width * 0.06, relativeTo: .title3))
            .foregroundStyle(.white.opacity(0.82))
            .frame(width: size.width * 0.17, height: size.width * 0.17)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 1)
            }
            .offset(x: size.width * 0.35, y: -size.height * 0.37)
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
        VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
            Text(label)
                .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.82))

            Text(collection.title)
                .font(.system(size: titleFontSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(collection.subtitle)
                .font(.system(size: isCompact ? 13 : 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(2)

            Text("\(collection.poemCount) 首作品")
                .font(.system(size: isCompact ? 11 : 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.76))
                .padding(.top, 4)
        }
        .padding(max(isCompact ? 16 : 18, size.width * 0.06))
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

    private var isCompact: Bool {
        size.width < 260
    }

    private var titleFontSize: CGFloat {
        isCompact ? 22 : min(30, max(26, size.width * 0.09))
    }
}
