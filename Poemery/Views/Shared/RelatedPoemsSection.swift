import SwiftUI

struct RelatedPoemsSection: View {
    let poems: [Poem]
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    var body: some View {
        if !poems.isEmpty {
            PoemShelf(title: "相关诗词", poems: poems, onOpenPoem: onOpenPoem)
        }
    }
}
