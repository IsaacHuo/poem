import SwiftUI

struct HomeScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    @Environment(\.chineseScriptPreference) private var script
    @State private var loadedFavorites: [Poem] = []
    @State private var loadedRecents: [Poem] = []
    @State private var loadedRecommendations: [Poem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let currentPoem = session.currentPoem(in: library) {
                        PoemListSection(
                            title: "继续阅读",
                            poems: [currentPoem],
                            queueTitle: session.currentQueue?.title ?? "继续阅读",
                            onOpenPoem: onOpenPoem
                        )
                    }

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

                    PoemShelf(
                        title: "最近阅读",
                        poems: recentPoems,
                        emptyTitle: "还没有阅读记录",
                        emptySubtitle: "读过的作品会在这里方便继续。",
                        onOpenPoem: onOpenPoem
                    )

                    PoemListSection(
                        title: "为你推荐",
                        poems: recommendations,
                        onOpenPoem: onOpenPoem
                    )
                }
                .screenContentPadding()
            }
            .navigationTitle("主页")
            .navigationBarTitleDisplayMode(.large)
            .scrollIndicators(.hidden)
            .background(PoemeryTheme.background)
            .task(id: snapshotTaskID) {
                async let favorites = library.loadSummaries(ids: session.favoritePoemIDs, script: script)
                async let recents = library.loadSummaries(ids: session.recentPoemIDs, script: script)
                async let recommendations = library.loadRecommendations(
                    recentIDs: session.recentPoemIDs,
                    favoriteIDs: session.favoritePoemIDs,
                    limit: 6,
                    script: script
                )
                loadedFavorites = await favorites
                loadedRecents = await recents
                loadedRecommendations = await recommendations
            }
        }
    }

    private var featuredCollections: [PoemCollection] {
        library.collections.filter { [.featured, .author, .mood].contains($0.kind) }
    }

    private var favoritePoems: [Poem] {
        loadedFavorites
    }

    private var recentPoems: [Poem] {
        loadedRecents
    }

    private var recommendations: [Poem] {
        loadedRecommendations.isEmpty ? library.popularPoems(limit: 6) : loadedRecommendations
    }

    private var snapshotTaskID: String {
        "\(script.rawValue)|\(session.favoritePoemIDs.joined(separator: ","))|\(session.recentPoemIDs.joined(separator: ","))|\(library.totalPoemCount)"
    }
}
