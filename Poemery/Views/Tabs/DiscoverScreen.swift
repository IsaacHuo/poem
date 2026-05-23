import SwiftUI

struct DiscoverScreen: View {
    let library: PoemLibraryStore
    @Binding var searchText: String
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var results: SearchResults {
        library.search(searchText)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(title: "新发现", subtitle: "搜索、诗单与题材入口")
                SearchField(text: $searchText)

                if isSearching {
                    if results.isEmpty {
                        EmptyLibraryState(title: "未找到结果", subtitle: "试试诗名、作者、题材或正文里的字句。")
                    } else {
                        SearchResultsView(
                            results: results,
                            onOpenPoem: onOpenPoem,
                            onOpenCollection: onOpenCollection
                        )
                    }
                } else {
                    discoveryContent
                }
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

            PoemListSection(title: "新诗精选", poems: Array(library.poems.prefix(6)), onOpenPoem: onOpenPoem)

            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "浏览题材")

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(library.categories) { category in
                        Button {
                            searchText = category.title
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
