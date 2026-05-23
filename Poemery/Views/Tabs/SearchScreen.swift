import SwiftUI

struct SearchScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    @Binding var searchText: String
    let onOpenPoem: (Poem) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var results: SearchResults {
        library.search(searchText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "搜索", subtitle: nil)

                SearchField(text: $searchText)

                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionTitle(title: "浏览类别")

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
                } else if results.isEmpty {
                    EmptyLibraryState(title: "未找到结果", subtitle: "试试诗名、作者、题材或正文里的字句。")
                } else {
                    SearchResultsView(
                        results: results,
                        onOpenPoem: onOpenPoem,
                        onOpenCollection: onOpenCollection
                    )
                }
            }
            .screenContentPadding()
        }
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }
}
