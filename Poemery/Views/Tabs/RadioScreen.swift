import SwiftUI

struct RadioScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                ScreenHeader(title: "广播", subtitle: "为不同心境连续诵读")

                VStack(spacing: 16) {
                    ForEach(radioCollections) { collection in
                        Button {
                            onOpenCollection(collection)
                        } label: {
                            RadioRow(collection: collection, poems: library.poems(for: collection))
                        }
                        .buttonStyle(.plain)
                    }
                }

                PoemListSection(
                    title: "夜读精选",
                    poems: Array(library.poems.reversed().prefix(5)),
                    onOpenPoem: onOpenPoem
                )
            }
            .screenContentPadding()
        }
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private var radioCollections: [PoemCollection] {
        let radios = library.collections.filter { $0.kind == .radio }
        return radios.isEmpty ? library.collections : radios + library.collections.filter { $0.kind != .radio }.prefix(2)
    }
}
