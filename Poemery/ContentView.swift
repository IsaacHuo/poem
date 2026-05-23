import SwiftUI

struct ContentView: View {
    @State private var library = PoemLibraryStore()
    @State private var session = ReadingSessionStore()
    @State private var selectedTab: AppTab = .home
    @State private var presentedItem: PresentedLibraryItem?
    @State private var searchText = ""

    var body: some View {
        tabContainer
            .tint(PoemeryTheme.accent)
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .background(PoemeryTheme.background.ignoresSafeArea())
            .sheet(item: $presentedItem) { item in
                switch item {
                case .poem(let poem):
                    PoemDetailView(
                        poem: poem,
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
                    searchText: $searchText,
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
                        searchText: $searchText,
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
    }

    private func openPoem(_ poem: Poem) {
        session.markRecent(poem)
        presentedItem = .poem(poem)
    }

    private func openCollection(_ collection: PoemCollection) {
        presentedItem = .collection(collection)
    }
}

private enum PresentedLibraryItem: Identifiable {
    case poem(Poem)
    case collection(PoemCollection)

    var id: String {
        switch self {
        case .poem(let poem): "poem-\(poem.id)"
        case .collection(let collection): "collection-\(collection.id)"
        }
    }
}

private enum AppTab: String, Identifiable {
    case home
    case discover
    case library
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "主页"
        case .discover: "新发现"
        case .library: "资料库"
        case .profile: "我的"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .discover: "square.grid.2x2.fill"
        case .library: "books.vertical.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

#Preview {
    ContentView()
}
