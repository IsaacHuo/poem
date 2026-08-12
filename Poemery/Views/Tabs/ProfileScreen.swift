import SwiftUI

struct ProfileScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    @AppStorage("poemery.profile.displayName") private var displayName = "诗笺用户"
    @AppStorage("poemery.profile.signature") private var signature = "把喜欢的诗词留在本机"
    @AppStorage("poemery.profile.avatarSymbol") private var avatarSymbol = "person.fill"
    @AppStorage(ChineseScriptPreference.storageKey) private var chineseScriptRawValue = ChineseScriptPreference.simplified.rawValue
    @AppStorage(PoemTextSizePreference.storageKey) private var poemTextSize = PoemTextSizePreference.defaultValue
    @Environment(\.chineseScriptPreference) private var script
    @State private var pendingResetAction: ProfileResetAction?
    @State private var isEditingProfile = false

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

    private var statisticsValue: String {
        let totalMinutes = Int(session.statistics.totalDuration) / 60
        let hours = totalMinutes / 60
        if hours > 0 {
            return script.converted("\(hours) 小时")
        }
        let minutes = totalMinutes % 60
        if minutes > 0 {
            return script.converted("\(minutes) 分钟")
        }
        return script.converted("\(Int(session.statistics.totalDuration)) 秒")
    }

    var body: some View {
        NavigationStack {
            rootContent
                .navigationDestination(for: ProfileDestination.self) { destination in
                    destinationView(for: destination)
                }
        }
        .confirmationDialog(
            script.converted(pendingResetAction?.title ?? "清除本机记录"),
            isPresented: resetConfirmationBinding,
            titleVisibility: .visible,
            presenting: pendingResetAction
        ) { action in
            Button(script.converted(action.title), role: .destructive) {
                performReset(action)
            }
        } message: { action in
            Text(script.converted(action.message))
        }
        .sheet(isPresented: $isEditingProfile) {
            ProfileEditorSheet(
                displayName: $displayName,
                signature: $signature,
                avatarSymbol: $avatarSymbol
            )
        }
    }

    private var rootContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                accountSummary
                readingTaste
                settingsEntry
            }
            .screenContentPadding()
            .padding(.bottom, 52)
        }
        .navigationTitle(script.converted("我的"))
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    @ViewBuilder
    private func destinationView(for destination: ProfileDestination) -> some View {
        switch destination {
        case .favorites:
            ProfilePoemListView(
                title: script.converted("收藏"),
                poems: favoritePoems,
                emptyTitle: script.converted("还没有收藏"),
                emptySubtitle: script.converted("打开作品详情后可以把喜欢的诗词加入收藏。"),
                queueTitle: script.converted("收藏"),
                onOpenPoem: onOpenPoem
            )
        case .recents:
            ProfilePoemListView(
                title: script.converted("最近阅读"),
                poems: recentPoems,
                emptyTitle: script.converted("还没有最近阅读"),
                emptySubtitle: script.converted("打开任意作品详情后会出现在这里。"),
                queueTitle: script.converted("最近阅读"),
                onOpenPoem: onOpenPoem
            )
        case .statistics:
            ReadingStatisticsView(library: library, session: session)
        case .settings:
            ProfileSettingsHomeView(
                chineseScriptRawValue: $chineseScriptRawValue,
                poemTextSize: $poemTextSize,
                favoriteCount: session.favoritePoemIDs.count,
                recentCount: session.recentPoemIDs.count,
                onReset: { pendingResetAction = $0 }
            )
        case .dataSource:
            DataSourceNoticeView()
        case .privacy:
            PrivacyOverviewView()
        }
    }

    private var accountSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: script.converted("账号摘要"), showsChevron: false)

            VStack(spacing: 0) {
                Button {
                    isEditingProfile = true
                } label: {
                    HStack(spacing: 12) {
                        ProfileAvatar(symbol: avatarSymbol, size: 56)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(script.converted(displayName))
                                .font(.headline)
                                .foregroundStyle(PoemeryTheme.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            Text(script.converted(signature))
                                .font(.subheadline)
                                .foregroundStyle(PoemeryTheme.secondaryText)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PoemeryTheme.tertiaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 82)

                NavigationLink(value: ProfileDestination.favorites) {
                    AccountValueRow(symbol: "heart.fill", title: script.converted("收藏"), value: "\(favoritePoems.count)")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(value: ProfileDestination.recents) {
                    AccountValueRow(symbol: "clock.fill", title: script.converted("最近阅读"), value: "\(recentPoems.count)")
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 50)

                NavigationLink(value: ProfileDestination.statistics) {
                    AccountValueRow(symbol: "chart.bar.fill", title: script.converted("阅读统计"), value: statisticsValue)
                }
                .buttonStyle(.plain)
            }
            .groupedListBackground()
        }
    }

    private var readingTaste: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: script.converted("阅读偏好"), showsChevron: false)

            VStack(alignment: .leading, spacing: 0) {
                PreferenceRow(title: script.converted("常读作者"), values: topAuthors.map(script.converted))
                Divider()
                PreferenceRow(title: script.converted("常读体裁"), values: topForms.map(script.converted))
            }
            .groupedListBackground()
        }
    }

    private var settingsEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: script.converted("管理"), showsChevron: false)

            VStack(spacing: 0) {
                NavigationLink(value: ProfileDestination.settings) {
                    ProfileNavigationRow(symbol: "gearshape.fill", title: script.converted("设置与隐私"))
                }
                .buttonStyle(.plain)
            }
            .groupedListBackground()
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

private struct ProfileAvatar: View {
    let symbol: String
    let size: CGFloat
    @Environment(\.chineseScriptPreference) private var script

    var body: some View {
        ZStack {
            Circle()
                .fill(PoemeryTheme.groupedBackground)

            Image(systemName: symbol)
                .font(.system(size: size * 0.40, weight: .semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(script.converted("账号头像"))
    }
}

private struct AccountValueRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(PoemeryTheme.accent)
                .frame(width: 24, height: 22, alignment: .center)
                .baselineOffset(-1)

            Text(title)
                .font(.body)
                .foregroundStyle(PoemeryTheme.primaryText)
                .lineLimit(1)

            Spacer(minLength: 12)

            Text(value)
                .font(.body)
                .foregroundStyle(PoemeryTheme.secondaryText)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PoemeryTheme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

private struct ProfileNavigationRow: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(PoemeryTheme.accent)
                .frame(width: 24, height: 22, alignment: .center)
                .baselineOffset(-1)

            Text(title)
                .font(.body)
                .foregroundStyle(PoemeryTheme.primaryText)

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(PoemeryTheme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

private struct ProfilePoemListView: View {
    let title: String
    let poems: [Poem]
    let emptyTitle: String
    let emptySubtitle: String
    let queueTitle: String
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    var body: some View {
        ScrollView {
            if poems.isEmpty {
                EmptyLibraryState(title: emptyTitle, subtitle: emptySubtitle)
                    .screenContentPadding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(poems) { poem in
                        Button {
                            onOpenPoem(poem, ReadingQueue(title: queueTitle, poems: poems))
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
                .groupedListBackground()
                .screenContentPadding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }
}

private struct ProfileEditorSheet: View {
    @Binding var displayName: String
    @Binding var signature: String
    @Binding var avatarSymbol: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.chineseScriptPreference) private var script
    @State private var draftDisplayName: String
    @State private var draftSignature: String
    @State private var draftAvatarSymbol: String

    private let avatarOptions = [
        "person.fill",
        "text.book.closed.fill",
        "bookmark.fill",
        "heart.text.square.fill",
        "sparkles"
    ]

    init(
        displayName: Binding<String>,
        signature: Binding<String>,
        avatarSymbol: Binding<String>
    ) {
        self._displayName = displayName
        self._signature = signature
        self._avatarSymbol = avatarSymbol
        self._draftDisplayName = State(initialValue: displayName.wrappedValue)
        self._draftSignature = State(initialValue: signature.wrappedValue)
        self._draftAvatarSymbol = State(initialValue: avatarSymbol.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()

                        ProfileAvatar(symbol: draftAvatarSymbol, size: 88)

                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section(script.converted("账号资料")) {
                    TextField(script.converted("昵称"), text: $draftDisplayName)
                        .textInputAutocapitalization(.never)

                    TextField(script.converted("签名"), text: $draftSignature, axis: .vertical)
                        .lineLimit(2...3)
                }

                Section(script.converted("头像")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                        ForEach(avatarOptions, id: \.self) { symbol in
                            Button {
                                draftAvatarSymbol = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(symbol == draftAvatarSymbol ? .white : PoemeryTheme.accent)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        symbol == draftAvatarSymbol ? PoemeryTheme.accent : PoemeryTheme.accent.opacity(0.10),
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(script.converted("头像"))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(script.converted("编辑资料"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(script.converted("取消")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(script.converted("完成")) {
                        save()
                    }
                }
            }
            .background(PoemeryTheme.background)
        }
    }

    private func save() {
        let trimmedName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSignature = draftSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = trimmedName.isEmpty ? script.converted("诗笺用户") : trimmedName
        signature = trimmedSignature.isEmpty ? script.converted("把喜欢的诗词留在本机") : trimmedSignature
        avatarSymbol = draftAvatarSymbol
        dismiss()
    }
}

private struct PreferenceRow: View {
    let title: String
    let values: [String]
    @Environment(\.chineseScriptPreference) private var script

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.body)
                .foregroundStyle(PoemeryTheme.primaryText)

            Spacer(minLength: 16)

            Text(displayValue)
                .font(.body)
                .foregroundStyle(PoemeryTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var displayValue: String {
        values.isEmpty ? script.converted("暂无记录") : values.joined(separator: " · ")
    }
}
