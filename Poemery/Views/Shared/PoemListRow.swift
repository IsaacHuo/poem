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

struct PoemSearchResultRow: View {
    let item: PoemListItem

    var body: some View {
        HStack(spacing: 12) {
            PoemArtwork(item: item, size: 54, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if let matchLabel {
                        Text(matchLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PoemeryTheme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PoemeryTheme.accent.opacity(0.12), in: Capsule())
                    }

                    Text(highlighted(item.title, baseColor: PoemeryTheme.primaryText))
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                }

                Text(detailText)
                    .font(.subheadline)
                    .lineLimit(item.searchMatch?.kind == .content ? 2 : 1)
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

    private var matchLabel: String? {
        switch item.searchMatch?.kind {
        case .title: "题目"
        case .author: "作者"
        case .content: "正文"
        case .metadata, nil: nil
        }
    }

    private var detailText: AttributedString {
        guard let match = item.searchMatch else {
            return highlighted(
                item.displayArtist + " · " + item.form,
                baseColor: PoemeryTheme.secondaryText
            )
        }

        switch match.kind {
        case .title:
            return highlighted(
                item.displayArtist + " · " + item.form,
                baseColor: PoemeryTheme.secondaryText
            )
        case .author:
            return highlighted(
                item.displayArtist + " · " + item.form,
                query: match.highlightedQuery,
                baseColor: PoemeryTheme.secondaryText
            )
        case .content:
            return highlighted(
                match.text,
                query: match.highlightedQuery,
                baseColor: PoemeryTheme.secondaryText
            )
        case .metadata:
            return highlighted(
                match.text,
                query: match.highlightedQuery,
                baseColor: PoemeryTheme.secondaryText
            )
        }
    }

    private func highlighted(_ text: String, query: String? = nil, baseColor: Color) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = baseColor
        let searchText = query ?? item.searchMatch?.highlightedQuery
        guard let searchText, !searchText.isEmpty else {
            return attributed
        }

        if let range = attributed.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].foregroundColor = PoemeryTheme.accent
        }

        return attributed
    }
}
