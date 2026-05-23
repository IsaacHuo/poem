import SwiftUI

struct ContentView: View {
    @State private var library = PoemLibraryStore()
    @State private var session = ReadingSessionStore()
    @State private var selectedTab: AppTab = .home
    @State private var presentedPoem: Poem?
    @State private var nowReadingPoem: Poem?
    @State private var searchText = ""
    @Namespace private var glassNamespace

    var body: some View {
        tabContainer
            .tint(PoemeryTheme.accent)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .background(PoemeryTheme.background.ignoresSafeArea())
            .onAppear {
                session.configureIfNeeded(with: library)
            }
            .sheet(item: $presentedPoem) { poem in
                PoemDetailView(
                    poem: poem,
                    library: library,
                    session: session,
                    onStartReading: { startReading($0) }
                )
            }
            .sheet(item: $nowReadingPoem) { poem in
                NowReadingView(
                    poem: poem,
                    library: library,
                    session: session
                )
            }
            .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var tabContainer: some View {
        if #available(iOS 18.0, *) {
            modernTabView
        } else {
            legacyTabView
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
                    session: session,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection
                )
            }

            legacyTabScreen(.radio) {
                RadioScreen(
                    library: library,
                    session: session,
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

            legacyTabScreen(.search) {
                SearchScreen(
                    library: library,
                    session: session,
                    searchText: $searchText,
                    onOpenPoem: openPoem,
                    onOpenCollection: openCollection
                )
            }
        }
    }

    @available(iOS 18.0, *)
    @ViewBuilder
    private var modernTabView: some View {
        if #available(iOS 26.0, *) {
            modernTabViewContent
                .tabViewSearchActivation(.searchTabSelection)
        } else {
            modernTabViewContent
        }
    }

    @available(iOS 18.0, *)
    private var modernTabViewContent: some View {
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
                        session: session,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection
                    )
                }
            }

            Tab(AppTab.radio.title, systemImage: AppTab.radio.symbol, value: AppTab.radio) {
                tabContent {
                    RadioScreen(
                        library: library,
                        session: session,
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

            Tab(AppTab.search.title, systemImage: AppTab.search.symbol, value: AppTab.search, role: .search) {
                tabContent {
                    SearchScreen(
                        library: library,
                        session: session,
                        searchText: $searchText,
                        onOpenPoem: openPoem,
                        onOpenCollection: openCollection
                    )
                }
            }
        }
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
            .safeAreaInset(edge: .bottom, spacing: 8) {
                miniReadingInset
            }
    }

    @ViewBuilder
    private var miniReadingInset: some View {
        if let poem = session.currentPoem(in: library) {
            MiniReadingBar(
                poem: poem,
                namespace: glassNamespace,
                onOpen: { nowReadingPoem = poem },
                onContinue: { continueReading(poem) },
                onNext: { session.playNext(in: library) }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func openPoem(_ poem: Poem) {
        presentedPoem = poem
    }

    private func openCollection(_ collection: PoemCollection) {
        guard let poem = library.poems(for: collection).first else { return }
        session.startReading(poem, queue: library.poems(for: collection))
        presentedPoem = poem
    }

    private func startReading(_ poem: Poem) {
        session.startReading(poem, queue: library.poems)
        nowReadingPoem = poem
    }

    private func continueReading(_ poem: Poem) {
        session.continueReading(library)
        nowReadingPoem = poem
    }
}

private enum AppTab: String, Identifiable {
    case home
    case discover
    case radio
    case library
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "主页"
        case .discover: "新发现"
        case .radio: "广播"
        case .library: "资料库"
        case .search: "搜索"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .discover: "square.grid.2x2.fill"
        case .radio: "dot.radiowaves.left.and.right"
        case .library: "books.vertical.fill"
        case .search: "magnifyingglass"
        }
    }
}

#Preview {
    ContentView()
}
