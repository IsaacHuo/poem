import SwiftUI

struct FeaturedCarousel: View {
    let title: String
    let collections: [PoemCollection]
    let library: PoemLibraryStore
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title, showsChevron: true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(collections) { collection in
                        Button {
                            onOpenCollection(collection)
                        } label: {
                            FeaturedCollectionCard(collection: collection, poems: library.poems(for: collection))
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
