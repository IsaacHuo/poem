import SwiftUI

struct HomeScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    let onOpenAuthor: (AuthorResult) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                ScreenHeader(title: "主页", subtitle: "诗意很远，心意很近。")

                FeaturedCarousel(
                    title: "专属精选推荐",
                    collections: featuredCollections,
                    library: library,
                    layout: .narrowPortrait,
                    onOpenCollection: onOpenCollection
                )

                PoemShelf(
                    title: "最近阅读",
                    poems: recentPoems,
                    emptyTitle: "还没有最近阅读",
                    emptySubtitle: "打开任意一首诗词后会出现在这里。",
                    onOpenPoem: onOpenPoem
                )

                PoemListSection(
                    title: "开始阅读",
                    poems: library.popularPoems(limit: 4),
                    onOpenPoem: onOpenPoem
                )

                PoemShelf(
                    title: "为你推荐",
                    poems: recommendedPoems,
                    onOpenPoem: onOpenPoem
                )

                AuthorShelf(authors: library.popularAuthors(limit: 6), onOpenAuthor: onOpenAuthor)
            }
            .screenContentPadding()
        }
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private var featuredCollections: [PoemCollection] {
        library.collections.filter { [.featured, .author, .mood].contains($0.kind) }
    }

    private var recentPoems: [Poem] {
        let poems = session.recentPoems(in: library)
        return poems.isEmpty ? library.popularPoems(limit: 3) : poems
    }

    private var recommendedPoems: [Poem] {
        Array(library.popularPoems(limit: 12).dropFirst(4).prefix(8))
    }
}
