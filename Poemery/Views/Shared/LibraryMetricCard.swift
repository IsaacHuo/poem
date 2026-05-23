import SwiftUI

struct LibraryMetricCard: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(PoemeryTheme.accent)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PoemeryTheme.primaryText)
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PoemeryTheme.secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
