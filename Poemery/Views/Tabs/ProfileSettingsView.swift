import SwiftUI

enum ProfileDestination: Hashable {
    case settings
    case dataSource
    case privacy
}

enum ProfileResetAction: Identifiable {
    case favorites
    case recents

    var id: String {
        switch self {
        case .favorites: "favorites"
        case .recents: "recents"
        }
    }

    var title: String {
        switch self {
        case .favorites: "清除收藏"
        case .recents: "清除最近阅读"
        }
    }

    var message: String {
        switch self {
        case .favorites: "收藏只保存在本机。清除后不会影响诗库内容。"
        case .recents: "最近阅读和当前阅读状态会从本机移除。"
        }
    }
}

struct ProfileSettingsView: View {
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    @Binding var pendingResetAction: ProfileResetAction?

    var body: some View {
        List {
            Section("本地诗库") {
                SettingsValueRow(symbol: "text.book.closed.fill", title: "诗词", value: "\(library.poems.count)")
                SettingsValueRow(symbol: "person.2.fill", title: "作者", value: "\(library.authors().count)")
                SettingsValueRow(symbol: "rectangle.stack.fill", title: "诗单", value: "\(library.collections.count)")

                NavigationLink(value: ProfileDestination.dataSource) {
                    SettingsLabelRow(symbol: "doc.text.magnifyingglass", title: "数据来源与许可")
                }
            }

            Section("本机数据") {
                SettingsValueRow(symbol: "heart.fill", title: "收藏", value: "\(session.favoritePoemIDs.count)")
                SettingsValueRow(symbol: "clock.fill", title: "最近阅读", value: "\(session.recentPoemIDs.count)")

                Button(role: .destructive) {
                    pendingResetAction = .favorites
                } label: {
                    SettingsLabelRow(symbol: "heart.slash.fill", title: "清除收藏")
                }
                .disabled(session.favoritePoemIDs.isEmpty)

                Button(role: .destructive) {
                    pendingResetAction = .recents
                } label: {
                    SettingsLabelRow(symbol: "clock.badge.xmark.fill", title: "清除最近阅读")
                }
                .disabled(session.recentPoemIDs.isEmpty)
            }

            Section("显示") {
                SettingsValueRow(symbol: "sun.max.fill", title: "外观", value: "浅色纸感")
                SettingsValueRow(symbol: "textformat.size", title: "文字", value: "跟随系统动态字体")
            }

            Section("隐私") {
                NavigationLink(value: ProfileDestination.privacy) {
                    SettingsLabelRow(symbol: "hand.raised.fill", title: "隐私说明")
                }
                SettingsValueRow(symbol: "wifi.slash", title: "网络", value: "离线可用")
                SettingsValueRow(symbol: "person.crop.circle.badge.xmark", title: "远程登录", value: "无需")
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .scrollContentBackground(.hidden)
        .background(PoemeryTheme.background)
    }
}

struct DataSourceNoticeView: View {
    private let noticeText = DataSourceNoticeView.loadNoticeText()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Poemery 使用随 App 打包的离线诗词数据。")
                        .font(.headline)
                        .foregroundStyle(PoemeryTheme.primaryText)

                    Text("内容来自 chinese-poetry/chinese-poetry 的固定版本，App 不在运行时联网更新诗库。")
                        .font(.subheadline)
                        .foregroundStyle(PoemeryTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.58), lineWidth: 0.6)
                }

                Text(noticeText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .screenContentPadding()
        }
        .navigationTitle("数据来源")
        .navigationBarTitleDisplayMode(.large)
        .scrollIndicators(.hidden)
        .background(PoemeryTheme.background)
    }

    private static func loadNoticeText() -> String {
        guard let url = Bundle.main.url(forResource: "ChinesePoetryNotice", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            return "未找到数据来源说明。"
        }

        return text
    }
}

struct PrivacyOverviewView: View {
    var body: some View {
        List {
            Section("免费离线") {
                SettingsLabelRow(symbol: "wifi.slash", title: "核心阅读和搜索不需要联网")
                SettingsLabelRow(symbol: "person.crop.circle.badge.xmark", title: "本地账号不需要远程登录")
            }

            Section("本机保存") {
                SettingsLabelRow(symbol: "heart.fill", title: "收藏保存在本机 UserDefaults")
                SettingsLabelRow(symbol: "clock.fill", title: "最近阅读保存在本机 UserDefaults")
                SettingsLabelRow(symbol: "trash.fill", title: "可以在设置中清除本机记录")
            }

            Section("数据使用") {
                SettingsLabelRow(symbol: "hand.raised.fill", title: "不追踪用户")
                SettingsLabelRow(symbol: "icloud.slash.fill", title: "不上传收藏或最近阅读")
                SettingsLabelRow(symbol: "bell.slash.fill", title: "不使用推送通知")
            }
        }
        .navigationTitle("隐私说明")
        .navigationBarTitleDisplayMode(.large)
        .scrollContentBackground(.hidden)
        .background(PoemeryTheme.background)
    }
}

private struct SettingsLabelRow: View {
    let symbol: String
    let title: String

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(PoemeryTheme.primaryText)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(PoemeryTheme.accent)
        }
    }
}

private struct SettingsValueRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsLabelRow(symbol: symbol, title: title)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}
