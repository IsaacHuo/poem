import SwiftUI

struct RelatedPoemsSection: View {
    let poems: [Poem]
    let onOpenPoem: (Poem) -> Void

    var body: some View {
        if !poems.isEmpty {
            PoemShelf(title: "相关诗词", poems: poems, onOpenPoem: onOpenPoem)
        }
    }
}
