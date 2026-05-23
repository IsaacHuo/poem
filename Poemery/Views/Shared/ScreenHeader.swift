import SwiftUI

struct ScreenHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(alignment: .top) {
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

            Spacer(minLength: 16)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.74, green: 0.81, blue: 0.96), Color(red: 0.48, green: 0.51, blue: 0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("霍")
                    .font(PoemeryTheme.chineseFont(size: 23, relativeTo: .title3))
                    .foregroundStyle(.white)
            }
            .frame(width: 54, height: 54)
            .padding(.top, 2)
        }
    }
}
