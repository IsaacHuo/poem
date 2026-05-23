import SwiftUI

struct AnnotationDetailSheet: View {
    let annotation: PoemAnnotation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(PoemeryTheme.separator)
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)

            Text(annotation.term)
                .font(PoemeryTheme.chineseFont(size: 34, relativeTo: .title))
                .foregroundStyle(PoemeryTheme.primaryText)

            Text(annotation.reading.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(PoemeryTheme.accent)

            Text(annotation.summary)
                .font(.headline)
                .foregroundStyle(PoemeryTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(annotation.detail)
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(PoemeryTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(24)
        .background(PoemeryTheme.background)
    }
}
