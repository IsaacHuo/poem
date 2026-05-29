import SwiftUI

struct LibraryScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        NavigationStack {
            rootContent
                .navigationDestination(for: LibraryDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
    }

    private var rootContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeader(title: "收藏、诗单、诗人与最近阅读", subtitle: nil)

                VStack(spacing: 0) {
                    LibraryNavigationRow(
                        symbol: "rectangle.stack.fill",
                        title: "诗单",
                        value: "\(library.collections.count)",
                        destination: .collections
                    )
                    LibraryNavigationRow(
                        symbol: "person.2.fill",
                        title: "诗人",
                        value: "\(authors.count)",
                        destination: .authors
                    )
                    LibraryNavigationRow(
                        symbol: "text.book.closed.fill",
                        title: "诗词",
                        value: "\(library.poems.count)",
                        destination: .poems
                    )
                    LibraryNavigationRow(
                        symbol: "heart.fill",
                        title: "收藏",
                        value: "\(favoritePoems.count)",
                        destination: .favorites
                    )
                    LibraryNavigationRow(
                        symbol: "clock.fill",
                        title: "最近阅读",
                        value: "\(recentPoems.count)",
                        destination: .recents
                    )
                }
                .groupedListBackground()

                PoemShelf(
                    title: "最近添加",
                    poems: Array(library.poems.prefix(8)),
                    onOpenPoem: onOpenPoem
                )

                CollectionListSection(
                    collections: library.collections,
                    library: library,
                    onOpenCollection: onOpenCollection
                )
            }
            .screenContentPadding()
        }
        .navigationTitle("资料库")
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private var authors: [AuthorResult] {
        library.authors()
    }

    private var favoritePoems: [Poem] {
        session.favoritePoems(in: library)
    }

    private var recentPoems: [Poem] {
        session.recentPoems(in: library)
    }

    @ViewBuilder
    private func destinationView(for destination: LibraryDestination) -> some View {
        switch destination {
        case .collections:
            ScrollView {
                CollectionListSection(
                    title: "全部诗单",
                    collections: library.collections,
                    library: library,
                    onOpenCollection: onOpenCollection
                )
                .screenContentPadding()
            }
            .navigationTitle("诗单")
            .navigationBarTitleDisplayMode(.large)
            .scrollIndicators(.hidden)
            .background(PoemeryTheme.background)
        case .authors:
            AuthorDirectoryView(authors: authors)
        case .author(let authorID):
            if let author = authors.first(where: { $0.id == authorID }) {
                PoemDirectoryView(
                    title: author.name,
                    poems: author.poems,
                    emptyTitle: "暂无作品",
                    emptySubtitle: "这个诗人暂时没有可阅读的作品。",
                    queueTitle: author.name,
                    onOpenPoem: onOpenPoem
                )
            } else {
                PoemDirectoryView(
                    title: "诗人",
                    poems: [],
                    emptyTitle: "未找到诗人",
                    emptySubtitle: "这个诗人条目已经不可用。",
                    queueTitle: "诗人",
                    onOpenPoem: onOpenPoem
                )
            }
        case .poems:
            PoemDirectoryView(
                title: "诗词",
                poems: library.poems,
                emptyTitle: "暂无诗词",
                emptySubtitle: "诗库暂时没有可阅读的作品。",
                queueTitle: "诗词",
                onOpenPoem: onOpenPoem
            )
        case .favorites:
            PoemDirectoryView(
                title: "收藏",
                poems: favoritePoems,
                emptyTitle: "还没有收藏",
                emptySubtitle: "打开作品详情后可以把喜欢的诗词加入收藏。",
                queueTitle: "收藏",
                onOpenPoem: onOpenPoem
            )
        case .recents:
            PoemDirectoryView(
                title: "最近阅读",
                poems: recentPoems,
                emptyTitle: "还没有最近阅读",
                emptySubtitle: "打开任意作品详情后会出现在这里。",
                queueTitle: "最近阅读",
                onOpenPoem: onOpenPoem
            )
        }
    }
}

private enum LibraryDestination: Hashable {
    case collections
    case authors
    case author(AuthorResult.ID)
    case poems
    case favorites
    case recents
}

private struct LibraryNavigationRow: View {
    let symbol: String
    let title: String
    let value: String
    let destination: LibraryDestination

    var body: some View {
        NavigationLink(value: destination) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.accent)
                    .frame(width: 32, height: 32)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(PoemeryTheme.primaryText)

                Spacer()

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AuthorDirectoryView: View {
    let authors: [AuthorResult]

    var body: some View {
        ScrollView {
            if authors.isEmpty {
                EmptyLibraryState(title: "暂无诗人", subtitle: "诗库暂时没有可浏览的诗人。")
                    .screenContentPadding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(authors) { author in
                        NavigationLink(value: LibraryDestination.author(author.id)) {
                            AuthorDirectoryRow(author: author)
                        }
                        .buttonStyle(.plain)

                        if author.id != authors.last?.id {
                            Divider()
                                .padding(.leading, 72)
                        }
                    }
                }
                .libraryListCard()
                .screenContentPadding()
            }
        }
        .navigationTitle("诗人")
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }
}

private struct AuthorDirectoryRow: View {
    let author: AuthorResult

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PoemeryTheme.groupedBackground)

                Text(String(author.name.prefix(1)))
                    .font(PoemeryTheme.chineseFont(size: 26, relativeTo: .title3))
                    .foregroundStyle(PoemeryTheme.accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(author.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(1)

                Text("\(author.dynasty) · \(author.poems.count) 首")
                    .font(.subheadline)
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PoemeryTheme.tertiaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct PoemDirectoryView: View {
    let title: String
    let poems: [Poem]
    let emptyTitle: String
    let emptySubtitle: String
    let queueTitle: String
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    var body: some View {
        ScrollView {
            if poems.isEmpty {
                EmptyLibraryState(title: emptyTitle, subtitle: emptySubtitle)
                    .screenContentPadding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(poems) { poem in
                        Button {
                            onOpenPoem(poem, ReadingQueue(title: queueTitle, poems: poems))
                        } label: {
                            PoemListRow(poem: poem)
                        }
                        .buttonStyle(.plain)

                        if poem.id != poems.last?.id {
                            Divider()
                                .padding(.leading, 74)
                        }
                    }
                }
                .libraryListCard()
                .screenContentPadding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }
}

private extension View {
    func libraryListCard() -> some View {
        groupedListBackground()
    }
}
