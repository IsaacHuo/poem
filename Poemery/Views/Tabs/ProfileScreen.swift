import SwiftUI

struct ProfileScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    @State private var pendingResetAction: ProfileResetAction?

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
        NavigationStack {
            rootContent
                .navigationDestination(for: ProfileDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .confirmationDialog(
            pendingResetAction?.title ?? "清除本机记录",
            isPresented: resetConfirmationBinding,
            titleVisibility: .visible,
            presenting: pendingResetAction
        ) { action in
            Button(action.title, role: .destructive) {
                performReset(action)
            }
        } message: { action in
            Text(action.message)
        }
    }

    private var rootContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(title: "我的", subtitle: "本地阅读档案")

                archiveSummary
                settingsEntry
                readingTaste
                readingAssets
            }
            .screenContentPadding()
        }
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    @ViewBuilder
    private func destinationView(for destination: ProfileDestination) -> some View {
        switch destination {
        case .settings:
            ProfileSettingsView(
                library: library,
                session: session,
                pendingResetAction: $pendingResetAction
            )
        case .dataSource:
            DataSourceNoticeView()
        case .privacy:
            PrivacyOverviewView()
        }
    }

    private var archiveSummary: some View {
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

                    Image(systemName: "text.book.closed.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text("本地诗笺")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PoemeryTheme.primaryText)

                    Text("收藏与阅读记录仅保存在本机")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text("免费离线")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PoemeryTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PoemeryTheme.accent.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 10) {
                ArchiveMetricCard(symbol: "heart.fill", title: "收藏", value: "\(favoritePoems.count)")
                ArchiveMetricCard(symbol: "clock.fill", title: "最近", value: "\(recentPoems.count)")
                ArchiveMetricCard(symbol: "text.book.closed.fill", title: "诗库", value: "\(library.poems.count)")
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.58), lineWidth: 0.6)
        }
    }

    private var settingsEntry: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "设置与隐私", showsChevron: false)

            NavigationLink(value: ProfileDestination.settings) {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.accent)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("本地设置")
                            .font(.headline)
                            .foregroundStyle(PoemeryTheme.primaryText)

                        Text("数据来源、隐私说明与本机记录管理")
                            .font(.subheadline)
                            .foregroundStyle(PoemeryTheme.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PoemeryTheme.tertiaryText)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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

    private var resetConfirmationBinding: Binding<Bool> {
        Binding {
            pendingResetAction != nil
        } set: { isPresented in
            if !isPresented {
                pendingResetAction = nil
            }
        }
    }

    private func performReset(_ action: ProfileResetAction) {
        switch action {
        case .favorites:
            session.clearFavorites()
        case .recents:
            session.clearRecents()
        }
        pendingResetAction = nil
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

private struct ArchiveMetricCard: View {
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
