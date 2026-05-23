import SwiftUI

struct Poem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let author: String
    let dynasty: String
    let form: String
    let tags: [String]
    let summary: String
    let lines: [PoemLine]
    let annotations: [PoemAnnotation]
    let sourceURL: URL?
    let artworkStyle: ArtworkStyle

    var fullText: String {
        lines.map(\.text).joined(separator: "\n")
    }

    var displayArtist: String {
        "\(dynasty) · \(author)"
    }

    func annotations(for lineID: PoemLine.ID) -> [PoemAnnotation] {
        annotations.filter { $0.lineID == lineID }
    }
}

struct PoemLine: Identifiable, Codable, Hashable {
    let id: String
    let order: Int
    let text: String
}

struct PoemAnnotation: Identifiable, Codable, Hashable {
    let id: String
    let lineID: PoemLine.ID
    let term: String
    let reading: String
    let summary: String
    let detail: String
}

struct PoemCollection: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let kind: CollectionKind
    let poemIDs: [Poem.ID]
    let accent: ArtworkStyle
}

enum CollectionKind: String, Codable, CaseIterable, Hashable {
    case featured
    case mood
    case author
    case era
    case chart
}

struct PoemCategory: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let tag: String
    let artworkStyle: ArtworkStyle
    let symbol: String
}

struct ArtworkStyle: Codable, Hashable {
    let primaryHex: String
    let secondaryHex: String
    let tertiaryHex: String
    let glyph: String
}

extension ArtworkStyle {
    var primary: Color {
        Color(hex: primaryHex)
    }

    var secondary: Color {
        Color(hex: secondaryHex)
    }

    var tertiary: Color {
        Color(hex: tertiaryHex)
    }

    static let fallback = ArtworkStyle(
        primaryHex: "#E93445",
        secondaryHex: "#FF9F55",
        tertiaryHex: "#24242B",
        glyph: "诗"
    )
}

struct PoemSeedCatalog: Codable {
    let poems: [Poem]
    let collections: [PoemCollection]
    let categories: [PoemCategory]
}

struct SearchResults {
    var poems: [Poem] = []
    var authors: [AuthorResult] = []
    var collections: [PoemCollection] = []

    var isEmpty: Bool {
        poems.isEmpty && authors.isEmpty && collections.isEmpty
    }
}

struct AuthorResult: Identifiable, Hashable {
    let id: String
    let name: String
    let dynasty: String
    let poems: [Poem]
}

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)

        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double

        switch trimmed.count {
        case 8:
            red = Double((value & 0xFF00_0000) >> 24) / 255
            green = Double((value & 0x00FF_0000) >> 16) / 255
            blue = Double((value & 0x0000_FF00) >> 8) / 255
            alpha = Double(value & 0x0000_00FF) / 255
        case 6:
            red = Double((value & 0xFF0000) >> 16) / 255
            green = Double((value & 0x00FF00) >> 8) / 255
            blue = Double(value & 0x0000FF) / 255
            alpha = 1
        default:
            red = 0.91
            green = 0.20
            blue = 0.27
            alpha = 1
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
