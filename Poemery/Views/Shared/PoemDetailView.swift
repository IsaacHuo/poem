import SwiftUI

struct PoemDetailView: View {
    let poem: Poem
    let library: PoemLibraryStore
    let session: ReadingSessionStore
    let onStartReading: (Poem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var visiblePoem: Poem
    @State private var speechConductor = SpeechConductor()
    @State private var selectedAnnotation: PoemAnnotation?

    init(
        poem: Poem,
        library: PoemLibraryStore,
        session: ReadingSessionStore,
        onStartReading: @escaping (Poem) -> Void
    ) {
        self.poem = poem
        self.library = library
        self.session = session
        self.onStartReading = onStartReading
        self._visiblePoem = State(initialValue: poem)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    actionBar

                    Text(visiblePoem.summary)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(PoemeryTheme.secondaryText)
                        .padding(.horizontal, 2)

                    PoemTextSection(
                        poem: visiblePoem,
                        highlightedLineID: speechConductor.highlightedLineID,
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("更多")
                }
            }
            .sheet(item: $selectedAnnotation) { annotation in
                AnnotationDetailSheet(annotation: annotation)
                    .presentationDetents([.medium])
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

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                onStartReading(visiblePoem)
                dismiss()
            } label: {
                Label("诵读", systemImage: "play.fill")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.regular)

            Button {
                session.toggleFavorite(visiblePoem)
            } label: {
                Image(systemName: session.isFavorite(visiblePoem) ? "heart.fill" : "heart")
                    .font(.headline.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.regular)
            .tint(session.isFavorite(visiblePoem) ? PoemeryTheme.accent : PoemeryTheme.secondaryText)
            .accessibilityLabel(session.isFavorite(visiblePoem) ? "取消收藏" : "收藏")

            Button {
                toggleSpeech()
            } label: {
                Image(systemName: speechConductor.isSpeaking ? "pause.fill" : "speaker.wave.2.fill")
                    .font(.headline.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.regular)
            .tint(PoemeryTheme.secondaryText)
            .accessibilityLabel(speechConductor.isSpeaking ? "暂停朗读" : "朗读")
        }
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
        speechConductor.stop()
        withAnimation(PoemeryTheme.motion) {
            visiblePoem = poem
        }
    }

    private func toggleSpeech() {
        if speechConductor.isSpeaking {
            speechConductor.stop()
        } else {
            speechConductor.speak(poem: visiblePoem, from: 0)
        }
    }
}
