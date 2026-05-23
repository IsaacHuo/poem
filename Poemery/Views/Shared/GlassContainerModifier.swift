import SwiftUI

struct GlassContainerModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let namespace: Namespace.ID
    let glassID: String

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                content
                    .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
                    .glassEffectID(glassID, in: namespace)
            }
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.62), lineWidth: 0.8)
                }
        }
    }
}

#Preview {
    ContentView()
}
