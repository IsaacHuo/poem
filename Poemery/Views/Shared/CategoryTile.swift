import SwiftUI

struct CategoryTile: View {
    let category: PoemCategory

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            category.artworkStyle.primary,
                            category.artworkStyle.secondary,
                            category.artworkStyle.tertiary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .center) {
                    Text(category.artworkStyle.glyph)
                        .font(PoemeryTheme.chineseFont(size: 56, relativeTo: .largeTitle))
                        .foregroundStyle(.white.opacity(0.22))
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: category.symbol)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.black.opacity(0.20))
                        .padding(14)
                }
                .overlay(PaperTexture().opacity(0.16))

            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(category.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(2)
            }
            .padding(16)
        }
        .frame(height: 116)
        .accessibilityElement(children: .combine)
    }
}
