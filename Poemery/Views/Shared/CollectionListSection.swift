import SwiftUI

struct CollectionListSection: View {
    var title: String = "诗单"
    let collections: [PoemCollection]
    let library: PoemLibraryStore
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title, showsChevron: !collections.isEmpty)

            VStack(spacing: 0) {
                ForEach(collections) { collection in
                    Button {
                        onOpenCollection(collection)
                    } label: {
                        CollectionListRow(collection: collection, count: library.poems(for: collection).count)
                    }
                    .buttonStyle(.plain)

                    if collection.id != collections.last?.id {
                        Divider()
                            .padding(.leading, 76)
                    }
                }
            }
            .groupedListBackground()
        }
    }
}

private struct CollectionListRow: View {
    let collection: PoemCollection
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [collection.accent.primary, collection.accent.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(collection.accent.glyph)
                    .font(PoemeryTheme.chineseFont(size: 28, relativeTo: .title3))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(collection.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(1)
                Text("\(collection.subtitle) · \(count) 首")
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
