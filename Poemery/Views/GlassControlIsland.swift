#if false
import SwiftUI

struct GlassControlIsland: View {
    let isSpeaking: Bool
    let isMemorizing: Bool
    let isAnnotationVisible: Bool
    let isCardVisible: Bool
    let namespace: Namespace.ID
    let onSpeak: () -> Void
    let onAnnotate: () -> Void
    let onMemorize: () -> Void
    let onCard: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                islandContent
                    .padding(10)
                    .glassEffect(.regular.tint(PoemeryTheme.paper.opacity(0.08)).interactive(), in: .rect(cornerRadius: 30))
                    .glassEffectID("control-island", in: namespace)
            }
        } else {
            AdaptiveGlassSurface(cornerRadius: 30, isInteractive: true) {
                islandContent
                    .padding(10)
            }
        }
    }

    private var islandContent: some View {
        HStack(spacing: 8) {
            ControlButton(
                symbol: isSpeaking ? "pause.fill" : "waveform",
                title: isSpeaking ? "暂停" : "朗读",
                isActive: isSpeaking,
                action: onSpeak
            )

            ControlButton(
                symbol: "text.magnifyingglass",
                title: "注解",
                isActive: isAnnotationVisible,
                action: onAnnotate
            )

            ControlButton(
                symbol: "eye.slash",
                title: "背诵",
                isActive: isMemorizing,
                action: onMemorize
            )

            ControlButton(
                symbol: "rectangle.portrait.on.rectangle.portrait",
                title: "诗笺",
                isActive: isCardVisible,
                action: onCard
            )
        }
        .frame(maxWidth: .infinity)
    }
}
#endif

private struct ControlButton: View {
    let symbol: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24, height: 22)
                Text(title)
                    .font(PoemeryTheme.chineseFont(size: 11, relativeTo: .caption2))
            }
            .foregroundStyle(isActive ? PoemeryTheme.deepInk : PoemeryTheme.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isActive {
                    Capsule()
                        .fill(PoemeryTheme.paper.opacity(0.78))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
