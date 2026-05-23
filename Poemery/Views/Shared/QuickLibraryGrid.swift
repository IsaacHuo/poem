import SwiftUI

struct QuickLibraryGrid: View {
    let favoritesCount: Int
    let recentsCount: Int
    let authorsCount: Int
    let collectionsCount: Int

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            LibraryMetricCard(symbol: "heart.fill", title: "收藏", value: "\(favoritesCount)")
            LibraryMetricCard(symbol: "clock.fill", title: "最近阅读", value: "\(recentsCount)")
            LibraryMetricCard(symbol: "person.2.fill", title: "作者", value: "\(authorsCount)")
            LibraryMetricCard(symbol: "rectangle.stack.fill", title: "诗单", value: "\(collectionsCount)")
        }
    }
}
