import SwiftUI

struct CollectionDetailView: View {
    let collection: PoemCollection
    let poems: [Poem]
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    @Environment(\.dismiss) private var dismiss

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
            CollectionCover(collection: collection, poemCount: poems.count)
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

                Text("\(poems.count) 首作品")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PoemeryTheme.accent)
            }
        }
    }

    private var poemList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "作品")

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
}

struct AuthorDetailView: View {
    let author: AuthorResult
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AuthorDetailContent(author: author, onOpenPoem: onOpenPoem)
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

struct AuthorDetailContent: View {
    let author: AuthorResult
    let onOpenPoem: (Poem, ReadingQueue) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                introductionSection
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

    private var header: some View {
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

                Text("\(author.dynasty) · \(author.poems.count) 首作品")
                    .font(.headline)
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .lineLimit(1)
            }
        }
    }

    private var introductionSection: some View {
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
