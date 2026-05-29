import SwiftUI

struct ContentView: View {
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
            .task {
                await loadLibraryIfNeeded()
            }
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
                    await loadLibraryIfNeeded()
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
        .background(.ultraThinMaterial)
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
                    onOpenPoem: openPoem
                )
            case .author(let author):
                AuthorDetailView(author: author, onOpenPoem: openPoem)
            }
        } else {
            EmptyView()
        }
    }

    private func loadLibraryIfNeeded() async {
        guard case .loading = libraryLoadState else {
            return
        }

        do {
            let library = try await PoemLibraryStore.loadBundled()
            libraryLoadState = .loaded(library)
        } catch {
            libraryLoadState = .failed
        }
    }
}

private enum LibraryLoadState {
    case loading
    case loaded(PoemLibraryStore)
    case failed
}

private struct LibraryLoadingScreen: View {
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
                    Text("静夜思")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(PoemeryTheme.primaryText)

                    Text("唐 · 李白")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("床前明月光，")
                    Text("疑是地上霜。")
                    Text("举头望明月，")
                    Text("低头思故乡。")
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
        .accessibilityLabel("诗境正在加载完整诗库，今日推荐静夜思")
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
    let library: PoemLibraryStore
    @Binding var searchText: String
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    let onOpenAuthor: (AuthorResult) -> Void
    let onDismissSearch: () -> Void

    @Environment(\.dismissSearch) private var dismissSearch
    @State private var isSearchPresented = true

    private var results: SearchResults {
        library.search(searchText)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if isSearching {
                        if results.isEmpty {
                            EmptyLibraryState(title: "未找到结果", subtitle: "试试诗名、作者、题材或正文里的字句。")
                        } else {
                            SearchResultsView(
                                results: results,
                                onOpenPoem: onOpenPoem,
                                onOpenCollection: onOpenCollection,
                                onOpenAuthor: onOpenAuthor
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
            } else if isInline {
                compactPlaceholder
            } else {
                expandedPlaceholder
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
                Image(systemName: "forward.fill")
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
                Image(systemName: "forward.fill")
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

    private var expandedPlaceholder: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("打开一首诗")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.primaryText)

                Text("当前阅读会显示在这里")
                    .font(.subheadline)
                    .foregroundStyle(PoemeryTheme.secondaryText)
            }

            Spacer(minLength: 12)

            Image(systemName: "sparkles")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PoemeryTheme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("打开一首诗，当前阅读会显示在这里")
    }

    private var compactPlaceholder: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.book.closed.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.accent)

            Text("开始阅读")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
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
