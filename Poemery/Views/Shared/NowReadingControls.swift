import SwiftUI

struct NowReadingControls: View {
    let isFavorite: Bool
    let isSpeaking: Bool
    let onFavorite: () -> Void
    let onSpeak: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundStyle(isFavorite ? PoemeryTheme.accent : PoemeryTheme.primaryText)
            }
            Button(action: onSpeak) {
                Image(systemName: isSpeaking ? "pause.fill" : "speaker.wave.2.fill")
            }
            Button(action: onNext) {
                Image(systemName: "forward.fill")
            }
        }
        .font(.system(size: 27, weight: .semibold))
        .foregroundStyle(PoemeryTheme.primaryText)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(PoemeryTheme.surface.opacity(0.88), in: Capsule())
    }
}
