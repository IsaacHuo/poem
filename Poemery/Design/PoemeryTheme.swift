import SwiftUI
import UIKit

enum PoemeryTheme {
    static let chineseFontName = "STKaiti"

    static let accent = Color(uiColor: .systemRed)
    static let accentSoft = Color(uiColor: .systemRed).opacity(0.12)
    static let background = Color(red: 0.965, green: 0.952, blue: 0.918)
    static let groupedBackground = Color(red: 0.985, green: 0.976, blue: 0.948)
    static let surface = Color(red: 0.992, green: 0.986, blue: 0.965)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = Color(uiColor: .secondaryLabel)
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let separator = Color(uiColor: .separator).opacity(0.32)

    static let paper = Color(red: 0.96, green: 0.93, blue: 0.85)
    static let warmPaper = Color(red: 0.98, green: 0.94, blue: 0.82)
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
