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

    var displayArtworkStyle: ArtworkStyle {
        ArtworkStyle.displayStyle(
            seed: "\(id)|\(title)",
            baseGlyph: ArtworkStyle.firstCJKGlyph(in: title) ?? artworkStyle.glyph
        )
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

    static func displayStyle(seed: String, baseGlyph: String) -> ArtworkStyle {
        let hash = stableHash(seed)
        let palette = displayPalettes[Int(hash % UInt64(displayPalettes.count))]
        return ArtworkStyle(
            primaryHex: palette.primary,
            secondaryHex: palette.secondary,
            tertiaryHex: palette.tertiary,
            glyph: baseGlyph.isEmpty ? fallback.glyph : baseGlyph
        )
    }

    static func firstCJKGlyph(in value: String) -> String? {
        for scalar in value.unicodeScalars where scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
            return String(scalar)
        }
        return nil
    }

    private static let displayPalettes: [(primary: String, secondary: String, tertiary: String)] = [
        ("#A53B32", "#E6A85F", "#24252D"),
        ("#1F6F78", "#93C8BC", "#263238"),
        ("#584B9C", "#B8A7E8", "#252538"),
        ("#7E365A", "#D99EB3", "#2C2530"),
        ("#2F6658", "#D3B56D", "#232F2D"),
        ("#9E5732", "#E5C56D", "#2D2D27"),
        ("#3C5E8D", "#AEC8E6", "#242C3A"),
        ("#7A4231", "#D58E70", "#302827"),
        ("#316A74", "#D1C17C", "#243233"),
        ("#8B3C63", "#D6A5C2", "#2B2632"),
        ("#4F5F38", "#D4C989", "#293025"),
        ("#8C4A39", "#DFB28A", "#302A28"),
        ("#355B72", "#A9D0CA", "#242E36"),
        ("#694A86", "#D2B0DF", "#2C2834"),
        ("#A44747", "#E5B066", "#2B2830"),
        ("#3B6B54", "#AFCB9E", "#253228"),
        ("#6F4C35", "#D9A35F", "#2C2925"),
        ("#46588C", "#BFB7E7", "#252A3A")
    ]

    private static func stableHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return hash
    }
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
