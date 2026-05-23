import SwiftUI

struct LibraryScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(title: "资料库", subtitle: "收藏、诗单、诗人与最近阅读")

                VStack(spacing: 0) {
                    LibraryNavigationRow(symbol: "rectangle.stack.fill", title: "诗单", value: "\(library.collections.count)") {
                        openFirstCollection()
                    }
                    LibraryNavigationRow(symbol: "person.2.fill", title: "诗人", value: "\(library.authors().count)") {
                        openFirstAuthor()
                    }
                    LibraryNavigationRow(symbol: "text.book.closed.fill", title: "诗词", value: "\(library.poems.count)") {
                        openFirstPoem()
                    }
                    LibraryNavigationRow(symbol: "heart.fill", title: "收藏", value: "\(session.favoritePoemIDs.count)") {
                        openFirstFavorite()
                    }
                    LibraryNavigationRow(symbol: "clock.fill", title: "最近阅读", value: "\(session.recentPoemIDs.count)") {
                        openFirstRecent()
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.58), lineWidth: 0.6)
                }

                PoemShelf(
                    title: "最近添加",
                    poems: Array(library.poems.prefix(8)),
                    onOpenPoem: onOpenPoem
                )

                CollectionListSection(
                    collections: library.collections,
                    library: library,
                    onOpenCollection: onOpenCollection
                )
            }
            .screenContentPadding()
        }
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private func openFirstCollection() {
        if let collection = library.collections.first {
            onOpenCollection(collection)
        }
    }

    private func openFirstAuthor() {
        if let poem = library.authors().first?.poems.first {
            onOpenPoem(poem)
        }
    }

    private func openFirstPoem() {
        if let poem = library.poems.first {
            onOpenPoem(poem)
        }
    }

    private func openFirstFavorite() {
        if let poem = session.favoritePoems(in: library).first {
            onOpenPoem(poem)
        } else {
            openFirstPoem()
        }
    }

    private func openFirstRecent() {
        if let poem = session.recentPoems(in: library).first {
            onOpenPoem(poem)
        } else {
            openFirstPoem()
        }
    }
}

private struct LibraryNavigationRow: View {
    let symbol: String
    let title: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.accent)
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(PoemeryTheme.primaryText)

                Spacer()

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
