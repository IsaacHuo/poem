import SwiftUI

struct NowReadingView: View {
    let poem: Poem
    let library: PoemLibraryStore
    let session: ReadingSessionStore

    @Environment(\.dismiss) private var dismiss
    @State private var speechConductor = SpeechConductor()
    @State private var selectedAnnotation: PoemAnnotation?

    var body: some View {
        ZStack {
            playerBackground

            VStack(spacing: 22) {
                Capsule()
                    .fill(.white.opacity(0.38))
                    .frame(width: 78, height: 5)
                    .padding(.top, 10)

                topBar
                poemIdentity
                verseDisplay
                progressArea
                transportControls
                volumeArea
                bottomActions
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 30)
        }
        .foregroundStyle(.white)
        .sheet(item: $selectedAnnotation) { annotation in
            AnnotationDetailSheet(annotation: annotation)
                .presentationDetents([.medium])
        }
        .onAppear {
            session.startReading(poem, queue: library.poems)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("收起")

            Spacer()

            VStack(spacing: 2) {
                Text("正在诵读")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
                Text(poem.form)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Button {
            } label: {
                Image(systemName: "ellipsis")
                    .font(.headline.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("更多")
        }
    }

    private var poemIdentity: some View {
        HStack(spacing: 18) {
            PoemArtwork(poem: poem, size: 92, cornerRadius: 14)
                .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)

            VStack(alignment: .leading, spacing: 5) {
                Text(poem.title)
                    .font(.title.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)
                Text(poem.displayArtist)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            Button {
                session.toggleFavorite(poem)
            } label: {
                Image(systemName: session.isFavorite(poem) ? "star.fill" : "star")
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.isFavorite(poem) ? "取消收藏" : "收藏")
        }
    }

    private var verseDisplay: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(poem.lines.prefix(4)) { line in
                Text(line.text)
                    .font(PoemeryTheme.chineseFont(size: 40, relativeTo: .largeTitle))
                    .fontWeight(.bold)
                    .foregroundStyle(line.id == speechConductor.highlightedLineID ? .white : .white.opacity(0.38))
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
            }

            if let annotation = poem.annotations.first {
                Button {
                    selectedAnnotation = annotation
                } label: {
                    Label("注解", systemImage: "text.bubble")
                        .font(.headline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.16), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 260, alignment: .center)
    }

    private var progressArea: some View {
        VStack(spacing: 8) {
            ProgressView(value: 0.18)
                .tint(.white.opacity(0.76))
                .background(.white.opacity(0.18), in: Capsule())

            HStack {
                Text("0:05")
                Spacer()
                Text("-4:55")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.52))
        }
    }

    private var transportControls: some View {
        HStack {
            Button {
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 34, weight: .bold))
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                toggleSpeech()
            } label: {
                Image(systemName: speechConductor.isSpeaking ? "pause.fill" : "play.fill")
                    .font(.system(size: 46, weight: .bold))
                    .frame(width: 76, height: 76)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speechConductor.isSpeaking ? "暂停朗读" : "开始朗读")

            Spacer()

            Button {
                session.playNext(in: library)
                dismiss()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 34, weight: .bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下一首诗词")
        }
        .padding(.horizontal, 12)
    }

    private var volumeArea: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
            ProgressView(value: 0.42)
                .tint(.white.opacity(0.72))
                .background(.white.opacity(0.16), in: Capsule())
            Image(systemName: "speaker.wave.3.fill")
        }
        .font(.headline)
        .foregroundStyle(.white.opacity(0.62))
    }

    private var bottomActions: some View {
        HStack {
            Image(systemName: "quote.bubble.fill")
            Spacer()
            Image(systemName: "airplayaudio")
            Spacer()
            Image(systemName: "list.bullet")
        }
        .font(.headline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.72))
        .padding(.horizontal, 22)
        .padding(.top, 2)
    }

    private var playerBackground: some View {
        LinearGradient(
            colors: [
                poem.artworkStyle.primary.opacity(0.92),
                poem.artworkStyle.tertiary.opacity(0.96),
                Color.black.opacity(0.96)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(PaperTexture().opacity(0.08))
        .ignoresSafeArea()
    }

    private func toggleSpeech() {
        if speechConductor.isSpeaking {
            speechConductor.stop()
        } else {
            speechConductor.speak(poem: poem, from: 0)
        }
    }
}
