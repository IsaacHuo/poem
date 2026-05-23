import SwiftUI

struct SectionTitle: View {
    let title: String
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(PoemeryTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
            }
        }
    }
}
