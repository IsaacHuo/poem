import SwiftUI

struct PoemDetailView: View {
    let initialPoemID: Poem.ID
    let queue: ReadingQueue
    let library: PoemLibraryStore
    let session: ReadingSessionStore

    @Environment(\.dismiss) private var dismiss
    @State private var currentPoemID: Poem.ID
    @State private var selectedAnnotation: PoemAnnotation?

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
        NavigationStack {
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
            .sheet(item: $selectedAnnotation) { annotation in
                AnnotationDetailSheet(annotation: annotation)
                    .presentationDetents([.medium])
            }
            .onAppear {
                session.startReading(visiblePoem, in: queue)
            }
        }
    }

    private var compactHero: some View {
        HStack(alignment: .center, spacing: 14) {
            PoemArtwork(poem: visiblePoem, size: 78, cornerRadius: 12)
                .shadow(color: visiblePoem.artworkStyle.primary.opacity(0.24), radius: 18, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(visiblePoem.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text("\(visiblePoem.displayArtist) · \(visiblePoem.form)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .lineLimit(2)

                Text(visiblePoem.tags.prefix(3).joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            favoriteButton
        }
        .frame(maxWidth: 680)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(visiblePoem.title)，\(visiblePoem.displayArtist)，\(visiblePoem.form)")
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

    private var background: some View {
        LinearGradient(
            colors: [
                visiblePoem.artworkStyle.primary.opacity(0.18),
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
}
