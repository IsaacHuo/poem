import SwiftUI

struct ContentView: View {
    @State private var library = PoemLibraryStore()
    @State private var session = ReadingSessionStore()
    @State private var selectedTab: AppTab = .home
    @State private var lastContentTab: AppTab = .home
    @State private var presentedItem: PresentedLibraryItem?
    @State private var discoverSearchText = ""
    @State private var tabSearchText = ""

    var body: some View {
        tabContainer
            .tint(PoemeryTheme.accent)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .background(PoemeryTheme.background.ignoresSafeArea())
            .sheet(item: $presentedItem) { item in
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
                }
            }
            .preferredColorScheme(.light)
            .onChange(of: selectedTab) { _, newTab in
                if newTab != .search {
                    lastContentTab = newTab
                }
            }
    }

    @ViewBuilder
    private var tabContainer: some View {
        if #available(iOS 26.0, *) {
            modernTabView
                .tabViewBottomAccessory {
                    ReadingTabAccessory(
                        poem: session.currentPoem(in: library),
                        queue: session.currentQueue,
                        canMoveNext: session.canMoveInCurrentQueue,
                        onOpenPoem: openCurrentPoem,
                        onMoveNext: moveToNextPoem
                    )
                }
                .tabViewSearchActivation(.searchTabSelection)
                .tabBarMinimizeBehavior(.onScrollDown)
        } else if #available(iOS 18.0, *) {
            modernTabView
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    readingFallbackAccessory
                }
        } else {
            legacyTabView
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    readingFallbackAccessory
                }
        }
    }

    private var legacyTabView: some View {
        TabView(selection: $selectedTab) {
            legacyTabScreen(.home) {
                HomeScreen(
                    library: library,
                    session: session,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection
                )
            }

            legacyTabScreen(.discover) {
                DiscoverScreen(
                    library: library,
                    searchText: $discoverSearchText,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection
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
                    onDismissSearch: dismissSearchTab
                )
            }
        }
    }

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(AppTab.home.title, systemImage: AppTab.home.symbol, value: AppTab.home) {
                tabContent {
                    HomeScreen(
                        library: library,
                        session: session,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection
                    )
                }
            }

            Tab(AppTab.discover.title, systemImage: AppTab.discover.symbol, value: AppTab.discover) {
                tabContent {
                    DiscoverScreen(
                        library: library,
                        searchText: $discoverSearchText,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection
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
                        onDismissSearch: dismissSearchTab
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var readingFallbackAccessory: some View {
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
        guard let poem = session.currentPoem(in: library) else {
            return
        }
        let queue = session.currentQueue ?? .singlePoem(poem)
        presentedItem = .poem(poem.id, queue)
    }

    private func moveToNextPoem() {
        _ = session.moveToNextPoem(in: library)
    }

    private func openCollection(_ collection: PoemCollection) {
        presentedItem = .collection(collection)
    }

    private func dismissSearchTab() {
        selectedTab = lastContentTab
    }
}

private enum PresentedLibraryItem: Identifiable {
    case poem(Poem.ID, ReadingQueue)
    case collection(PoemCollection)

    var id: String {
        switch self {
        case .poem(let poemID, let queue): "poem-\(queue.id)-\(poemID)"
        case .collection(let collection): "collection-\(collection.id)"
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
                                onOpenCollection: onOpenCollection
                            )
                        }
                    } else {
                        PoemListSection(
                            title: "推荐搜索",
                            poems: Array(library.poems.prefix(6)),
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
