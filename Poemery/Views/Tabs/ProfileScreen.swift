import SwiftUI

struct ProfileScreen: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void

    @AppStorage("poemery.profile.displayName") private var displayName = "诗笺用户"
    @AppStorage("poemery.profile.signature") private var signature = "把喜欢的诗词留在本机"
    @AppStorage("poemery.profile.avatarSymbol") private var avatarSymbol = "person.fill"
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
            VStack(alignment: .leading, spacing: 28) {
                ScreenHeader(title: "我的", subtitle: "本地账号与阅读档案")

                accountCard
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

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                ProfileAvatar(symbol: avatarSymbol, size: 76)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(PoemeryTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text("免费离线")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PoemeryTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PoemeryTheme.accent.opacity(0.12), in: Capsule())
                    }

                    Text(signature)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("本地账号 · 无需登录 · 不上传阅读记录")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.tertiaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 10) {
                AccountMetricCard(symbol: "heart.fill", title: "收藏", value: "\(favoritePoems.count)")
                AccountMetricCard(symbol: "clock.fill", title: "最近", value: "\(recentPoems.count)")
                AccountMetricCard(symbol: "text.book.closed.fill", title: "诗库", value: "\(library.poems.count)")
            }

            HStack(spacing: 10) {
                Button {
                    isEditingProfile = true
                } label: {
                    Label("编辑资料", systemImage: "pencil")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PoemeryTheme.accent)

                NavigationLink(value: ProfileDestination.settings) {
                    Label("账号设置", systemImage: "gearshape")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(PoemeryTheme.accent)
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
            SectionTitle(title: "账号服务", showsChevron: false)

            NavigationLink(value: ProfileDestination.settings) {
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.accent)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("本地账号设置")
                            .font(.headline)
                            .foregroundStyle(PoemeryTheme.primaryText)

                        Text("资料、数据来源、隐私说明与本机记录管理")
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

private struct ProfileAvatar: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
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

            Image(systemName: symbol)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: PoemeryTheme.accent.opacity(0.18), radius: 16, x: 0, y: 10)
        .accessibilityLabel("账号头像")
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

private struct ProfileEditorSheet: View {
    @Binding var displayName: String
    @Binding var signature: String
    @Binding var avatarSymbol: String

    @Environment(\.dismiss) private var dismiss
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

                Section("账号资料") {
                    TextField("昵称", text: $draftDisplayName)
                        .textInputAutocapitalization(.never)

                    TextField("签名", text: $draftSignature, axis: .vertical)
                        .lineLimit(2...3)
                }

                Section("头像") {
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
                            .accessibilityLabel("头像")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        save()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PoemeryTheme.background)
        }
    }

    private func save() {
        let trimmedName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSignature = draftSignature.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = trimmedName.isEmpty ? "诗笺用户" : trimmedName
        signature = trimmedSignature.isEmpty ? "把喜欢的诗词留在本机" : trimmedSignature
        avatarSymbol = draftAvatarSymbol
        dismiss()
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
