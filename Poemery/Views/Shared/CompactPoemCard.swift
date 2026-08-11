import SwiftUI

struct CompactPoemCard: View {
    let poem: Poem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PoemArtwork(poem: poem, size: 124, cornerRadius: 9)
            Text(poem.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.primaryText)
                .lineLimit(2)
                .frame(width: 124, alignment: .leading)
                .frame(minHeight: 36, alignment: .topLeading)
            Text("\(poem.author)，\(poem.form)")
                .font(.caption)
                .foregroundStyle(PoemeryTheme.tertiaryText)
                .lineLimit(2)
                .frame(width: 124, alignment: .leading)
        }
    }
}
