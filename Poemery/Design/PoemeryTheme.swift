import SwiftUI

enum PoemeryTheme {
    static let chineseFontName = "HYWenRunSongYun-U"

    static let accent = Color(red: 0.91, green: 0.13, blue: 0.20)
    static let accentSoft = Color(red: 1.00, green: 0.89, blue: 0.91)
    static let background = Color(red: 0.98, green: 0.98, blue: 0.97)
    static let groupedBackground = Color(red: 0.94, green: 0.94, blue: 0.93)
    static let surface = Color.white
    static let primaryText = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let secondaryText = Color(red: 0.36, green: 0.36, blue: 0.39)
    static let tertiaryText = Color(red: 0.55, green: 0.55, blue: 0.58)
    static let separator = Color.black.opacity(0.08)

    static let paper = Color(red: 0.96, green: 0.93, blue: 0.85)
    static let agedPaper = Color(red: 0.72, green: 0.66, blue: 0.54)
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.11)
    static let deepInk = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let dusk = Color(red: 0.18, green: 0.19, blue: 0.21)
    static let moon = Color(red: 0.76, green: 0.84, blue: 0.86)
    static let vine = Color(red: 0.30, green: 0.42, blue: 0.34)
    static let cinnabar = Color(red: 0.72, green: 0.11, blue: 0.12)
    static let pearl = Color(red: 0.95, green: 0.88, blue: 0.63)

    static let motion = Animation.smooth(duration: 0.42, extraBounce: 0.05)
    static let quickMotion = Animation.smooth(duration: 0.24, extraBounce: 0.03)

    static func chineseFont(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(chineseFontName, size: size, relativeTo: textStyle)
    }
}

extension View {
    func poemeryPressFeedback() -> some View {
        sensoryFeedback(.impact(weight: .light), trigger: UUID())
    }
}
