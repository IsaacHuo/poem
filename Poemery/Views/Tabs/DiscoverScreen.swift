import SwiftUI

struct DiscoverScreen: View {
    let library: PoemLibraryStore
    @Binding var searchText: String
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    private static let contentTopID = "discover-content-top"

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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Color.clear
                        .frame(height: 0)
                        .id(Self.contentTopID)

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
                        discoveryContent(scrollProxy: proxy)
                    }
                }
                .screenContentPadding()
            }
            .scrollIndicators(.hidden)
            .background(PoemeryTheme.background)
        }
    }

    private func discoveryContent(scrollProxy: ScrollViewProxy) -> some View {
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
                            withAnimation(PoemeryTheme.motion) {
                                scrollProxy.scrollTo(Self.contentTopID, anchor: .top)
                            }
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
