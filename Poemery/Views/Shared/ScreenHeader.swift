import SwiftUI

struct ScreenHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(PoemeryTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PoemeryTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
