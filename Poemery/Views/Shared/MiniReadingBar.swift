import SwiftUI

struct MiniReadingBar: View {
    let poem: Poem
    let namespace: Namespace.ID
    let onOpen: () -> Void
    let onContinue: () -> Void
    let onNext: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                PoemArtwork(poem: poem, size: 36, cornerRadius: 7)

                VStack(alignment: .leading, spacing: 2) {
                    Text(poem.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.primaryText)
                        .lineLimit(1)
                    Text(poem.author)
                        .font(.caption)
                        .foregroundStyle(PoemeryTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: onContinue) {
                    Image(systemName: "play.fill")
                        .font(.headline.weight(.bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("继续诵读")

                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                        .font(.headline.weight(.bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("下一首诗词")
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .foregroundStyle(PoemeryTheme.primaryText)
            .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassContainer(cornerRadius: 28, tint: .white.opacity(0.60), namespace: namespace, glassID: "mini-reading-bar")
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在阅读，\(poem.title)，\(poem.author)")
    }
}
