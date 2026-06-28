import SwiftUI

struct HomeScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
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

    private var favoritePoems: [Poem] {
        session.favoritePoems(in: library)
    }
}
