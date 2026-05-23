import SwiftUI

struct AdaptiveGlassSurface<Content: View>: View {
    var cornerRadius: CGFloat = 28
    var tint: Color = PoemeryTheme.paper.opacity(0.10)
    var isInteractive: Bool = false
    var content: Content

    init(
        cornerRadius: CGFloat = 28,
        tint: Color = PoemeryTheme.paper.opacity(0.10),
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.isInteractive = isInteractive
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    glass.interactive(isInteractive),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.8)
                }
                .shadow(color: .black.opacity(0.20), radius: 22, x: 0, y: 14)
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        .regular.tint(tint)
    }
}
