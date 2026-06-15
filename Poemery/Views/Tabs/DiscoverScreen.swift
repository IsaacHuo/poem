import SwiftUI

struct DiscoverScreen: View {
    let library: PoemLibraryStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void
    let onOpenCollection: (PoemCollection) -> Void
    let onStartSearch: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private let themeQueries = ["思乡", "抒情", "爱国", "哲理"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ScreenHeader(title: "按朝代、体裁与题材慢慢找。", subtitle: nil)
                    discoveryContent
                }
                .screenContentPadding()
            }
            .navigationTitle("资料库")
            .navigationBarTitleDisplayMode(.large)
            .scrollIndicators(.hidden)
            .background(PoemeryTheme.background)
        }
    }

    private var discoveryContent: some View {
        VStack(alignment: .leading, spacing: 32) {
            FeaturedCarousel(
                title: "编辑推荐",
                collections: library.collections.filter { [.chart, .mood, .featured].contains($0.kind) },
                library: library,
                layout: .narrowPortrait,
                onOpenCollection: onOpenCollection
            )

            keywordBlock

            browseBlock(title: "按朝代", values: library.dynasties())
            browseBlock(title: "按体裁", values: library.forms(limit: 6))
            themeBlock

            PoemListSection(title: "编辑精选", poems: library.popularPoems(limit: 6), onOpenPoem: onOpenPoem)

            VStack(alignment: .leading, spacing: 14) {
                SectionTitle(title: "浏览题材")

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(library.categories) { category in
                        Button {
                            onStartSearch(category.title)
                        } label: {
                            CategoryTile(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var keywordBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "高频字词")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(library.frequentKeywords(limit: 12)) { keyword in
                        Button {
                            onStartSearch(keyword.text)
                        } label: {
                            KeywordChip(keyword: keyword)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private func browseBlock(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: title)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(values, id: \.self) { value in
                        Button {
                            onStartSearch(value)
                        } label: {
                            Text(value)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PoemeryTheme.primaryText)
                                .padding(.horizontal, 16)
                                .frame(height: 38)
                                .background(PoemeryTheme.surface, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var themeBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "主题书架")

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(themeQueries, id: \.self) { theme in
                    Button {
                        onStartSearch(theme)
                    } label: {
                        ThemeTile(
                            title: theme,
                            count: library.poems(forTheme: theme).count,
                            style: themeStyle(for: theme)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func themeStyle(for theme: String) -> ArtworkStyle {
        switch theme {
        case "思乡":
            ArtworkStyle(primaryHex: "#355B72", secondaryHex: "#A9D0CA", tertiaryHex: "#242E36", glyph: "乡")
        case "爱国":
            ArtworkStyle(primaryHex: "#A53B32", secondaryHex: "#E6A85F", tertiaryHex: "#24252D", glyph: "国")
        case "哲理":
            ArtworkStyle(primaryHex: "#2F6658", secondaryHex: "#D3B56D", tertiaryHex: "#232F2D", glyph: "理")
        default:
            ArtworkStyle(primaryHex: "#7E365A", secondaryHex: "#D99EB3", tertiaryHex: "#2C2530", glyph: "情")
        }
    }
}

private struct KeywordChip: View {
    let keyword: PoemKeyword

    var body: some View {
        HStack(spacing: 8) {
            Text(keyword.text)
                .font(PoemeryTheme.chineseFont(size: 24, relativeTo: .title3))
                .foregroundStyle(PoemeryTheme.accent)

            Text("\(keyword.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(PoemeryTheme.secondaryText)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(PoemeryTheme.surface, in: Capsule())
        .accessibilityLabel("\(keyword.text)，\(keyword.count) 首相关作品")
    }
}

private struct ThemeTile: View {
    let title: String
    let count: Int
    let style: ArtworkStyle

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [style.primary, style.secondary, style.tertiary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Text(style.glyph)
                        .font(PoemeryTheme.chineseFont(size: 52, relativeTo: .largeTitle))
                        .foregroundStyle(.white.opacity(0.24))
                        .padding(12)
                }
                .overlay(PaperTexture().opacity(0.16))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(count) 首相关作品")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
            }
            .padding(16)
        }
        .frame(height: 104)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)，\(count) 首相关作品")
    }
}
