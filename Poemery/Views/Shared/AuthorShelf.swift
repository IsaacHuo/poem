import SwiftUI

struct AuthorShelf: View {
    let authors: [AuthorResult]
    let onOpenAuthor: (AuthorResult) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "诗人精选")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(authors) { author in
                        Button {
                            onOpenAuthor(author)
                        } label: {
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(PoemeryTheme.groupedBackground)
                                    Text(String(author.name.prefix(1)))
                                        .font(PoemeryTheme.chineseFont(size: 32, relativeTo: .title))
                                        .foregroundStyle(PoemeryTheme.accent)
                                }
                                    .frame(width: 64, height: 64)

                                Text(author.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PoemeryTheme.primaryText)
                                Text("\(author.dynasty) · \(author.poems.count) 首")
                                    .font(.caption)
                                    .foregroundStyle(PoemeryTheme.secondaryText)
                            }
                            .frame(width: 92)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
        }
    }
}
