import SwiftUI

struct SearchResultsView: View {
    let results: SearchResults
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PoemListSection(title: "诗词", poems: results.poems, queueTitle: "搜索结果", onOpenPoem: onOpenPoem)

            if !results.authors.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(title: "作者")
                    ForEach(results.authors) { author in
                        Button {
                            if let poem = author.poems.first {
                                onOpenPoem(poem, ReadingQueue(title: author.name, poems: author.poems))
                            }
                        } label: {
                            HStack {
                                Text(author.name)
                                    .font(.headline)
                                    .foregroundStyle(PoemeryTheme.primaryText)
                                Text(author.dynasty)
                                    .font(.subheadline)
                                    .foregroundStyle(PoemeryTheme.secondaryText)
                                Spacer()
                                Text("\(author.poems.count) 首")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PoemeryTheme.accent)
                            }
                            .padding()
                            .background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(PoemeryTheme.tertiaryText)
                            }
                            .padding()
                            .background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
