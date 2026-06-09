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

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PoemeryTheme.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

struct PoemListItemRow: View {
    let item: PoemListItem

    var body: some View {
        HStack(spacing: 12) {
            PoemArtwork(item: item, size: 54, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(1)
                Text("\(item.displayArtist) · \(item.form)")
                    .font(.subheadline)
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PoemeryTheme.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
