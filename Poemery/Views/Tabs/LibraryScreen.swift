import SwiftUI

struct LibraryScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    let onRefresh: @Sendable () async -> Void

    @State private var selectedShelf: LibraryShelf = .poems
    @State private var selectedSort: LibrarySort = .curated

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
                ScreenHeader(title: "你的诗歌书库", subtitle: nil)
                localLibraryStatus

                libraryShelfPicker
                librarySortPicker

                VStack(spacing: 0) {
                    LibraryNavigationRow(
                        symbol: "rectangle.stack.fill",
                        title: "诗单",
                        value: "\(library.totalCollectionCount)",
                        destination: .collections
                    )
                    LibraryNavigationRow(
                        symbol: "person.2.fill",
                        title: "诗人",
                        value: "\(library.totalAuthorCount)",
                        destination: .authors
                    )
                    LibraryNavigationRow(
                        symbol: "text.book.closed.fill",
                        title: "诗词",
                        value: "\(library.totalPoemCount)",
                        destination: .poems
                    )
                    LibraryNavigationRow(
                        symbol: "chart.bar.fill",
                        title: "作品榜",
                        value: "\(library.chartPoems(limit: 100).count)",
                        destination: .chart
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

                shelfPreview

                CollectionListSection(
                    collections: library.collections,
                    library: library,
                    onOpenCollection: onOpenCollection
                )
            }
            .screenContentPadding()
        }
        .refreshable {
            await onRefresh()
        }
        .navigationTitle("资料库")
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private var localLibraryStatus: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "internaldrive.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(PoemeryTheme.accent)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("本地诗库已就绪")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PoemeryTheme.primaryText)

                Text("离线收录 \(library.totalPoemCount) 首 · \(library.totalAuthorCount) 位作者")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .groupedListBackground()
        .accessibilityElement(children: .combine)
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

    private var libraryShelfPicker: some View {
        Picker("资料库内容", selection: $selectedShelf) {
            ForEach(LibraryShelf.allCases) { shelf in
                Text(shelf.title).tag(shelf)
            }
        }
        .pickerStyle(.segmented)
    }

    private var librarySortPicker: some View {
        Picker("排序", selection: $selectedSort) {
            ForEach(LibrarySort.allCases) { sort in
                Text(sort.title).tag(sort)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var shelfPreview: some View {
        switch selectedShelf {
        case .poems:
            PoemListSection(
                title: selectedSort.title,
                poems: sortedPoems(Array(library.poems.prefix(80))).prefixArray(6),
                queueTitle: "诗词",
                onOpenPoem: onOpenPoem
            )

            PoemListSection(
                title: "作品榜",
                poems: library.chartPoems(limit: 8),
                queueTitle: "作品榜",
                onOpenPoem: onOpenPoem
            )
        case .favorites:
            PoemShelf(
                title: "收藏",
                poems: sortedPoems(favoritePoems),
                emptyTitle: "还没有收藏",
                emptySubtitle: "打开作品详情后可以把喜欢的诗词加入收藏。",
                onOpenPoem: onOpenPoem
            )
        case .recents:
            PoemShelf(
                title: "最近阅读",
                poems: recentPoems,
                emptyTitle: "还没有最近阅读",
                emptySubtitle: "打开任意作品详情后会出现在这里。",
                onOpenPoem: onOpenPoem
            )
        case .authors:
            AuthorShelf(authors: Array(authors.prefix(8))) { author in
                if let firstPoem = author.poems.first {
                    onOpenPoem(firstPoem, ReadingQueue(title: author.name, poems: author.poems))
                }
            }
        }
    }

    private func sortedPoems(_ poems: [Poem]) -> [Poem] {
        switch selectedSort {
        case .curated:
            poems
        case .title:
            poems.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .author:
            poems.sorted {
                let authorOrder = $0.author.localizedCompare($1.author)
                if authorOrder == .orderedSame {
                    return $0.title.localizedCompare($1.title) == .orderedAscending
                }
                return authorOrder == .orderedAscending
            }
        }
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
            PagedAuthorDirectoryView(library: library)
        case .authorDetail(let author):
            PagedAuthorDetailContent(
                author: author,
                library: library,
                onOpenPoem: onOpenPoem
            )
        case .author(let authorID):
            if let author = authors.first(where: { $0.id == authorID }) {
                PagedAuthorDetailContent(
                    author: author,
                    library: library,
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
            PagedPoemDirectoryView(
                title: "诗词",
                library: library,
                emptyTitle: "暂无诗词",
                emptySubtitle: "诗库暂时没有可阅读的作品。",
                queueTitle: "诗词",
                onOpenPoem: onOpenPoem
            )
        case .chart:
            PoemDirectoryView(
                title: "作品榜",
                poems: library.chartPoems(limit: 100),
                emptyTitle: "暂无排行",
                emptySubtitle: "当前诗库暂时无法生成作品榜。",
                queueTitle: "作品榜",
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
    case authorDetail(AuthorResult)
    case author(AuthorResult.ID)
    case poems
    case chart
    case favorites
    case recents
}

private enum LibraryShelf: String, CaseIterable, Identifiable {
    case poems
    case favorites
    case recents
    case authors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .poems: "诗词"
        case .favorites: "收藏"
        case .recents: "最近"
        case .authors: "诗人"
        }
    }
}

private enum LibrarySort: String, CaseIterable, Identifiable {
    case curated
    case title
    case author

    var id: String { rawValue }

    var title: String {
        switch self {
        case .curated: "精选排序"
        case .title: "按题名"
        case .author: "按作者"
        }
    }
}

private extension Array {
    func prefixArray(_ maxLength: Int) -> [Element] {
        Array(prefix(maxLength))
    }
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
                        NavigationLink(value: LibraryDestination.authorDetail(author)) {
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

                Text("\(author.dynasty) · \(author.poemCount) 首")
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

private struct PagedPoemDirectoryView: View {
    let title: String
    let library: PoemLibraryStore
    let emptyTitle: String
    let emptySubtitle: String
    let queueTitle: String
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    @Environment(\.chineseScriptPreference) private var script
    @State private var poems: [Poem] = []
    @State private var nextPage: Int? = 1
    @State private var total = 0
    @State private var isLoading = false

    private var displayTotal: Int {
        max(total, library.totalPoemCount)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                directoryProgress

                if poems.isEmpty && isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .groupedListBackground()
                } else if poems.isEmpty {
                    EmptyLibraryState(title: emptyTitle, subtitle: emptySubtitle)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(poems.enumerated()), id: \.element.id) { index, poem in
                            Button {
                                onOpenPoem(poem, ReadingQueue(title: queueTitle, poems: poems))
                            } label: {
                                PoemListRow(poem: poem)
                            }
                            .buttonStyle(.plain)
                            .task {
                                await loadNextPageIfNeeded(currentIndex: index)
                            }

                            if index != poems.indices.last {
                                Divider()
                                    .padding(.leading, 74)
                            }
                        }
                    }
                    .libraryListCard()

                    directoryFooter
                }
            }
            .screenContentPadding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
        .task(id: script.rawValue) {
            await reloadFirstPage()
        }
    }

    private var directoryProgress: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("本地诗词")
                .font(.caption.weight(.bold))
                .foregroundStyle(PoemeryTheme.accent)

            Text("\(poems.count) / \(displayTotal)")
                .font(.title3.weight(.bold))
                .foregroundStyle(PoemeryTheme.primaryText)
                .monospacedDigit()

            Text("向下滚动会继续加载本地诗库。")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .groupedListBackground()
    }

    @ViewBuilder
    private var directoryFooter: some View {
        if nextPage != nil || isLoading {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.down.circle")
                }
                Text(isLoading ? "加载中" : "继续向下浏览")
                Spacer()
                Text("\(poems.count) / \(displayTotal)")
                    .foregroundStyle(PoemeryTheme.tertiaryText)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 44)
            .groupedListBackground()
        }
    }

    private func loadFirstPage() async {
        guard poems.isEmpty else {
            return
        }
        await loadPage(1)
    }

    private func reloadFirstPage() async {
        poems = []
        nextPage = 1
        total = 0
        await loadPage(1)
    }

    private func loadNextPageIfNeeded(currentIndex: Int) async {
        guard let nextPage, currentIndex >= poems.count - 8 else {
            return
        }
        await loadPage(nextPage)
    }

    private func loadPage(_ page: Int) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        let result = await library.loadPoemsPage(page: page, script: script)
        if page <= 1 {
            poems = result.poems
        } else {
            poems.append(contentsOf: result.poems)
        }
        total = result.total
        nextPage = result.nextPage
        isLoading = false
    }
}

private struct PagedAuthorDirectoryView: View {
    let library: PoemLibraryStore

    @Environment(\.chineseScriptPreference) private var script
    @State private var authors: [AuthorResult] = []
    @State private var nextPage: Int? = 1
    @State private var total = 0
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            if authors.isEmpty && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .screenContentPadding()
            } else if authors.isEmpty {
                EmptyLibraryState(title: "暂无诗人", subtitle: "诗库暂时没有可浏览的诗人。")
                    .screenContentPadding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(authors) { author in
                        NavigationLink(value: LibraryDestination.authorDetail(author)) {
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

                if nextPage != nil {
                    VStack {
                        Button(action: loadMore) {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                }
                                Text(isLoading ? "加载中" : "继续加载")
                                Spacer()
                                Text("\(authors.count) / \(total)")
                                    .foregroundStyle(PoemeryTheme.tertiaryText)
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(PoemeryTheme.accent)
                        .disabled(isLoading)
                    }
                    .screenContentPadding()
                }
            }
        }
        .navigationTitle("诗人")
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
        .task(id: script.rawValue) {
            await reloadFirstPage()
        }
    }

    private func loadFirstPage() async {
        guard authors.isEmpty else {
            return
        }
        await loadPage(1)
    }

    private func reloadFirstPage() async {
        authors = []
        nextPage = 1
        total = 0
        await loadPage(1)
    }

    private func loadMore() {
        guard let nextPage else {
            return
        }

        Task {
            await loadPage(nextPage)
        }
    }

    private func loadPage(_ page: Int) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        let result = await library.loadAuthorsPage(page: page, script: script)
        if page <= 1 {
            authors = result.authors
        } else {
            authors.append(contentsOf: result.authors)
        }
        total = result.total
        nextPage = result.nextPage
        isLoading = false
    }
}

private extension View {
    func libraryListCard() -> some View {
        groupedListBackground()
    }
}
