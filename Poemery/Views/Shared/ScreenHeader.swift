import SwiftUI

struct ScreenHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PoemeryTheme.primaryText)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PoemeryTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
