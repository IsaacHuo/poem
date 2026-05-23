import SwiftUI

struct FeaturedCarousel: View {
    let title: String
    let collections: [PoemCollection]
    let library: PoemLibraryStore
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title, showsChevron: true)

            GeometryReader { proxy in
                let cardSize = cardSize(for: proxy.size.width)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 18) {
                        ForEach(collections) { collection in
                            Button {
                                onOpenCollection(collection)
                            } label: {
                                FeaturedCollectionCard(
                                    collection: collection,
                                    poems: library.poems(for: collection),
                                    size: cardSize
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
            }
            .frame(height: carouselHeight)
        }
    }

    private var carouselHeight: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            420
        } else {
            360
        }
    }

    private func cardSize(for availableWidth: CGFloat) -> CGSize {
        let width: CGFloat
        if UIDevice.current.userInterfaceIdiom == .pad {
            width = min(availableWidth * 0.58, 380)
        } else {
            width = min(max(availableWidth * 0.82, 280), 340)
        }
        return CGSize(width: width, height: width * 1.08)
    }
}
