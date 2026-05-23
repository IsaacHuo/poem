#if false
import SwiftUI

struct AnnotationPanel: View {
    let annotation: PoemAnnotation
    let line: PoemLine
    let namespace: Namespace.ID
    let onClose: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                panelContent
                    .glassEffect(.regular.tint(PoemeryTheme.paper.opacity(0.10)).interactive(), in: .rect(cornerRadius: 32))
                    .glassEffectID("control-island", in: namespace)
            }
        } else {
            AdaptiveGlassSurface(cornerRadius: 32, isInteractive: true) {
                panelContent
            }
        }
    }

    private var panelContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(annotation.term)
                        .font(PoemeryTheme.chineseFont(size: 27, relativeTo: .title2))
                        .foregroundStyle(PoemeryTheme.ink)
                    Text(annotation.reading)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(PoemeryTheme.ink.opacity(0.48))
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PoemeryTheme.ink.opacity(0.78))
                        .frame(width: 34, height: 34)
                        .background(PoemeryTheme.paper.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭注解")
            }

            Text(annotation.summary)
                .font(PoemeryTheme.chineseFont(size: 15, relativeTo: .body))
                .lineSpacing(5)
                .foregroundStyle(PoemeryTheme.ink.opacity(0.86))

            Divider()
                .overlay(PoemeryTheme.paper.opacity(0.12))

            Text(annotation.detail)
                .font(PoemeryTheme.chineseFont(size: 13.5, relativeTo: .callout))
                .lineSpacing(5)
                .foregroundStyle(PoemeryTheme.ink.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)

            Text(line.text)
                .font(PoemeryTheme.chineseFont(size: 13, relativeTo: .caption))
                .foregroundStyle(PoemeryTheme.pearl.opacity(0.72))
                .padding(.top, 2)
        }
        .padding(22)
    }
}
#endif
