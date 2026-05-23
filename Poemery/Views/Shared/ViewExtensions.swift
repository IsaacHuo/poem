import SwiftUI

extension View {
    func screenContentPadding() -> some View {
        self
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 40)
    }

    func glassContainer(cornerRadius: CGFloat, tint: Color, namespace: Namespace.ID, glassID: String) -> some View {
        modifier(GlassContainerModifier(cornerRadius: cornerRadius, tint: tint, namespace: namespace, glassID: glassID))
    }
}
