import SwiftUI

struct HomeScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    let onOpenAuthor: (AuthorResult) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ScreenHeader(title: "诗意很远，心意很近。", subtitle: nil)

                    PoemShelf(
                        title: "继续阅读",
                        poems: continueReadingPoems,
                        emptyTitle: "还没有最近阅读",
                        emptySubtitle: "打开任意一首诗词后会出现在这里。",
                        onOpenPoem: onOpenPoem
                    )

                    FeaturedCarousel(
                        title: "今日精选",
                        collections: featuredCollections,
                        library: library,
                        layout: .narrowPortrait,
                        onOpenCollection: onOpenCollection
                    )

                    PoemShelf(
                        title: "最近收藏",
                        poems: favoritePoems,
                        emptyTitle: "还没有收藏",
                        emptySubtitle: "收藏喜欢的作品后会在这里汇成书架。",
                        onOpenPoem: onOpenPoem
                    )

                    PoemListSection(
                        title: "从经典开始",
                        poems: library.popularPoems(limit: 5),
                        onOpenPoem: onOpenPoem
                    )

                    PoemShelf(
                        title: recommendationTitle,
                        poems: recommendedPoems,
                        onOpenPoem: onOpenPoem
                    )

                    AuthorShelf(authors: library.popularAuthors(limit: 6), onOpenAuthor: onOpenAuthor)
                }
                .screenContentPadding()
            }
            .navigationTitle("主页")
            .navigationBarTitleDisplayMode(.large)
            .scrollIndicators(.hidden)
            .background(PoemeryTheme.background)
        }
    }

    private var featuredCollections: [PoemCollection] {
        library.collections.filter { [.featured, .author, .mood].contains($0.kind) }
    }

    private var continueReadingPoems: [Poem] {
        let recent = session.recentPoems(in: library)
        return recent.isEmpty ? Array(library.popularPoems(limit: 6).prefix(4)) : recent
    }

    private var favoritePoems: [Poem] {
        let favorites = session.favoritePoems(in: library)
        return favorites.isEmpty ? Array(library.popularPoems(limit: 10).dropFirst(4).prefix(4)) : favorites
    }

    private var recommendedPoems: [Poem] {
        if let recent = session.recentPoems(in: library).first {
            let themed = recent.themes.lazy
                .flatMap { library.poems(forTheme: $0, limit: 8) }
                .filter { $0.id != recent.id }
            let unique = Array(Dictionary(grouping: themed, by: \.id).compactMap { $0.value.first }.prefix(8))
            if !unique.isEmpty {
                return unique
            }
        }
        return Array(library.popularPoems(limit: 16).dropFirst(8).prefix(8))
    }

    private var recommendationTitle: String {
        guard let recent = session.recentPoems(in: library).first,
              let theme = recent.themes.first
        else {
            return "为你推荐"
        }
        return "延续\(theme)"
    }
}
