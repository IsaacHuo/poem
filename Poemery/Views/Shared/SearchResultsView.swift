import SwiftUI

struct SearchResultsView: View {
    let results: SearchResultsPage
    let isLoadingMore: Bool
    let onOpenPoem: (PoemListItem) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    let onOpenAuthor: (AuthorResult) -> Void
    let onLoadMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !results.poems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: poemSectionTitle)

                    LazyVStack(spacing: 0) {
                        ForEach(Array(results.poems.enumerated()), id: \.element.id) { index, poem in
                            Button {
                                onOpenPoem(poem)
                            } label: {
                                PoemSearchResultRow(item: poem)
                            }
                            .buttonStyle(.plain)

                            if index != results.poems.indices.last {
                                Divider()
                                    .padding(.leading, 74)
                            }
                        }
                    }
                    .groupedListBackground()

                    if results.nextOffset != nil {
                        Button(action: onLoadMore) {
                            HStack(spacing: 8) {
                                if isLoadingMore {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                }

                                Text(isLoadingMore ? "加载中" : "继续加载")
                                Spacer()
                                Text("\(results.poems.count) / \(results.totalPoemCount)")
                                    .foregroundStyle(PoemeryTheme.tertiaryText)
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(PoemeryTheme.accent)
                        .disabled(isLoadingMore)
                    }
                }
            }

            if !results.authors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "作者")
                    ForEach(results.authors) { author in
                        Button {
                            onOpenAuthor(author)
                        } label: {
                            HStack {
                                Text(author.name)
                                    .font(.headline)
                                    .foregroundStyle(PoemeryTheme.primaryText)
                                Text(author.dynasty)
                                    .font(.subheadline)
                                    .foregroundStyle(PoemeryTheme.secondaryText)
                                Spacer()
                                Text("\(author.poemCount) 首")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PoemeryTheme.accent)
                            }
                            .padding()
                            .groupedListBackground()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !results.collections.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "合集")
                    ForEach(results.collections) { collection in
                        Button {
                            onOpenCollection(collection)
                        } label: {
                            HStack {
                                Text(collection.title)
                                    .font(.headline)
                                    .foregroundStyle(PoemeryTheme.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PoemeryTheme.tertiaryText)
                            }
                            .padding()
                            .groupedListBackground()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var poemSectionTitle: String {
        results.nextOffset == nil ? "诗词" : "诗词 · \(results.totalPoemCount) 首"
    }
}
