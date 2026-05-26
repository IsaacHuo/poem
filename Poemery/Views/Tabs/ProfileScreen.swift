import SwiftUI

struct ProfileScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
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
                ScreenHeader(title: "我的", subtitle: "账号、会员与阅读资产")

                accountSummary
                membershipCard
                accountServices
                readingTaste
                readingAssets
            }
            .screenContentPadding()
        }
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private var accountSummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    PoemeryTheme.accent.opacity(0.95),
                                    PoemeryTheme.moon.opacity(0.86)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: "person.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text("诗笺用户")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PoemeryTheme.primaryText)

                    Text("本机资料 · 普通用户")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.secondaryText)
                }

                Spacer(minLength: 12)

                Text("普通用户")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PoemeryTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PoemeryTheme.accent.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 10) {
                AccountMetricCard(symbol: "heart.fill", title: "收藏", value: "\(favoritePoems.count)")
                AccountMetricCard(symbol: "clock.fill", title: "最近", value: "\(recentPoems.count)")
                AccountMetricCard(symbol: "rectangle.stack.fill", title: "诗单", value: "\(library.collections.count)")
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.58), lineWidth: 0.6)
        }
    }

    private var membershipCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "会员", showsChevron: false)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PoemeryTheme.accent)
                        .frame(width: 42, height: 42)
                        .background(PoemeryTheme.accent.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("普通用户")
                            .font(.headline)
                            .foregroundStyle(PoemeryTheme.primaryText)

                        Text("会员中心已预留")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PoemeryTheme.secondaryText)
                    }

                    Spacer(minLength: 12)

                    Text("即将开放")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PoemeryTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(PoemeryTheme.surface, in: Capsule())
                }

                HStack(spacing: 8) {
                    MembershipPill(title: "专属内容")
                    MembershipPill(title: "高级同步")
                    MembershipPill(title: "个性推荐")
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 0.6)
            }
        }
    }

    private var accountServices: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "账户服务", showsChevron: false)

            VStack(spacing: 0) {
                AccountServiceRow(symbol: "person.crop.circle", title: "账号状态", value: "本机资料")
                Divider().padding(.leading, 50)
                AccountServiceRow(symbol: "crown", title: "会员权益", value: "未开通")
                Divider().padding(.leading, 50)
                AccountServiceRow(symbol: "icloud", title: "数据同步", value: "待接入")
            }
            .padding(.vertical, 4)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 0.6)
            }
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

    private var readingAssets: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionTitle(title: "阅读资产", showsChevron: false)

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

private struct AccountMetricCard: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(PoemeryTheme.accent)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(PoemeryTheme.primaryText)
                .lineLimit(1)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct MembershipPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(PoemeryTheme.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(PoemeryTheme.surface.opacity(0.76), in: Capsule())
    }
}

private struct AccountServiceRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.accent)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.primaryText)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
