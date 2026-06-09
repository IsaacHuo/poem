import SwiftUI

struct ContentView: View {
    @AppStorage(ChineseScriptPreference.storageKey) private var chineseScriptRawValue = ChineseScriptPreference.simplified.rawValue
    @State private var libraryLoadState: LibraryLoadState = .loading
    @State private var session = ReadingSessionStore()
    @State private var selectedTab: AppTab = .home
    @State private var lastContentTab: AppTab = .home
    @State private var presentedItem: PresentedLibraryItem?
    @State private var tabSearchText = ""

    var body: some View {
        content
            .tint(PoemeryTheme.accent)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .background(PoemeryTheme.background.ignoresSafeArea())
            .sheet(item: $presentedItem) { item in
                presentedView(for: item)
            }
            .preferredColorScheme(.light)
            .onChange(of: selectedTab) { _, newTab in
                if newTab != .search {
                    lastContentTab = newTab
                }
            }
            .task(id: chineseScriptRawValue) {
                await loadLibrary()
            }
    }

    private var chineseScriptPreference: ChineseScriptPreference {
        ChineseScriptPreference(rawValue: chineseScriptRawValue)
    }

    @ViewBuilder
    private var content: some View {
        switch libraryLoadState {
        case .loading:
            LibraryLoadingScreen()
        case .loaded(let library):
            tabContainer(library: library)
        case .failed:
            LibraryLoadFailedScreen {
                libraryLoadState = .loading
                Task {
                    await loadLibrary()
                }
            }
        }
    }

    @ViewBuilder
    private func tabContainer(library: PoemLibraryStore) -> some View {
        if #available(iOS 26.0, *) {
            modernTabView(library: library)
                .tabViewBottomAccessory {
                    ReadingTabAccessory(
                        poem: session.currentPoem(in: library),
                        queue: session.currentQueue,
                        canMoveNext: session.canMoveInCurrentQueue,
                        onOpenPoem: openCurrentPoem,
                        onMoveNext: moveToNextPoem
                    )
                }
                .tabBarMinimizeBehavior(.onScrollDown)
        } else if #available(iOS 18.0, *) {
            modernTabView(library: library)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    readingFallbackAccessory(library: library)
                }
        } else {
            legacyTabView(library: library)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    readingFallbackAccessory(library: library)
            }
        }
    }

    private func legacyTabView(library: PoemLibraryStore) -> some View {
        TabView(selection: $selectedTab) {
            legacyTabScreen(.home) {
                HomeScreen(
                    library: library,
                    session: session,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection,
                    onOpenAuthor: openAuthor
                )
            }

            legacyTabScreen(.discover) {
                DiscoverScreen(
                    library: library,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection,
                    onStartSearch: startSearch
                )
            }

            legacyTabScreen(.library) {
                LibraryScreen(
                    library: library,
                    session: session,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection
                )
            }

            legacyTabScreen(.profile) {
                ProfileScreen(
                    library: library,
                    session: session,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection
                )
            }

            legacyTabScreen(.search) {
                SearchScreen(
                    library: library,
                    searchText: $tabSearchText,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection,
                    onOpenAuthor: openAuthor,
                    onDismissSearch: dismissSearchTab
                )
            }
        }
    }

    @available(iOS 18.0, *)
    private func modernTabView(library: PoemLibraryStore) -> some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.symbol, value: AppTab.home) {
                tabContent {
                    HomeScreen(
                        library: library,
                        session: session,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection,
                        onOpenAuthor: openAuthor
                    )
                }
            }

            Tab(AppTab.discover.title, systemImage: AppTab.discover.symbol, value: AppTab.discover) {
                tabContent {
                    DiscoverScreen(
                        library: library,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection,
                        onStartSearch: startSearch
                    )
                }
            }

            Tab(AppTab.library.title, systemImage: AppTab.library.symbol, value: AppTab.library) {
                tabContent {
                    LibraryScreen(
                        library: library,
                        session: session,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection
                    )
                }
            }

            Tab(AppTab.profile.title, systemImage: AppTab.profile.symbol, value: AppTab.profile) {
                tabContent {
                    ProfileScreen(
                        library: library,
                        session: session,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection
                    )
                }
            }

            Tab(AppTab.search.title, systemImage: AppTab.search.symbol, value: AppTab.search, role: .search) {
                tabContent {
                    SearchScreen(
                        library: library,
                        searchText: $tabSearchText,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection,
                        onOpenAuthor: openAuthor,
                        onDismissSearch: dismissSearchTab
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func readingFallbackAccessory(library: PoemLibraryStore) -> some View {
        ReadingAccessoryContent(
            poem: session.currentPoem(in: library),
            queue: session.currentQueue,
            isInline: false,
            canMoveNext: session.canMoveInCurrentQueue,
            onOpenPoem: openCurrentPoem,
            onMoveNext: moveToNextPoem
        )
        .background(
            PoemeryTheme.warmPaper.opacity(0.34)
                .background(.ultraThinMaterial)
        )
    }

    private func legacyTabScreen<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        tabContent {
            content()
        }
        .tag(tab)
        .tabItem {
            Label(tab.title, systemImage: tab.symbol)
        }
    }

    private func tabContent<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
    }

    private func openPoem(_ poem: Poem, queue: ReadingQueue) {
        session.startReading(poem, in: queue)
        presentedItem = .poem(poem.id, session.currentQueue ?? queue)
    }

    private func openCurrentPoem() {
        guard case .loaded(let library) = libraryLoadState,
              let poem = session.currentPoem(in: library) else {
            return
        }
        let queue = session.currentQueue ?? .singlePoem(poem)
        presentedItem = .poem(poem.id, queue)
    }

    private func openPoemFromPresentedItem(_ poem: Poem, queue: ReadingQueue) {
        session.startReading(poem, in: queue)
        let nextItem = PresentedLibraryItem.poem(poem.id, queue)
        presentedItem = nil

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            presentedItem = nextItem
        }
    }

    private func moveToNextPoem() {
        guard case .loaded(let library) = libraryLoadState else {
            return
        }
        _ = session.moveToNextPoem(in: library)
    }

    private func openCollection(_ collection: PoemCollection) {
        presentedItem = .collection(collection)
    }

    private func openAuthor(_ author: AuthorResult) {
        presentedItem = .author(author)
    }

    private func startSearch(_ query: String) {
        tabSearchText = query
        selectedTab = .search
    }

    private func dismissSearchTab() {
        selectedTab = lastContentTab
    }

    @ViewBuilder
    private func presentedView(for item: PresentedLibraryItem) -> some View {
        if case .loaded(let library) = libraryLoadState {
            switch item {
            case .poem(let poemID, let queue):
                PoemDetailView(
                    initialPoemID: poemID,
                    queue: queue,
                    library: library,
                    session: session
                )
            case .collection(let collection):
                CollectionDetailView(
                    collection: collection,
                    poems: library.poems(for: collection),
                    onOpenPoem: openPoemFromPresentedItem
                )
            case .author(let author):
                AuthorDetailView(author: author, onOpenPoem: openPoemFromPresentedItem)
            }
        } else {
            EmptyView()
        }
    }

    private func loadLibrary() async {
        if !libraryLoadState.isLoaded {
            libraryLoadState = .loading
        }

        do {
            let library = try await PoemLibraryStore.loadBundled(script: chineseScriptPreference)
            guard !Task.isCancelled else {
                return
            }
            libraryLoadState = .loaded(library)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            libraryLoadState = .failed
        }
    }
}

private enum LibraryLoadState {
    case loading
    case loaded(PoemLibraryStore)
    case failed

    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }
}

private struct LibraryLoadingScreen: View {
    @State private var recommendation = LoadingPoemRecommendation.random()

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 32)

            VStack(alignment: .leading, spacing: 8) {
                Text("诗境")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(PoemeryTheme.primaryText)

                Text("正在整理离线诗库")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 18) {
                Text("今日推荐")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PoemeryTheme.accent)

                VStack(alignment: .leading, spacing: 10) {
                    Text(recommendation.title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(PoemeryTheme.primaryText)

                    Text(recommendation.attribution)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recommendation.lines, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(.title3.weight(.medium))
                .foregroundStyle(PoemeryTheme.deepInk)
                .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.62), lineWidth: 0.6)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text("正在准备书架")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.primaryText)

                HStack(spacing: 14) {
                    LoadingShelfCard(title: "唐诗", color: PoemeryTheme.cinnabar)
                    LoadingShelfCard(title: "宋词", color: PoemeryTheme.moon)
                    LoadingShelfCard(title: "元曲", color: PoemeryTheme.agedPaper)
                }
            }

            HStack(spacing: 10) {
                ProgressView()
                    .tint(PoemeryTheme.accent)

                Text("加载完整诗库中")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
            }

            Spacer(minLength: 32)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(PoemeryTheme.background.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("诗境正在加载完整诗库，今日推荐\(recommendation.title)")
    }
}

private struct LoadingPoemRecommendation {
    let title: String
    let attribution: String
    let lines: [String]

    static func random() -> LoadingPoemRecommendation {
        samples.randomElement() ?? samples[0]
    }

    private static let samples = [
        LoadingPoemRecommendation(
            title: "静夜思",
            attribution: "唐 · 李白",
            lines: ["床前明月光，", "疑是地上霜。", "举头望明月，", "低头思故乡。"]
        ),
        LoadingPoemRecommendation(
            title: "春晓",
            attribution: "唐 · 孟浩然",
            lines: ["春眠不觉晓，", "处处闻啼鸟。", "夜来风雨声，", "花落知多少。"]
        ),
        LoadingPoemRecommendation(
            title: "登鹳雀楼",
            attribution: "唐 · 王之涣",
            lines: ["白日依山尽，", "黄河入海流。", "欲穷千里目，", "更上一层楼。"]
        ),
        LoadingPoemRecommendation(
            title: "相思",
            attribution: "唐 · 王维",
            lines: ["红豆生南国，", "春来发几枝。", "愿君多采撷，", "此物最相思。"]
        )
    ]
}

private struct LoadingShelfCard: View {
    let title: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
        }
        .padding(12)
        .frame(width: 92, height: 116)
        .background(
            LinearGradient(
                colors: [color.opacity(0.88), color.opacity(0.48), PoemeryTheme.deepInk.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityHidden(true)
    }
}

private struct LibraryLoadFailedScreen: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()

            Text("诗库暂时没有加载成功")
                .font(.title2.weight(.bold))
                .foregroundStyle(PoemeryTheme.primaryText)

            Text("请稍后重试。你的收藏和最近阅读记录仍保存在本机。")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)

            Button(action: onRetry) {
                Label("重新加载", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.bold))
            }
            .buttonStyle(.borderedProminent)
            .tint(PoemeryTheme.accent)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(PoemeryTheme.background.ignoresSafeArea())
    }
}

private enum PresentedLibraryItem: Identifiable {
    case poem(Poem.ID, ReadingQueue)
    case collection(PoemCollection)
    case author(AuthorResult)

    var id: String {
        switch self {
        case .poem(let poemID, let queue): "poem-\(queue.id)-\(poemID)"
        case .collection(let collection): "collection-\(collection.id)"
        case .author(let author): "author-\(author.id)"
        }
    }
}

private enum AppTab: String, Identifiable {
    case home
    case discover
    case library
    case profile
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "主页"
        case .discover: "新发现"
        case .library: "资料库"
        case .profile: "我的"
        case .search: "搜索"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .discover: "square.grid.2x2.fill"
        case .library: "books.vertical.fill"
        case .profile: "person.crop.circle.fill"
        case .search: "magnifyingglass"
        }
    }
}

private struct SearchScreen: View {
    private static let searchPageSize = 100
    private static let debounceNanoseconds: UInt64 = 220_000_000

    let library: PoemLibraryStore
    @Binding var searchText: String
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    let onOpenAuthor: (AuthorResult) -> Void
    let onDismissSearch: () -> Void

    @Environment(\.dismissSearch) private var dismissSearch
    @State private var isSearchPresented = true
    @State private var results = SearchResultsPage()
    @State private var isLoadingFirstPage = false
    @State private var isLoadingMore = false
    @State private var searchTask: Task<Void, Never>?

    private var isSearching: Bool {
        !trimmedSearchText.isEmpty
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if isSearching {
                        if isLoadingFirstPage {
                            SearchLoadingState()
                        } else if results.isEmpty {
                            EmptyLibraryState(title: "未找到结果", subtitle: "试试诗名、作者、题材或正文里的字句。")
                        } else {
                            SearchResultsView(
                                results: results,
                                isLoadingMore: isLoadingMore,
                                onOpenPoem: openSearchResult,
                                onOpenCollection: onOpenCollection,
                                onOpenAuthor: onOpenAuthor,
                                onLoadMore: loadMoreResults
                            )
                        }
                    } else {
                        PoemListSection(
                            title: "推荐搜索",
                            poems: library.popularPoems(limit: 6),
                            onOpenPoem: onOpenPoem
                        )
                    }
                }
                .screenContentPadding()
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(dismissSearchDrag)
            .scrollIndicators(.hidden)
            .background(PoemeryTheme.background)
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "诗人、诗词、句子、题材"
            )
            .submitLabel(.search)
            .onAppear {
                isSearchPresented = true
                scheduleSearch(debounced: false)
            }
            .onChange(of: searchText) {
                scheduleSearch(debounced: true)
            }
            .onDisappear {
                searchTask?.cancel()
            }
            .modifier(SearchToolbarBehaviorModifier())
        }
    }

    private var dismissSearchDrag: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                guard value.translation.height > 44,
                      abs(value.translation.height) > abs(value.translation.width)
                else {
                    return
                }

                closeSearch()
            }
    }

    private func closeSearch() {
        isSearchPresented = false
        dismissSearch()
        onDismissSearch()
    }

    private func scheduleSearch(debounced: Bool) {
        searchTask?.cancel()

        let query = trimmedSearchText
        guard !query.isEmpty else {
            results = SearchResultsPage()
            isLoadingFirstPage = false
            isLoadingMore = false
            return
        }

        results = SearchResultsPage()
        isLoadingFirstPage = true
        isLoadingMore = false

        searchTask = Task { @MainActor in
            if debounced {
                try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
                guard !Task.isCancelled else {
                    return
                }
            }

            let page = await library.searchPage(query, limit: Self.searchPageSize)
            guard !Task.isCancelled, query == trimmedSearchText else {
                return
            }

            results = page
            isLoadingFirstPage = false
        }
    }

    private func loadMoreResults() {
        guard let nextOffset = results.nextOffset, !isLoadingMore else {
            return
        }

        searchTask?.cancel()
        let query = trimmedSearchText
        isLoadingMore = true

        searchTask = Task { @MainActor in
            let page = await library.searchPage(
                query,
                offset: nextOffset,
                limit: Self.searchPageSize
            )
            guard !Task.isCancelled, query == trimmedSearchText else {
                return
            }

            results = results.appending(page)
            isLoadingMore = false
        }
    }

    private func openSearchResult(_ item: PoemListItem) {
        guard let poem = library.poem(id: item.id) else {
            return
        }

        onOpenPoem(
            poem,
            ReadingQueue(title: "搜索结果", poemIDs: results.poemIDs)
        )
    }
}

private struct SearchLoadingState: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(PoemeryTheme.accent)

            Text("正在搜索诗库")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupedListBackground()
    }
}

private struct SearchToolbarBehaviorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.searchToolbarBehavior(.minimize)
        } else {
            content
        }
    }
}

@available(iOS 26.0, *)
private struct ReadingTabAccessory: View {
    let poem: Poem?
    let queue: ReadingQueue?
    let canMoveNext: Bool
    let onOpenPoem: () -> Void
    let onMoveNext: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        ReadingAccessoryContent(
            poem: poem,
            queue: queue,
            isInline: placement == .inline,
            canMoveNext: canMoveNext,
            onOpenPoem: onOpenPoem,
            onMoveNext: onMoveNext
        )
        .animation(PoemeryTheme.quickMotion, value: placement)
    }
}

private struct ReadingAccessoryContent: View {
    let poem: Poem?
    let queue: ReadingQueue?
    let isInline: Bool
    let canMoveNext: Bool
    let onOpenPoem: () -> Void
    let onMoveNext: () -> Void

    var body: some View {
        Group {
            if let poem {
                if isInline {
                    compactPoemRow(poem)
                } else {
                    expandedPoemRow(poem)
                }
            } else {
                compactPlaceholder
            }
        }
        .contentShape(Rectangle())
        .animation(PoemeryTheme.quickMotion, value: isInline)
    }

    private func expandedPoemRow(_ poem: Poem) -> some View {
        HStack(spacing: 12) {
            Button(action: onOpenPoem) {
                HStack(spacing: 12) {
                    PoemArtwork(poem: poem, size: 44, cornerRadius: 8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(poem.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(PoemeryTheme.primaryText)
                            .lineLimit(1)

                        Text(subtitle(for: poem))
                            .font(.subheadline)
                            .foregroundStyle(PoemeryTheme.secondaryText)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("当前阅读，\(poem.title)，\(subtitle(for: poem))")

            Spacer(minLength: 12)

            Button(action: onMoveNext) {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(canMoveNext ? PoemeryTheme.primaryText : PoemeryTheme.tertiaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canMoveNext)
            .accessibilityLabel("下一首")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func compactPoemRow(_ poem: Poem) -> some View {
        HStack(spacing: 10) {
            Button(action: onOpenPoem) {
                HStack(spacing: 10) {
                    PoemArtwork(poem: poem, size: 34, cornerRadius: 7)

                    Text(poem.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
            }
            .buttonStyle(.plain)

            Button(action: onMoveNext) {
                Image(systemName: "chevron.right")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(canMoveNext ? PoemeryTheme.primaryText : PoemeryTheme.tertiaryText)
            }
            .buttonStyle(.plain)
            .disabled(!canMoveNext)
            .accessibilityLabel("下一首")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var compactPlaceholder: some View {
        Text("开始阅读")
            .font(.headline.weight(.semibold))
            .foregroundStyle(PoemeryTheme.primaryText)
            .lineLimit(1)
            .accessibilityLabel("开始阅读")
    }

    private func subtitle(for poem: Poem) -> String {
        if let queue {
            return "\(queue.title) · \(poem.displayArtist)"
        }
        return poem.displayArtist
    }
}

#Preview {
    ContentView()
}
