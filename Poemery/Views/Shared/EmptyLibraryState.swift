import SwiftUI

struct EmptyLibraryState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.isEmpty ? "暂无内容" : title)
                .font(.headline)
                .foregroundStyle(PoemeryTheme.primaryText)
            Text(subtitle.isEmpty ? "内容会在这里出现。" : subtitle)
                .font(.subheadline)
                .foregroundStyle(PoemeryTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(PoemeryTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
