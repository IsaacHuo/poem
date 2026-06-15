import SwiftUI

struct CollectionDetailView: View {
    let collection: PoemCollection
    let library: PoemLibraryStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.chineseScriptPreference) private var script
    @State private var poems: [Poem] = []
    @State private var nextPage: Int? = 1
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    poemList
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 56)
            }
            .background(background)
            .task(id: "\(collection.id)|\(script.rawValue)") {
                await loadFirstPage()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            CollectionCover(collection: collection, poemCount: collection.poemCount)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                Text(collection.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(collection.subtitle)
                    .font(.headline)
                    .foregroundStyle(PoemeryTheme.secondaryText)

                Text("\(collection.poemCount) 首作品")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PoemeryTheme.accent)
            }
        }
    }

    private var poemList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "作品")

            if poems.isEmpty && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .groupedListBackground()
            } else if poems.isEmpty {
                EmptyLibraryState(title: "暂无作品", subtitle: "这个诗单暂时没有可阅读的作品。")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(poems) { poem in
                        Button {
                            onOpenPoem(poem, ReadingQueue(title: collection.title, poems: poems))
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

                if nextPage != nil {
                    Button(action: loadMore) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                            Text(isLoading ? "加载中" : "继续加载")
                            Spacer()
                            Text("\(poems.count) / \(collection.poemCount)")
                                .foregroundStyle(PoemeryTheme.tertiaryText)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(PoemeryTheme.accent)
                    .disabled(isLoading)
                }
            }
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                collection.accent.primary.opacity(0.24),
                PoemeryTheme.background,
                PoemeryTheme.background
            ],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    private func loadFirstPage() async {
        poems = []
        nextPage = 1
        await loadPage(1)
    }

    private func loadMore() {
        guard let nextPage else {
            return
        }

        Task {
            await loadPage(nextPage)
        }
    }

    private func loadPage(_ page: Int) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        let result = await library.loadCollectionPoems(collection: collection, page: page, script: script)
        if page <= 1 {
            poems = result.poems
        } else {
            poems.append(contentsOf: result.poems)
        }
        nextPage = result.nextPage
        isLoading = false
    }
}

struct AuthorDetailView: View {
    let author: AuthorResult
    let library: PoemLibraryStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PagedAuthorDetailContent(author: author, library: library, onOpenPoem: onOpenPoem)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("关闭") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct PagedAuthorDetailContent: View {
    let author: AuthorResult
    let library: PoemLibraryStore
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    @Environment(\.chineseScriptPreference) private var script
    @State private var poems: [Poem] = []
    @State private var nextPage: Int? = 1
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AuthorHeader(author: author)
                AuthorIntroduction(author: author)
                poemList
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 56)
        }
        .background(PoemeryTheme.background)
        .navigationTitle(author.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(author.id)|\(script.rawValue)") {
            await reloadFirstPage()
        }
    }

    private var poemList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "作品")

            if poems.isEmpty && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .groupedListBackground()
            } else if poems.isEmpty {
                EmptyLibraryState(title: "暂无作品", subtitle: "这个诗人暂时没有可阅读的作品。")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(poems) { poem in
                        Button {
                            onOpenPoem(poem, ReadingQueue(title: author.name, poems: poems))
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

                if nextPage != nil {
                    Button(action: loadMore) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.down.circle")
                            }
                            Text(isLoading ? "加载中" : "继续加载")
                            Spacer()
                            Text("\(poems.count) / \(author.poemCount)")
                                .foregroundStyle(PoemeryTheme.tertiaryText)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(PoemeryTheme.accent)
                    .disabled(isLoading)
                }
            }
        }
    }

    private func loadFirstPage() async {
        guard poems.isEmpty else {
            return
        }
        await loadPage(1)
    }

    private func reloadFirstPage() async {
        poems = []
        nextPage = 1
        await loadPage(1)
    }

    private func loadMore() {
        guard let nextPage else {
            return
        }

        Task {
            await loadPage(nextPage)
        }
    }

    private func loadPage(_ page: Int) async {
        guard !isLoading else {
            return
        }

        isLoading = true
        let result = await library.loadAuthorPoems(author: author, page: page, script: script)
        if page <= 1 {
            poems = result.poems
        } else {
            poems.append(contentsOf: result.poems)
        }
        nextPage = result.nextPage
        isLoading = false
    }
}

struct AuthorDetailContent: View {
    let author: AuthorResult
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AuthorHeader(author: author)
                AuthorIntroduction(author: author)
                poemList
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 56)
        }
        .background(PoemeryTheme.background)
        .navigationTitle(author.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var poemList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "作品")

            if author.poems.isEmpty {
                EmptyLibraryState(title: "暂无作品", subtitle: "这个诗人暂时没有可阅读的作品。")
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(author.poems) { poem in
                        Button {
                            onOpenPoem(poem, ReadingQueue(title: author.name, poems: author.poems))
                        } label: {
                            PoemListRow(poem: poem)
                        }
                        .buttonStyle(.plain)

                        if poem.id != author.poems.last?.id {
                            Divider()
                                .padding(.leading, 74)
                        }
                    }
                }
                .groupedListBackground()
            }
        }
    }
}

struct AuthorHeader: View {
    let author: AuthorResult

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(PoemeryTheme.groupedBackground)

                Text(String(author.name.prefix(1)))
                    .font(PoemeryTheme.chineseFont(size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(PoemeryTheme.accent)
            }
            .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 7) {
                Text(author.name)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("\(author.dynasty) · \(author.poemCount) 首作品")
                    .font(.headline)
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

struct AuthorIntroduction: View {
    let author: AuthorResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "作者简介")

            Text(author.introduction)
                .font(.body)
                .foregroundStyle(PoemeryTheme.secondaryText)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .groupedListBackground()
        }
    }
}

private struct CollectionCover: View {
    let collection: PoemCollection
    let poemCount: Int

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            collection.accent.primary,
                            collection.accent.secondary,
                            collection.accent.tertiary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.14))
                        .frame(width: 112, height: 160)
                        .rotationEffect(.degrees(-8))
                        .offset(x: 22, y: 28)
                }
                .overlay(alignment: .topTrailing) {
                    VStack(spacing: 4) {
                        Text("诗")
                        Text("境")
                    }
                    .font(PoemeryTheme.chineseFont(size: 22, relativeTo: .title3))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 56, height: 56)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(.white.opacity(0.55), lineWidth: 1)
                    }
                    .padding(20)
                }
                .overlay(alignment: .center) {
                    Text(collection.accent.glyph)
                        .font(PoemeryTheme.chineseFont(size: 144, relativeTo: .largeTitle))
                        .foregroundStyle(.white.opacity(0.20))
                }
                .overlay(PaperTexture().opacity(0.24))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("诗单")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))

                Text(collection.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text("\(poemCount) 首作品")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(22)
        }
        .frame(height: 280)
        .shadow(color: collection.accent.primary.opacity(0.22), radius: 24, x: 0, y: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.title)，\(poemCount) 首作品")
    }
}
