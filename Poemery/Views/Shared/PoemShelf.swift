import SwiftUI

struct PoemShelf: View {
    let title: String
    let poems: [Poem]
    var emptyTitle: String = ""
    var emptySubtitle: String = ""
    let onOpenPoem: (Poem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title, showsChevron: !poems.isEmpty)

            if poems.isEmpty {
                EmptyLibraryState(title: emptyTitle, subtitle: emptySubtitle)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 18) {
                        ForEach(poems) { poem in
                            Button {
                                onOpenPoem(poem)
                            } label: {
                                CompactPoemCard(poem: poem)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
        }
    }
}
