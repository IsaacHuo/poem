import SwiftUI

struct Poem: Identifiable, Codable, Hashable, Sendable {
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
    let sourceName: String
    let sourceLicense: String
    let editorialSummary: String
    let themes: [String]
    let difficulty: Int
    let canonicalKey: String
    let searchMatch: SearchMatchSnippet?

    init(
        id: String,
        title: String,
        author: String,
        dynasty: String,
        form: String,
        tags: [String],
        summary: String,
        lines: [PoemLine],
        annotations: [PoemAnnotation],
        sourceURL: URL?,
        artworkStyle: ArtworkStyle,
        sourceName: String = "chinese-poetry/chinese-poetry",
        sourceLicense: String = "MIT",
        editorialSummary: String? = nil,
        themes: [String]? = nil,
        difficulty: Int? = nil,
        canonicalKey: String? = nil,
        searchMatch: SearchMatchSnippet? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.dynasty = dynasty
        self.form = form
        self.tags = tags
        self.summary = summary
        self.lines = lines
        self.annotations = annotations
        self.sourceURL = sourceURL
        self.artworkStyle = artworkStyle
        self.sourceName = sourceName.isEmpty ? Self.defaultSourceName(tags: tags, dynasty: dynasty, form: form) : sourceName
        self.sourceLicense = sourceLicense
        self.editorialSummary = editorialSummary ?? Self.defaultEditorialSummary(
            title: title,
            author: author,
            form: form,
            tags: tags,
            summary: summary
        )
        self.themes = themes?.isEmpty == false ? themes ?? [] : Self.defaultThemes(tags: tags, dynasty: dynasty, form: form)
        self.difficulty = difficulty ?? Self.defaultDifficulty(form: form, lines: lines)
        self.canonicalKey = canonicalKey ?? Self.defaultCanonicalKey(dynasty: dynasty, author: author, title: title)
        self.searchMatch = searchMatch
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case dynasty
        case form
        case tags
        case summary
        case lines
        case annotations
        case sourceURL
        case artworkStyle
        case sourceName
        case sourceLicense
        case editorialSummary
        case themes
        case difficulty
        case canonicalKey
        case searchMatch
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let title = try container.decode(String.self, forKey: .title)
        let author = try container.decode(String.self, forKey: .author)
        let dynasty = try container.decode(String.self, forKey: .dynasty)
        let form = try container.decode(String.self, forKey: .form)
        let tags = try container.decode([String].self, forKey: .tags)
        let summary = try container.decode(String.self, forKey: .summary)
        let lines = try container.decodeIfPresent([PoemLine].self, forKey: .lines) ?? []
        let annotations = try container.decodeIfPresent([PoemAnnotation].self, forKey: .annotations) ?? []
        let sourceURL = try container.decodeIfPresent(URL.self, forKey: .sourceURL)
        let artworkStyle = try container.decode(ArtworkStyle.self, forKey: .artworkStyle)

        self.init(
            id: id,
            title: title,
            author: author,
            dynasty: dynasty,
            form: form,
            tags: tags,
            summary: summary,
            lines: lines,
            annotations: annotations,
            sourceURL: sourceURL,
            artworkStyle: artworkStyle,
            sourceName: try container.decodeIfPresent(String.self, forKey: .sourceName) ?? Self.defaultSourceName(tags: tags, dynasty: dynasty, form: form),
            sourceLicense: try container.decodeIfPresent(String.self, forKey: .sourceLicense) ?? "MIT",
            editorialSummary: try container.decodeIfPresent(String.self, forKey: .editorialSummary),
            themes: try container.decodeIfPresent([String].self, forKey: .themes),
            difficulty: try container.decodeIfPresent(Int.self, forKey: .difficulty),
            canonicalKey: try container.decodeIfPresent(String.self, forKey: .canonicalKey),
            searchMatch: try container.decodeIfPresent(SearchMatchSnippet.self, forKey: .searchMatch)
        )
    }

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

    func withSearchMatch(_ searchMatch: SearchMatchSnippet?) -> Poem {
        Poem(
            id: id,
            title: title,
            author: author,
            dynasty: dynasty,
            form: form,
            tags: tags,
            summary: summary,
            lines: lines,
            annotations: annotations,
            sourceURL: sourceURL,
            artworkStyle: artworkStyle,
            sourceName: sourceName,
            sourceLicense: sourceLicense,
            editorialSummary: editorialSummary,
            themes: themes,
            difficulty: difficulty,
            canonicalKey: canonicalKey,
            searchMatch: searchMatch
        )
    }

    private static func defaultThemes(tags: [String], dynasty: String, form: String) -> [String] {
        var values = [dynasty, form]
        values.append(contentsOf: tags.prefix(4))
        return Array(NSOrderedSet(array: values).compactMap { $0 as? String }.prefix(6))
    }

    private static func defaultDifficulty(form: String, lines: [PoemLine]) -> Int {
        if form == "曲" || lines.count > 12 {
            return 4
        }
        if form == "词" || lines.count > 8 {
            return 3
        }
        return 2
    }

    private static func defaultCanonicalKey(dynasty: String, author: String, title: String) -> String {
        "\(dynasty)|\(author)|\(title)"
    }

    private static func defaultSourceName(tags: [String], dynasty: String, form: String) -> String {
        if tags.contains("唐诗三百首") {
            return "chinese-poetry/chinese-poetry · 唐诗三百首"
        }
        if tags.contains("宋词三百首") {
            return "chinese-poetry/chinese-poetry · 宋词三百首"
        }
        if tags.contains("元曲") || dynasty == "元" || form == "曲" {
            return "chinese-poetry/chinese-poetry · 元曲"
        }
        if tags.contains("论语") {
            return "chinese-poetry/chinese-poetry · 论语"
        }
        if tags.contains("诗经") {
            return "chinese-poetry/chinese-poetry · 诗经"
        }
        if tags.contains("四书五经") {
            return "chinese-poetry/chinese-poetry · 四书五经"
        }
        return "chinese-poetry/chinese-poetry"
    }

    private static func defaultEditorialSummary(
        title: String,
        author: String,
        form: String,
        tags: [String],
        summary: String
    ) -> String {
        let sourceTags = ["唐诗三百首", "宋词三百首", "唐诗", "宋词", "元曲"]
        let themeText = tags.first { !sourceTags.contains($0) } ?? form
        if !themeText.isEmpty {
            return "\(author)《\(title)》可从\(themeText)与\(form)的线索继续阅读。"
        }
        return summary
    }
}

struct PoemLine: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let order: Int
    let text: String
}

struct PoemAnnotation: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let lineID: PoemLine.ID
    let term: String
    let reading: String
    let summary: String
    let detail: String
}

struct PoemCollection: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let kind: CollectionKind
    let poemCount: Int
    let poemIDs: [Poem.ID]
    let accent: ArtworkStyle

    init(
        id: String,
        title: String,
        subtitle: String,
        kind: CollectionKind,
        poemCount: Int? = nil,
        poemIDs: [Poem.ID],
        accent: ArtworkStyle
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.poemCount = poemCount ?? poemIDs.count
        self.poemIDs = poemIDs
        self.accent = accent
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case kind
        case poemCount
        case poemIDs
        case accent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let poemIDs = try container.decodeIfPresent([Poem.ID].self, forKey: .poemIDs) ?? []

        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decode(String.self, forKey: .subtitle)
        self.kind = try container.decode(CollectionKind.self, forKey: .kind)
        self.poemCount = try container.decodeIfPresent(Int.self, forKey: .poemCount) ?? poemIDs.count
        self.poemIDs = poemIDs
        self.accent = try container.decode(ArtworkStyle.self, forKey: .accent)
    }
}

enum CollectionKind: String, Codable, CaseIterable, Hashable, Sendable {
    case featured
    case mood
    case author
    case era
    case chart
}

struct PoemCategory: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let tag: String
    let artworkStyle: ArtworkStyle
    let symbol: String
}

struct PoemKeyword: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
    let count: Int
    let poemIDs: [Poem.ID]
}

struct PoemListItem: Identifiable, Hashable, Sendable {
    let id: Poem.ID
    let title: String
    let author: String
    let dynasty: String
    let form: String
    let artworkStyle: ArtworkStyle
    let searchMatch: SearchMatchSnippet?

    init(
        id: Poem.ID,
        title: String,
        author: String,
        dynasty: String,
        form: String,
        artworkStyle: ArtworkStyle,
        searchMatch: SearchMatchSnippet? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.dynasty = dynasty
        self.form = form
        self.artworkStyle = artworkStyle
        self.searchMatch = searchMatch
    }

    init(poem: Poem, searchMatch: SearchMatchSnippet? = nil) {
        self.id = poem.id
        self.title = poem.title
        self.author = poem.author
        self.dynasty = poem.dynasty
        self.form = poem.form
        self.artworkStyle = poem.artworkStyle
        self.searchMatch = searchMatch ?? poem.searchMatch
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

    func withSearchMatch(_ searchMatch: SearchMatchSnippet?) -> PoemListItem {
        PoemListItem(
            id: id,
            title: title,
            author: author,
            dynasty: dynasty,
            form: form,
            artworkStyle: artworkStyle,
            searchMatch: searchMatch
        )
    }
}

enum SearchMatchKind: String, Codable, Hashable, Sendable {
    case title
    case author
    case content
    case metadata
}

struct SearchMatchSnippet: Codable, Hashable, Sendable {
    let kind: SearchMatchKind
    let text: String
    let highlightedQuery: String
}

struct ArtworkStyle: Codable, Hashable, Sendable {
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

struct PoemSeedCatalog: Codable, Sendable {
    let poems: [Poem]
    let collections: [PoemCollection]
    let categories: [PoemCategory]
}

struct PoemeryStats: Codable, Sendable {
    let totalPoems: Int
    let totalAuthors: Int
    let totalCollections: Int
    let totalCategories: Int
}

struct PoemeryBootstrapSnapshot: Sendable {
    let stats: PoemeryStats
    let catalog: PoemSeedCatalog
}

struct SearchResults: Sendable {
    var poems: [Poem] = []
    var authors: [AuthorResult] = []
    var collections: [PoemCollection] = []

    var isEmpty: Bool {
        poems.isEmpty && authors.isEmpty && collections.isEmpty
    }
}

struct SearchResultsPage: Sendable {
    var poems: [PoemListItem] = []
    var authors: [AuthorResult] = []
    var collections: [PoemCollection] = []
    var totalPoemCount: Int = 0
    var nextOffset: Int?
    var poemIDs: [Poem.ID] = []

    var isEmpty: Bool {
        poems.isEmpty && authors.isEmpty && collections.isEmpty
    }

    func appending(_ page: SearchResultsPage) -> SearchResultsPage {
        let combinedPoemIDs: [Poem.ID]
        if poemIDs.count == poems.count {
            combinedPoemIDs = poemIDs + page.poemIDs
        } else {
            combinedPoemIDs = poemIDs.isEmpty ? page.poemIDs : poemIDs
        }

        return SearchResultsPage(
            poems: poems + page.poems,
            authors: authors.isEmpty ? page.authors : authors,
            collections: collections.isEmpty ? page.collections : collections,
            totalPoemCount: max(totalPoemCount, page.totalPoemCount),
            nextOffset: page.nextOffset,
            poemIDs: combinedPoemIDs
        )
    }
}

struct PagedPoems: Sendable {
    let poems: [Poem]
    let page: Int
    let totalPages: Int
    let total: Int

    var hasNextPage: Bool {
        page < totalPages
    }

    var nextPage: Int? {
        hasNextPage ? page + 1 : nil
    }
}

struct PagedAuthors: Sendable {
    let authors: [AuthorResult]
    let page: Int
    let totalPages: Int
    let total: Int

    var hasNextPage: Bool {
        page < totalPages
    }

    var nextPage: Int? {
        hasNextPage ? page + 1 : nil
    }
}

struct AuthorResult: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let dynasty: String
    let poemCount: Int
    let poems: [Poem]

    init(id: String, name: String, dynasty: String, poemCount: Int? = nil, poems: [Poem]) {
        self.id = id
        self.name = name
        self.dynasty = dynasty
        self.poemCount = poemCount ?? poems.count
        self.poems = poems
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case dynasty
        case poemCount
        case poems
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let poems = try container.decodeIfPresent([Poem].self, forKey: .poems) ?? []

        self.id = try container.decode(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.dynasty = try container.decode(String.self, forKey: .dynasty)
        self.poemCount = try container.decodeIfPresent(Int.self, forKey: .poemCount) ?? poems.count
        self.poems = poems
    }

    var introduction: String {
        if let introduction = Self.introductions[name] {
            return introduction
        }

        if name == "佚名" {
            return "这类作品作者已不可考，诗库保留原始题名与文本，方便从作品本身继续阅读。"
        }

        let era = dynasty.isEmpty ? "" : "\(dynasty)代"
        let countText = poemCount == 0 ? "暂无收录作品" : "当前诗库收录 \(poemCount) 首作品"
        return "\(era)作者。\(countText)，可从作品列表继续阅读相关作品。"
    }

    private static let introductions: [String: String] = [
        "李白": "李白，唐代诗人，字太白，号青莲居士。其诗想象奔放、语言明朗，后世常称“诗仙”。",
        "杜甫": "杜甫，唐代诗人，字子美。其诗沉郁顿挫，深切记录时代与民生，后世常称“诗圣”。",
        "白居易": "白居易，唐代诗人，字乐天，号香山居士。其诗平易晓畅，重视诗歌对现实生活的关照。",
        "王维": "王维，唐代诗人、画家，字摩诘。其山水田园诗清远闲雅，常见诗画相生的意境。",
        "王維": "王维，唐代诗人、画家，字摩诘。其山水田园诗清远闲雅，常见诗画相生的意境。",
        "孟浩然": "孟浩然，唐代山水田园诗人。其诗多写隐逸、行旅与自然景色，风格清淡自然。",
        "王昌龄": "王昌龄，唐代诗人，擅长七言绝句。其边塞诗气韵雄健，也有细腻含蓄的送别之作。",
        "王昌齡": "王昌龄，唐代诗人，擅长七言绝句。其边塞诗气韵雄健，也有细腻含蓄的送别之作。",
        "王之涣": "王之涣，唐代诗人。作品虽传世不多，却以开阔高远的边塞与登临气象著称。",
        "王之渙": "王之涣，唐代诗人。作品虽传世不多，却以开阔高远的边塞与登临气象著称。",
        "杜牧": "杜牧，唐代诗人，字牧之。其诗俊爽明丽，咏史、写景与抒怀皆有鲜明风致。",
        "李商隐": "李商隐，唐代诗人，字义山。其诗辞采精工、意象繁密，尤以含蓄深婉见长。",
        "李商隱": "李商隐，唐代诗人，字义山。其诗辞采精工、意象繁密，尤以含蓄深婉见长。",
        "苏轼": "苏轼，宋代文学家，字子瞻，号东坡居士。诗词文书画皆工，词风开阔豪放而兼具旷达情怀。",
        "蘇軾": "苏轼，宋代文学家，字子瞻，号东坡居士。诗词文书画皆工，词风开阔豪放而兼具旷达情怀。",
        "柳永": "柳永，宋代词人，原名三变。其词多写都市风物与离情别绪，推动慢词的发展。",
        "李清照": "李清照，宋代词人，号易安居士。其词语言清丽，情感细腻，前后期风格各有深致。",
        "辛弃疾": "辛弃疾，宋代词人，字幼安，号稼轩。其词慷慨沉雄，常寄寓家国抱负与人生感怀。",
        "辛棄疾": "辛弃疾，宋代词人，字幼安，号稼轩。其词慷慨沉雄，常寄寓家国抱负与人生感怀。",
        "陆游": "陆游，宋代诗人，字务观，号放翁。诗作数量丰富，兼具家国情怀与日常生活气息。",
        "陸游": "陆游，宋代诗人，字务观，号放翁。诗作数量丰富，兼具家国情怀与日常生活气息。",
        "关汉卿": "关汉卿，元代杂剧作家、散曲家。其作品关注世情与人物命运，是元曲的重要代表。",
        "關漢卿": "关汉卿，元代杂剧作家、散曲家。其作品关注世情与人物命运，是元曲的重要代表。",
        "马致远": "马致远，元代戏曲家、散曲家。其小令清疏苍凉，常以羁旅与秋思意象见长。",
        "馬致遠": "马致远，元代戏曲家、散曲家。其小令清疏苍凉，常以羁旅与秋思意象见长。"
    ]
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
