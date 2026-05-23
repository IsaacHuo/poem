import SwiftUI

struct DiscoverScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(title: "新发现", subtitle: "新诗单、排行榜与题材入口")

                FeaturedCarousel(
                    title: "新诗单",
                    collections: library.collections.filter { [.chart, .mood, .featured].contains($0.kind) },
                    library: library,
                    onOpenCollection: onOpenCollection
                )

                PoemListSection(title: "新诗精选", poems: Array(library.poems.prefix(6)), onOpenPoem: onOpenPoem)

                VStack(alignment: .leading, spacing: 14) {
                    SectionTitle(title: "浏览题材")

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(library.categories) { category in
                            Button {
                                open(category)
                            } label: {
                                CategoryTile(category: category)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .screenContentPadding()
        }
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private func open(_ category: PoemCategory) {
        if let poem = library.poems(matching: category).first {
            onOpenPoem(poem)
        }
    }
}
