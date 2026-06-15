import SwiftUI

enum ProfileDestination: Hashable {
    case library
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

struct DataSourceNoticeView: View {
    private let noticeText = DataSourceNoticeView.loadNoticeText()
    @Environment(\.chineseScriptPreference) private var script

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(script.converted("Poemery 使用随 App 打包的本地诗词数据。"))
                        .font(.headline)
                        .foregroundStyle(PoemeryTheme.primaryText)

                    Text(script.converted("内容来自 chinese-poetry/chinese-poetry 的固定版本，阅读和搜索不会在运行时请求远端诗库。"))
                        .font(.subheadline)
                        .foregroundStyle(PoemeryTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .groupedListBackground()

                Text(script.converted(noticeText))
                    .font(.footnote.monospaced())
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .groupedListBackground()
            }
            .screenContentPadding()
        }
        .navigationTitle(script.converted("数据来源"))
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
    @Environment(\.chineseScriptPreference) private var script

    var body: some View {
        List {
            Section(script.converted("免费离线")) {
                SettingsLabelRow(symbol: "internaldrive.fill", title: script.converted("诗库随 App 保存在本机"))
                SettingsLabelRow(symbol: "wifi.slash", title: script.converted("核心阅读和搜索不需要联网"))
            }

            Section(script.converted("本机保存")) {
                SettingsLabelRow(symbol: "heart.fill", title: script.converted("收藏保存在本机 UserDefaults"))
                SettingsLabelRow(symbol: "clock.fill", title: script.converted("最近阅读保存在本机 UserDefaults"))
                SettingsLabelRow(symbol: "trash.fill", title: script.converted("可以在设置中清除本机记录"))
            }

            Section(script.converted("数据使用")) {
                SettingsLabelRow(symbol: "hand.raised.fill", title: script.converted("不追踪用户"))
                SettingsLabelRow(symbol: "icloud.slash.fill", title: script.converted("不上传收藏或最近阅读"))
                SettingsLabelRow(symbol: "bell.slash.fill", title: script.converted("不使用推送通知"))
            }
        }
        .navigationTitle(script.converted("隐私说明"))
        .navigationBarTitleDisplayMode(.large)
        .background(PoemeryTheme.background)
    }
}

struct SettingsLabelRow: View {
    let symbol: String
    let title: String
    var includesRowPadding = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(PoemeryTheme.accent)
                .frame(width: 24, height: 22, alignment: .center)
                .baselineOffset(-1)

            Text(title)
                .font(.body)
                .foregroundStyle(PoemeryTheme.primaryText)
        }
        .padding(.horizontal, includesRowPadding ? 14 : 0)
        .padding(.vertical, includesRowPadding ? 11 : 0)
    }
}

struct SettingsValueRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsLabelRow(symbol: symbol, title: title)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PoemeryTheme.secondaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}
