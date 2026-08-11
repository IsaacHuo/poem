import SwiftUI
import UIKit

struct ContentView: View {
    @AppStorage(ChineseScriptPreference.storageKey) private var chineseScriptRawValue = ChineseScriptPreference.simplified.rawValue
    @State private var libraryLoadState: LibraryLoadState = .loading(PoemLibraryStore.bootstrap())
    @State private var session = ReadingSessionStore()
    @State private var selectedTab: AppTab = .home
    @State private var lastContentTab: AppTab = .home
    @State private var presentedItem: PresentedLibraryItem?
    @State private var presentedPoem: PresentedPoem?
    @State private var tabSearchText = ""

    var body: some View {
        content
            .environment(\.chineseScriptPreference, chineseScriptPreference)
            .tint(PoemeryTheme.accent)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .background(PoemeryTheme.background.ignoresSafeArea())
            .sheet(item: $presentedItem) { item in
                presentedView(for: item)
            }
            .fullScreenCover(item: $presentedPoem) { item in
                presentedPoemView(for: item)
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab != .search {
                    lastContentTab = newTab
                }
            }
            .task(id: chineseScriptRawValue) {
                await loadLibrary()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                libraryLoadState.library?.handleMemoryWarning(keeping: presentedPoem?.poemID)
            }
    }

    private var chineseScriptPreference: ChineseScriptPreference {
        ChineseScriptPreference(rawValue: chineseScriptRawValue)
    }

    @ViewBuilder
    private var content: some View {
        if let library = libraryLoadState.library {
            tabContainer(library: library)
                .overlay(alignment: .top) {
                    switch libraryLoadState {
                    case .loading:
                        LibraryLoadStatusBanner(status: .loading)
                    case .failed:
                        LibraryLoadStatusBanner(status: .failed) {
                            Task { await loadLibrary() }
                        }
                    case .loaded:
                        EmptyView()
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
        } else {
            legacyTabView(library: library)
        }
    }

    private func legacyTabView(library: PoemLibraryStore) -> some View {
        TabView(selection: $selectedTab) {
            legacyTabScreen(.home, library: library) {
                HomeScreen(
                    library: library,
                    session: session,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection
                )
            }

            legacyTabScreen(.discover, library: library) {
                DiscoverScreen(
                    library: library,
                    session: session,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection,
                    onStartSearch: startSearch
                )
            }

            legacyTabScreen(.library, library: library) {
                LibraryScreen(
                    library: library,
                    session: session,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection,
                    onRefresh: { await refreshLibrary(library) }
                )
            }

            legacyTabScreen(.profile, library: library) {
                ProfileScreen(
                    library: library,
                    session: session,
                    onOpenPoem: openPoem
                )
            }

            legacyTabScreen(.search, library: library) {
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
            Tab(chineseScriptPreference.converted(AppTab.home.title), systemImage: AppTab.home.symbol, value: AppTab.home) {
                tabContent(library: library) {
                    HomeScreen(
                        library: library,
                        session: session,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection
                    )
                }
            }

            Tab(chineseScriptPreference.converted(AppTab.discover.title), systemImage: AppTab.discover.symbol, value: AppTab.discover) {
                tabContent(library: library) {
                    DiscoverScreen(
                        library: library,
                        session: session,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection,
                        onStartSearch: startSearch
                    )
                }
            }

            Tab(chineseScriptPreference.converted(AppTab.library.title), systemImage: AppTab.library.symbol, value: AppTab.library) {
                tabContent(library: library) {
                    LibraryScreen(
                        library: library,
                        session: session,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection,
                        onRefresh: { await refreshLibrary(library) }
                    )
                }
            }

            Tab(chineseScriptPreference.converted(AppTab.profile.title), systemImage: AppTab.profile.symbol, value: AppTab.profile) {
                tabContent(library: library) {
                    ProfileScreen(
                        library: library,
                        session: session,
                        onOpenPoem: openPoem
                    )
                }
            }

            Tab(chineseScriptPreference.converted(AppTab.search.title), systemImage: AppTab.search.symbol, value: AppTab.search, role: .search) {
                tabContent(library: library) {
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
        library: PoemLibraryStore,
        @ViewBuilder content: () -> Content
    ) -> some View {
        tabContent(library: library) {
            content()
        }
        .tag(tab)
        .tabItem {
            Label(chineseScriptPreference.converted(tab.title), systemImage: tab.symbol)
        }
    }

    @ViewBuilder
    private func tabContent<Content: View>(
        library: PoemLibraryStore,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 26.0, *) {
            content()
        } else {
            content()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    readingFallbackAccessory(library: library)
                }
        }
    }

    private func openPoem(_ poem: Poem, queue: ReadingQueue) {
        libraryLoadState.library?.remember(poem)
        session.startReading(poem, in: queue)
        presentedPoem = PresentedPoem(poemID: poem.id, queue: session.currentQueue ?? queue)
    }

    private func openCurrentPoem() {
        guard let library = libraryLoadState.library,
              let poem = session.currentPoem(in: library) else {
            return
        }
        let queue = session.currentQueue ?? .singlePoem(poem)
        presentedPoem = PresentedPoem(poemID: poem.id, queue: queue)
    }

    private func openPoemFromPresentedItem(_ poem: Poem, queue: ReadingQueue) {
        session.startReading(poem, in: queue)
        let nextPoem = PresentedPoem(poemID: poem.id, queue: queue)
        presentedItem = nil

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            presentedPoem = nextPoem
        }
    }

    private func moveToNextPoem() {
        guard let library = libraryLoadState.library else {
            return
        }
        _ = session.moveToNextPoem(in: library)
    }

    private func openCollection(_ collection: PoemCollection) {
        presentedItem = .collection(collection.id)
    }

    private func openAuthor(_ author: AuthorResult) {
        presentedItem = .author(author.id)
    }

    private func startSearch(_ query: String) {
        tabSearchText = query
        selectedTab = .search
    }

    private func dismissSearchTab() {
        selectedTab = lastContentTab
    }

    @ViewBuilder
    private func presentedPoemView(for item: PresentedPoem) -> some View {
        if let library = libraryLoadState.library {
            PoemDetailView(
                initialPoemID: item.poemID,
                queue: item.queue,
                library: library,
                session: session
            )
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func presentedView(for item: PresentedLibraryItem) -> some View {
        if let library = libraryLoadState.library {
            switch item {
            case .collection(let collectionID):
                if let collection = library.collection(id: collectionID) {
                    CollectionDetailView(
                        collection: collection,
                        library: library,
                        onOpenPoem: openPoemFromPresentedItem
                    )
                } else {
                    EmptyLibraryState(
                        title: chineseScriptPreference.converted("未找到诗单"),
                        subtitle: chineseScriptPreference.converted("这个诗单条目已经不可用。")
                    )
                }
            case .author(let authorID):
                if let author = library.author(id: authorID) {
                    AuthorDetailView(author: author, library: library, onOpenPoem: openPoemFromPresentedItem)
                } else {
                    EmptyLibraryState(
                        title: chineseScriptPreference.converted("未找到作者"),
                        subtitle: chineseScriptPreference.converted("这个作者条目已经不可用。")
                    )
                }
            }
        } else {
            EmptyView()
        }
    }

    private func loadLibrary() async {
        guard let library = libraryLoadState.library else { return }
        libraryLoadState = .loading(library)

        do {
            try await library.prepare(script: chineseScriptPreference)
            guard !Task.isCancelled else {
                return
            }
            libraryLoadState = .loaded(library)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            libraryLoadState = .failed(library)
        }
    }

    private func refreshLibrary(_ library: PoemLibraryStore) async {
        await loadLibrary()
    }
}

private enum LibraryLoadState {
    case loading(PoemLibraryStore)
    case loaded(PoemLibraryStore)
    case failed(PoemLibraryStore)

    var library: PoemLibraryStore? {
        switch self {
        case .loading(let library), .loaded(let library), .failed(let library):
            return library
        }
    }
}

private struct LibraryLoadStatusBanner: View {
    enum Status: Equatable {
        case loading
        case failed
    }

    let status: Status
    var onRetry: (() -> Void)? = nil

    @Environment(\.chineseScriptPreference) private var script

    var body: some View {
        HStack(spacing: 10) {
            if status == .loading {
                ProgressView()
                    .controlSize(.small)
                    .tint(PoemeryTheme.accent)
            } else {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(PoemeryTheme.accent)
            }

            Text(script.converted(status == .loading ? "完整诗库正在后台载入，可先开始阅读" : "完整诗库载入失败，当前仍可阅读精选内容"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
                .lineLimit(2)

            Spacer(minLength: 4)

            if let onRetry {
                Button(script.converted("重试"), action: onRetry)
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.45)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct LibraryLoadingScreen: View {
    @Environment(\.chineseScriptPreference) private var script
    @State private var recommendation = LoadingPoemRecommendation.random()

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Spacer(minLength: 32)

            VStack(alignment: .leading, spacing: 8) {
                Text(script.converted("诗境"))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(PoemeryTheme.primaryText)

                Text(script.converted("正在连接诗库"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 18) {
                Text(script.converted("今日推荐"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PoemeryTheme.accent)

                VStack(alignment: .leading, spacing: 10) {
                    Text(script.converted(recommendation.title))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(PoemeryTheme.primaryText)

                    Text(script.converted(recommendation.attribution))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recommendation.lines, id: \.self) { line in
                        Text(script.converted(line))
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
                Text(script.converted("正在准备书架"))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.primaryText)

                HStack(spacing: 14) {
                    LoadingShelfCard(title: script.converted("唐诗"), color: PoemeryTheme.cinnabar)
                    LoadingShelfCard(title: script.converted("宋词"), color: PoemeryTheme.moon)
                    LoadingShelfCard(title: script.converted("元曲"), color: PoemeryTheme.agedPaper)
                }
            }

            HStack(spacing: 10) {
                ProgressView()
                    .tint(PoemeryTheme.accent)

                Text(script.converted("加载本地诗库中"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
            }

            Spacer(minLength: 32)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(PoemeryTheme.background.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(script.converted("诗境正在加载本地诗库，今日推荐\(recommendation.title)"))
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
    @Environment(\.chineseScriptPreference) private var script

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()

            Text(script.converted("诗库暂时没有加载成功"))
                .font(.title2.weight(.bold))
                .foregroundStyle(PoemeryTheme.primaryText)

            Text(script.converted("请稍后重试。你的收藏和最近阅读记录仍保存在本机。"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)

            Button(action: onRetry) {
                Label(script.converted("重新加载"), systemImage: "arrow.clockwise")
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

private struct PresentedPoem: Identifiable {
    let poemID: Poem.ID
    let queue: ReadingQueue

    var id: String {
        "poem-\(queue.id)-\(poemID)"
    }
}

private enum PresentedLibraryItem: Identifiable {
    case collection(PoemCollection.ID)
    case author(AuthorResult.ID)

    var id: String {
        switch self {
        case .collection(let collectionID): "collection-\(collectionID)"
        case .author(let authorID): "author-\(authorID)"
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
        case .discover: "发现"
        case .library: "资料库"
        case .profile: "我的"
        case .search: "搜索"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .discover: "sparkles"
        case .library: "books.vertical.fill"
        case .profile: "person.crop.circle.fill"
        case .search: "magnifyingglass"
        }
    }
}

private struct SearchScreen: View {
    private static let searchPageSize = 50
    private static let debounceNanoseconds: UInt64 = 250_000_000

    let library: PoemLibraryStore
    @Binding var searchText: String
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    let onOpenAuthor: (AuthorResult) -> Void
    let onDismissSearch: () -> Void

    @Environment(\.chineseScriptPreference) private var script
    @Environment(\.dismissSearch) private var dismissSearch
    @State private var isSearchPresented = false
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
                            EmptyLibraryState(
                                title: script.converted("未找到结果"),
                                subtitle: script.converted("试试诗名、作者、题材或正文里的字句。")
                            )
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
                            title: script.converted("推荐搜索"),
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
            .navigationTitle(script.converted("搜索"))
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchText,
                isPresented: $isSearchPresented,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(script.converted("诗人、诗词、句子、题材"))
            )
            .submitLabel(.search)
            .onAppear {
                scheduleSearch(debounced: false)
            }
            .onChange(of: searchText) {
                scheduleSearch(debounced: true)
            }
            .onChange(of: script) {
                scheduleSearch(debounced: false)
            }
            .onDisappear {
                searchTask?.cancel()
                library.cancelSearch()
                isSearchPresented = false
                dismissSearch()
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
        library.cancelSearch()

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

            let page = await library.searchPage(query, limit: Self.searchPageSize, script: script)
            guard !Task.isCancelled, query == trimmedSearchText else {
                return
            }

            results = page
            isLoadingFirstPage = false
        }
    }

    private func loadMoreResults() {
        guard let nextCursor = results.nextCursor, !isLoadingMore else {
            return
        }

        searchTask?.cancel()
        library.cancelSearch()
        let query = trimmedSearchText
        isLoadingMore = true

        searchTask = Task { @MainActor in
            let page = await library.searchPage(
                query,
                cursor: nextCursor,
                limit: Self.searchPageSize,
                script: script
            )
            guard !Task.isCancelled, query == trimmedSearchText else {
                return
            }

            results = results.appending(page)
            isLoadingMore = false
        }
    }

    private func openSearchResult(_ item: PoemListItem) {
        Task { @MainActor in
            let poems = await library.loadSummaries(ids: [item.id], script: script)
            guard let poem = poems.first else { return }
            onOpenPoem(
                poem,
                ReadingQueue(title: "搜索结果", poemIDs: results.poemIDs)
            )
        }
    }
}

private struct SearchLoadingState: View {
    @Environment(\.chineseScriptPreference) private var script

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(PoemeryTheme.accent)

            Text(script.converted("正在搜索诗库"))
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

    @Environment(\.chineseScriptPreference) private var script

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
            .accessibilityLabel(script.converted("当前阅读，\(poem.title)，\(subtitle(for: poem))"))

            Spacer(minLength: 12)

            Button(action: onMoveNext) {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(canMoveNext ? PoemeryTheme.primaryText : PoemeryTheme.tertiaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canMoveNext)
            .accessibilityLabel(script.converted("下一首"))
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
            .accessibilityLabel(script.converted("下一首"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var compactPlaceholder: some View {
        Text(script.converted("开始阅读"))
            .font(.headline.weight(.semibold))
            .foregroundStyle(PoemeryTheme.primaryText)
            .lineLimit(1)
            .accessibilityLabel(script.converted("开始阅读"))
    }

    private func subtitle(for poem: Poem) -> String {
        if let queue {
            return "\(script.converted(queue.title)) · \(poem.displayArtist)"
        }
        return poem.displayArtist
    }
}

#Preview {
    ContentView()
}
