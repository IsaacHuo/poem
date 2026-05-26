import SwiftUI

struct DiscoverScreen: View {
    let library: PoemLibraryStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    let onStartSearch: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(title: "新发现", subtitle: "诗单与题材入口")
                discoveryContent
            }
            .screenContentPadding()
        }
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private var discoveryContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            FeaturedCarousel(
                title: "新诗单",
                collections: library.collections.filter { [.chart, .mood, .featured].contains($0.kind) },
                library: library,
                onOpenCollection: onOpenCollection
            )

            PoemListSection(title: "新诗精选", poems: library.popularPoems(limit: 6), onOpenPoem: onOpenPoem)

            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "浏览题材")

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(library.categories) { category in
                        Button {
                            onStartSearch(category.title)
                        } label: {
                            CategoryTile(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
