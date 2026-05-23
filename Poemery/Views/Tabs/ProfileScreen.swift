import SwiftUI

struct ProfileScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    private var favoritePoems: [Poem] {
        session.favoritePoems(in: library)
    }

    private var recentPoems: [Poem] {
        session.recentPoems(in: library)
    }

    private var topAuthors: [String] {
        topValues(from: recentPoems.map(\.author), limit: 3)
    }

    private var topForms: [String] {
        topValues(from: recentPoems.map(\.form), limit: 3)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(title: "我的", subtitle: "本地阅读档案")

                metricGrid
                readingTaste

                PoemListSection(
                    title: "收藏",
                    poems: Array(favoritePoems.prefix(8)),
                    emptyTitle: "还没有收藏",
                    emptySubtitle: "打开作品详情后可以把喜欢的诗词加入收藏。",
                    onOpenPoem: onOpenPoem
                )

                PoemListSection(
                    title: "最近阅读",
                    poems: Array(recentPoems.prefix(8)),
                    emptyTitle: "还没有最近阅读",
                    emptySubtitle: "打开任意作品详情后会出现在这里。",
                    onOpenPoem: onOpenPoem
                )

                CollectionListSection(
                    title: "常用诗单",
                    collections: Array(library.collections.prefix(4)),
                    library: library,
                    onOpenCollection: onOpenCollection
                )
            }
            .screenContentPadding()
        }
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private var metricGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ProfileMetricCard(symbol: "heart.fill", title: "收藏", value: "\(favoritePoems.count)")
            ProfileMetricCard(symbol: "clock.fill", title: "最近阅读", value: "\(recentPoems.count)")
            ProfileMetricCard(symbol: "text.book.closed.fill", title: "诗库", value: "\(library.poems.count)")
            ProfileMetricCard(symbol: "person.2.fill", title: "作者", value: "\(library.authors().count)")
        }
    }

    private var readingTaste: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "阅读偏好", showsChevron: false)

            VStack(alignment: .leading, spacing: 12) {
                PreferenceRow(title: "常读作者", values: topAuthors)
                Divider()
                PreferenceRow(title: "常读体裁", values: topForms)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 0.6)
            }
        }
    }

    private func topValues(from values: [String], limit: Int) -> [String] {
        Dictionary(grouping: values, by: { $0 })
            .map { value, matches in (value, matches.count) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    lhs.0.localizedCompare(rhs.0) == .orderedAscending
                } else {
                    lhs.1 > rhs.1
                }
            }
            .prefix(limit)
            .map(\.0)
    }
}

private struct ProfileMetricCard: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PoemeryTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PreferenceRow: View {
    let title: String
    let values: [String]

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(PoemeryTheme.primaryText)

            Spacer(minLength: 16)

            Text(displayValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var displayValue: String {
        values.isEmpty ? "暂无记录" : values.joined(separator: " · ")
    }
}
