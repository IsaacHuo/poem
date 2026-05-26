import CoreTransferable
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PoemDetailView: View {
    let initialPoemID: Poem.ID
    let queue: ReadingQueue
    let library: PoemLibraryStore
    let session: ReadingSessionStore

    @Environment(\.dismiss) private var dismiss
    @State private var currentPoemID: Poem.ID
    @State private var authorPath: [AuthorResult.ID] = []
    @State private var selectedAnnotation: PoemAnnotation?
    @State private var shareImage: PoemShareImage?
    @State private var hasStartedInitialReading = false

    init(
        initialPoemID: Poem.ID,
        queue: ReadingQueue,
        library: PoemLibraryStore,
        session: ReadingSessionStore
    ) {
        self.initialPoemID = initialPoemID
        self.queue = queue
        self.library = library
        self.session = session
        self._currentPoemID = State(initialValue: initialPoemID)
    }

    private var visiblePoem: Poem {
        library.poem(id: currentPoemID)
            ?? session.currentPoem(in: library)
            ?? library.poems.first
            ?? library.poems[0]
    }

    private var currentQueue: ReadingQueue {
        session.currentQueue ?? queue
    }

    private var canMoveInQueue: Bool {
        currentQueue.poemIDs.count > 1
    }

    private var currentQueueIndex: Int? {
        currentQueue.poemIDs.firstIndex(of: visiblePoem.id)
    }

    private var queuePositionText: String {
        guard let currentQueueIndex else {
            return currentQueue.title
        }
        return "\(currentQueueIndex + 1) / \(currentQueue.poemIDs.count)"
    }

    var body: some View {
        NavigationStack(path: $authorPath) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .center, spacing: 22) {
                        Color.clear
                            .frame(height: 0)
                            .id("reader-top")

                        compactHero

                        PoemTextSection(
                            poem: visiblePoem,
                            highlightedLineID: nil,
                            selectedAnnotation: $selectedAnnotation
                        )
                        .gesture(swipeGesture)

                        RelatedPoemsSection(poems: relatedPoems, onOpenPoem: showRelatedPoem)
                            .frame(maxWidth: 680, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 56)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .background(background)
                .onChange(of: currentPoemID) {
                    selectedAnnotation = nil
                    refreshShareImage()
                    withAnimation(PoemeryTheme.motion) {
                        proxy.scrollTo("reader-top", anchor: .top)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        movePoem(by: -1)
                    } label: {
                        Image(systemName: "backward.fill")
                    }
                    .disabled(!canMoveInQueue)
                    .accessibilityLabel("上一首")

                    Spacer()

                    Text(statusBarText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PoemeryTheme.primaryText)
                        .lineLimit(1)
                        .monospacedDigit()
                        .frame(minWidth: 132)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel("\(currentQueue.title)，\(queuePositionText)")

                    Spacer()

                    Button {
                        movePoem(by: 1)
                    } label: {
                        Image(systemName: "forward.fill")
                    }
                    .disabled(!canMoveInQueue)
                    .accessibilityLabel("下一首")
                }
            }
            .toolbarBackground(.hidden, for: .bottomBar)
            .navigationDestination(for: AuthorResult.ID.self) { authorID in
                if let author = library.author(id: authorID) {
                    AuthorDetailContent(author: author, onOpenPoem: showAuthorPoem)
                } else {
                    EmptyLibraryState(title: "未找到作者", subtitle: "这个作者条目已经不可用。")
                        .padding(20)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(PoemeryTheme.background)
                }
            }
            .sheet(item: $selectedAnnotation) { annotation in
                AnnotationDetailSheet(annotation: annotation)
                    .presentationDetents([.medium])
            }
            .onAppear {
                if !hasStartedInitialReading {
                    session.startReading(visiblePoem, in: queue)
                    hasStartedInitialReading = true
                }
                refreshShareImage()
            }
        }
    }

    private var compactHero: some View {
        HStack(alignment: .center, spacing: 14) {
            PoemArtwork(poem: visiblePoem, size: 78, cornerRadius: 12)
                .shadow(color: visiblePoem.displayArtworkStyle.primary.opacity(0.24), radius: 18, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(visiblePoem.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)

                authorAttribution

                Text(visiblePoem.tags.prefix(3).joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            actionButtons
        }
        .frame(maxWidth: 680)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var authorAttribution: some View {
        if let visibleAuthor {
            NavigationLink(value: visibleAuthor.id) {
                authorAttributionLabel(showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看\(visiblePoem.author)的作者介绍")
        } else {
            authorAttributionLabel(showsChevron: false)
        }
    }

    private func authorAttributionLabel(showsChevron: Bool) -> some View {
        HStack(spacing: 4) {
            Text(detailAttributionText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .imageScale(.small)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(PoemeryTheme.secondaryText)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            favoriteButton
            shareButton
        }
    }

    private var favoriteButton: some View {
        Button {
            session.toggleFavorite(visiblePoem)
        } label: {
            Image(systemName: session.isFavorite(visiblePoem) ? "heart.fill" : "heart")
                .font(.headline.weight(.bold))
                .foregroundStyle(session.isFavorite(visiblePoem) ? PoemeryTheme.accent : PoemeryTheme.primaryText)
                .frame(width: 42, height: 42)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(session.isFavorite(visiblePoem) ? "取消收藏" : "收藏")
    }

    @ViewBuilder
    private var shareButton: some View {
        if let shareImage {
            ShareLink(
                item: shareImage,
                subject: Text(visiblePoem.title),
                message: Text(detailAttributionText),
                preview: SharePreview(visiblePoem.title, image: shareImage.previewImage)
            ) {
                shareButtonLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("分享诗歌图片")
        } else {
            Button {
                refreshShareImage()
            } label: {
                shareButtonLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("生成分享图片")
        }
    }

    private var shareButtonLabel: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.headline.weight(.bold))
            .foregroundStyle(PoemeryTheme.primaryText)
            .frame(width: 42, height: 42)
            .background(.regularMaterial, in: Circle())
    }

    private var background: some View {
        LinearGradient(
            colors: [
                visiblePoem.displayArtworkStyle.primary.opacity(0.18),
                PoemeryTheme.background,
                PoemeryTheme.background
            ],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    private var statusBarText: String {
        "\(shortQueueTitle) \(queuePositionText)"
    }

    private var visibleAuthor: AuthorResult? {
        library.author(for: visiblePoem)
    }

    private var detailAttributionText: String {
        if visiblePoem.form == "词" || visiblePoem.tags.contains("宋词") {
            return "\(visiblePoem.author) · \(visiblePoem.form)"
        }
        return "\(visiblePoem.displayArtist) · \(visiblePoem.form)"
    }

    private var shortQueueTitle: String {
        if currentQueue.title.count > 4 {
            return String(currentQueue.title.prefix(4))
        }
        return currentQueue.title
    }

    private var relatedPoems: [Poem] {
        library.poems
            .filter { $0.id != visiblePoem.id && !$0.tags.filter(visiblePoem.tags.contains).isEmpty }
            .prefix(4)
            .map { $0 }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 60
                else {
                    return
                }

                if value.translation.width < 0 {
                    movePoem(by: 1)
                } else {
                    movePoem(by: -1)
                }
            }
    }

    private func showRelatedPoem(_ poem: Poem, queue: ReadingQueue) {
        session.startReading(poem, in: queue)
        withAnimation(PoemeryTheme.motion) {
            currentPoemID = poem.id
        }
    }

    private func showAuthorPoem(_ poem: Poem, queue: ReadingQueue) {
        session.startReading(poem, in: queue)
        withAnimation(PoemeryTheme.motion) {
            currentPoemID = poem.id
            authorPath = []
        }
    }

    private func movePoem(by offset: Int) {
        guard canMoveInQueue,
              let currentQueueIndex
        else {
            return
        }

        let nextIndex = (currentQueueIndex + offset + currentQueue.poemIDs.count) % currentQueue.poemIDs.count
        guard let poem = library.poem(id: currentQueue.poemIDs[nextIndex]) else {
            return
        }

        session.startReading(poem, in: currentQueue)
        withAnimation(PoemeryTheme.motion) {
            currentPoemID = poem.id
        }
    }

    @MainActor
    private func refreshShareImage() {
        shareImage = PoemShareImage.render(poem: visiblePoem)
    }
}

private struct PoemShareImage: Transferable {
    let pngData: Data
    let previewImage: Image

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            image.pngData
        }
    }

    @MainActor
    static func render(poem: Poem) -> PoemShareImage? {
        let renderer = ImageRenderer(
            content: PoemSharePoster(poem: poem)
                .frame(width: 900, height: 1200)
        )
        renderer.scale = 2

        guard let uiImage = renderer.uiImage,
              let pngData = uiImage.pngData()
        else {
            return nil
        }

        return PoemShareImage(pngData: pngData, previewImage: Image(uiImage: uiImage))
    }
}

private struct PoemSharePoster: View {
    let poem: Poem

    private var style: ArtworkStyle {
        poem.displayArtworkStyle
    }

    private var posterLines: [String] {
        let maxLineCount = 10
        var lines = poem.lines.prefix(maxLineCount).map(\.text)
        if poem.lines.count > maxLineCount, !lines.isEmpty {
            lines[lines.count - 1] += " ……"
        }
        return lines
    }

    var body: some View {
        ZStack {
            posterBackground

            VStack(alignment: .leading, spacing: 0) {
                posterSeal

                Spacer(minLength: 120)

                VStack(alignment: .leading, spacing: 18) {
                    Text(poem.title)
                        .font(.system(size: 74, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.68)

                    Text("\(poem.displayArtist) · \(poem.form)")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(posterLines.indices, id: \.self) { index in
                        Text(posterLines[index])
                            .font(PoemeryTheme.chineseFont(size: 34, relativeTo: .title3))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                }
                .padding(.top, 68)

                Spacer(minLength: 90)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Poemery")
                            .font(.system(size: 24, weight: .bold))
                        Text("诗从千年远，与你一念近。")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.78))

                    Spacer()

                    Text(style.glyph)
                        .font(PoemeryTheme.chineseFont(size: 44, relativeTo: .title))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 72, height: 72)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.58), lineWidth: 1.5)
                        }
                }
            }
            .padding(.horizontal, 76)
            .padding(.vertical, 82)
        }
        .frame(width: 900, height: 1200)
        .clipped()
    }

    private var posterBackground: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [style.primary, style.secondary, style.tertiary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                LinearGradient(
                    colors: [.white.opacity(0.24), .clear, .black.opacity(0.44)],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.12), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(-32))
                .offset(x: 140)
            }
            .overlay(alignment: .topTrailing) {
                Text(style.glyph)
                    .font(PoemeryTheme.chineseFont(size: 360, relativeTo: .largeTitle))
                    .foregroundStyle(.white.opacity(0.12))
                    .offset(x: 44, y: -20)
            }
            .overlay(PaperTexture().opacity(0.18))
    }

    private var posterSeal: some View {
        VStack(spacing: 5) {
            Text("诗")
            Text("境")
        }
        .font(PoemeryTheme.chineseFont(size: 28, relativeTo: .title2))
        .foregroundStyle(.white.opacity(0.88))
        .frame(width: 76, height: 76)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.60), lineWidth: 1.5)
        }
    }
}
