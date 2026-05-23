import SwiftUI

struct PoemListRow: View {
    let poem: Poem

    var body: some View {
        HStack(spacing: 12) {
            PoemArtwork(poem: poem, size: 54, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(poem.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(1)
                Text("\(poem.displayArtist) · \(poem.form)")
                    .font(.subheadline)
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "ellipsis")
                .font(.headline.weight(.bold))
                .foregroundStyle(PoemeryTheme.tertiaryText)
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
