import SwiftUI

struct SectionTitle: View {
    let title: String
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PoemeryTheme.primaryText)
                .lineLimit(1)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.tertiaryText)
            }
        }
    }
}
