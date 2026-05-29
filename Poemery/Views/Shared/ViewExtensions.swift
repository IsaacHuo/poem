import SwiftUI

extension View {
    func screenContentPadding() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 132)
    }

    func groupedListBackground(cornerRadius: CGFloat = 22) -> some View {
        background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func glassContainer(cornerRadius: CGFloat, tint: Color, namespace: Namespace.ID, glassID: String) -> some View {
        modifier(GlassContainerModifier(cornerRadius: cornerRadius, tint: tint, namespace: namespace, glassID: glassID))
    }
}
