import SwiftUI

struct PoemDetailView: View {
    let poem: Poem
    let library: PoemLibraryStore
    let session: ReadingSessionStore

    @Environment(\.dismiss) private var dismiss
    @State private var visiblePoem: Poem
    @State private var selectedAnnotation: PoemAnnotation?

    init(
        poem: Poem,
        library: PoemLibraryStore,
        session: ReadingSessionStore
    ) {
        self.poem = poem
        self.library = library
        self.session = session
        self._visiblePoem = State(initialValue: poem)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    favoriteBar
                    summarySection

                    PoemTextSection(
                        poem: visiblePoem,
                        highlightedLineID: nil,
                        selectedAnnotation: $selectedAnnotation
                    )

                    RelatedPoemsSection(poems: relatedPoems, onOpenPoem: showRelatedPoem)
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
            .sheet(item: $selectedAnnotation) { annotation in
                AnnotationDetailSheet(annotation: annotation)
                    .presentationDetents([.medium])
            }
            .onAppear {
                session.markRecent(visiblePoem)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            PoemArtwork(poem: visiblePoem, size: 236, cornerRadius: 18)
                .shadow(color: visiblePoem.artworkStyle.primary.opacity(0.34), radius: 30, x: 0, y: 18)

            VStack(spacing: 7) {
                Text(visiblePoem.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.68)

                Text("\(visiblePoem.displayArtist) · \(visiblePoem.form)")
                    .font(.headline)
                    .foregroundStyle(PoemeryTheme.secondaryText)
                    .multilineTextAlignment(.center)

                Text(visiblePoem.tags.prefix(3).joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var favoriteBar: some View {
        HStack(spacing: 12) {
            Button {
                session.toggleFavorite(visiblePoem)
            } label: {
                Label(session.isFavorite(visiblePoem) ? "已收藏" : "收藏", systemImage: session.isFavorite(visiblePoem) ? "heart.fill" : "heart")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.regular)
            .tint(session.isFavorite(visiblePoem) ? PoemeryTheme.accent : PoemeryTheme.secondaryText)
            .accessibilityLabel(session.isFavorite(visiblePoem) ? "取消收藏" : "收藏")
        }
    }

    private var summarySection: some View {
        Text(visiblePoem.summary)
            .font(.body)
            .lineSpacing(4)
            .foregroundStyle(PoemeryTheme.secondaryText)
            .padding(.horizontal, 2)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                visiblePoem.artworkStyle.primary.opacity(0.26),
                PoemeryTheme.background,
                PoemeryTheme.background
            ],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    private var relatedPoems: [Poem] {
        library.poems.filter { $0.id != visiblePoem.id && !$0.tags.filter(visiblePoem.tags.contains).isEmpty }.prefix(4).map { $0 }
    }

    private func showRelatedPoem(_ poem: Poem) {
        session.markRecent(poem)
        withAnimation(PoemeryTheme.motion) {
            visiblePoem = poem
        }
    }
}
