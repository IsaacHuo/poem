import SwiftUI

struct FeaturedCarousel: View {
    let title: String
    let collections: [PoemCollection]
    let library: PoemLibraryStore
    var layout: FeaturedCarouselLayout = .standard
    let onOpenCollection: (PoemCollection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: title)

            GeometryReader { proxy in
                let cardSize = cardSize(for: proxy.size.width)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: layout.cardSpacing) {
                        ForEach(collections) { collection in
                            Button {
                                onOpenCollection(collection)
                            } label: {
                                FeaturedCollectionCard(
                                    collection: collection,
                                    size: cardSize
                                )
                            }
                            .buttonStyle(.plain)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.96)
                                    .opacity(phase.isIdentity ? 1 : 0.86)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollClipDisabled()
                .padding(.horizontal, -16)
            }
            .frame(height: carouselHeight)
        }
    }

    private var carouselHeight: CGFloat {
        if layout == .narrowPortrait {
            UIDevice.current.userInterfaceIdiom == .pad ? 372 : 310
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            420
        } else {
            360
        }
    }

    private func cardSize(for availableWidth: CGFloat) -> CGSize {
        let width: CGFloat
        if layout == .narrowPortrait {
            if UIDevice.current.userInterfaceIdiom == .pad {
                width = min(max(availableWidth * 0.42, 260), 320)
                return CGSize(width: width, height: 372)
            } else {
                width = min(max(availableWidth * 0.58, 208), 248)
                return CGSize(width: width, height: 310)
            }
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            width = min(availableWidth * 0.58, 380)
        } else {
            width = min(max(availableWidth * 0.82, 280), 340)
        }
        return CGSize(width: width, height: width * 1.08)
    }
}

enum FeaturedCarouselLayout {
    case standard
    case narrowPortrait

    var cardSpacing: CGFloat {
        switch self {
        case .standard: 18
        case .narrowPortrait: 14
        }
    }
}
