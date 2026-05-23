import SwiftUI

struct HomeScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                ScreenHeader(title: "主页", subtitle: "诗词歌赋，为你继续阅读")

                FeaturedCarousel(
                    title: "专属精选推荐",
                    collections: featuredCollections,
                    library: library,
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
                    poems: Array(library.poems.prefix(4)),
                    onOpenPoem: onOpenPoem
                )

                PoemShelf(
                    title: "为你推荐",
                    poems: Array(library.poems.dropFirst(3).prefix(8)),
                    onOpenPoem: onOpenPoem
                )

                AuthorShelf(authors: Array(library.authors().prefix(6)), onOpenPoem: onOpenPoem)
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
        return poems.isEmpty ? Array(library.poems.prefix(3)) : poems
    }
}
