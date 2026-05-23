import SwiftUI

struct PoemListSection: View {
    let title: String
    let poems: [Poem]
    var emptyTitle: String = ""
    var emptySubtitle: String = ""
    var queueTitle: String?
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title, showsChevron: !poems.isEmpty)

            if poems.isEmpty {
                EmptyLibraryState(title: emptyTitle, subtitle: emptySubtitle)
            } else {
                VStack(spacing: 0) {
                    ForEach(poems) { poem in
                        Button {
                            onOpenPoem(poem, ReadingQueue(title: queueTitle ?? title, poems: poems))
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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.58), lineWidth: 0.6)
                }
            }
        }
    }
}
