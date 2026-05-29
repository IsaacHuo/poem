import Foundation
import Observation

@MainActor
@Observable
final class PoemLibraryStore {
    private(set) var poems: [Poem]
    private(set) var collections: [PoemCollection]
    private(set) var categories: [PoemCategory]

    private var poemsByID: [Poem.ID: Poem]
    private var poemOrderByID: [Poem.ID: Int]
    private var poemScoreByID: [Poem.ID: Int]
    private var popularPoemsCache: [Poem]
    private var authorsCache: [AuthorResult]
    private var poemSearchTextByID: [Poem.ID: String]?
    private var collectionSearchTextByID: [PoemCollection.ID: String]?
    private var authorSearchTextByID: [AuthorResult.ID: String]?
    private var formsCache: [String]
    private var dynastiesCache: [String]

    convenience init(catalog: PoemSeedCatalog = PoemLibraryStore.loadBundledCatalog()) {
        self.init(catalog: catalog, index: PoemLibraryIndex(catalog: catalog))
    }

    private init(catalog: PoemSeedCatalog, index: PoemLibraryIndex) {
        self.poems = catalog.poems
        self.collections = catalog.collections
        self.categories = catalog.categories
        self.poemsByID = index.poemsByID
        self.poemOrderByID = index.poemOrderByID
        self.poemScoreByID = index.poemScoreByID
        self.popularPoemsCache = index.popularPoems
        self.authorsCache = index.authors
        self.poemSearchTextByID = nil
        self.collectionSearchTextByID = nil
        self.authorSearchTextByID = nil
        self.formsCache = index.forms
        self.dynastiesCache = index.dynasties
    }

    nonisolated static func loadBundled() async throws -> PoemLibraryStore {
        let url = try bundledCatalogURL()
        let indexedCatalog = try await Task.detached(priority: .userInitiated) {
            let catalog = try decodeCatalog(at: url)
            return IndexedPoemCatalog(catalog: catalog, index: PoemLibraryIndex(catalog: catalog))
        }.value

        return await MainActor.run {
            PoemLibraryStore(catalog: indexedCatalog.catalog, index: indexedCatalog.index)
        }
    }

    func poem(id: Poem.ID) -> Poem? {
        poemsByID[id]
    }

    func poems(for collection: PoemCollection) -> [Poem] {
        collection.poemIDs.compactMap { poemsByID[$0] }
    }

    func poems(matching category: PoemCategory) -> [Poem] {
        poems.filter { poem in
            poem.tags.contains(category.tag) || poem.dynasty == category.tag || poem.form == category.tag || poem.author == category.tag
        }
    }

    func collection(id: PoemCollection.ID) -> PoemCollection? {
        collections.first { $0.id == id }
    }

    func authors() -> [AuthorResult] {
        authorsCache
    }

    func author(id: AuthorResult.ID) -> AuthorResult? {
        authorsCache.first { $0.id == id }
    }

    func author(for poem: Poem) -> AuthorResult? {
        authorsCache.first { $0.name == poem.author }
    }

    func popularPoems(limit: Int) -> [Poem] {
        Array(popularPoemsCache.prefix(limit))
    }

    func popularAuthors(limit: Int) -> [AuthorResult] {
        Array(authorsCache.prefix(limit))
    }

    func poems(forTheme theme: String, limit: Int? = nil) -> [Poem] {
        let normalizedTheme = Self.normalizedSearchText(theme)
        let matches = popularSortedPoems(
            poems.filter { poem in
                poem.themes.contains { Self.normalizedSearchText($0).localizedStandardContains(normalizedTheme) }
                    || poem.tags.contains { Self.normalizedSearchText($0).localizedStandardContains(normalizedTheme) }
                    || Self.normalizedSearchText(poem.dynasty).localizedStandardContains(normalizedTheme)
                    || Self.normalizedSearchText(poem.form).localizedStandardContains(normalizedTheme)
            }
        )
        guard let limit else {
            return matches
        }
        return Array(matches.prefix(limit))
    }

    func poems(forDynasty dynasty: String, limit: Int? = nil) -> [Poem] {
        limited(popularSortedPoems(poems.filter { $0.dynasty == dynasty }), limit: limit)
    }

    func poems(forForm form: String, limit: Int? = nil) -> [Poem] {
        limited(popularSortedPoems(poems.filter { $0.form == form || $0.tags.contains(form) }), limit: limit)
    }

    func forms(limit: Int) -> [String] {
        Array(formsCache.prefix(limit))
    }

    func dynasties() -> [String] {
        dynastiesCache
    }

    func search(_ query: String) -> SearchResults {
        let tokenVariants = Self.searchTokenVariants(query)

        guard !tokenVariants.isEmpty else {
            return SearchResults()
        }

        let searchIndex = self.searchIndex()
        let matchedPoems = poems.filter { poem in
            guard let searchable = searchIndex.poems[poem.id] else {
                return false
            }
            return tokenVariants.allSatisfy { variants in
                variants.contains { searchable.localizedStandardContains($0) }
            }
        }

        let matchedCollections = collections.filter { collection in
            guard let searchable = searchIndex.collections[collection.id] else {
                return false
            }
            return tokenVariants.allSatisfy { variants in
                variants.contains { searchable.localizedStandardContains($0) }
            }
        }

        let matchedAuthors = authors().filter { author in
            guard let searchable = searchIndex.authors[author.id] else {
                return false
            }
            return tokenVariants.allSatisfy { variants in
                variants.contains { searchable.localizedStandardContains($0) }
            }
        }

        return SearchResults(
            poems: popularSortedPoems(matchedPoems),
            authors: matchedAuthors,
            collections: matchedCollections
        )
    }

    private func popularSortedPoems(_ candidates: [Poem]) -> [Poem] {
        PoemLibraryIndex.popularSortedPoems(
            candidates,
            poemOrderByID: poemOrderByID,
            poemScoreByID: poemScoreByID
        )
    }

    private func limited(_ poems: [Poem], limit: Int?) -> [Poem] {
        guard let limit else {
            return poems
        }
        return Array(poems.prefix(limit))
    }

    private func searchIndex() -> PoemSearchIndex {
        if let poemSearchTextByID,
           let collectionSearchTextByID,
           let authorSearchTextByID {
            return PoemSearchIndex(
                poems: poemSearchTextByID,
                collections: collectionSearchTextByID,
                authors: authorSearchTextByID
            )
        }

        let index = PoemSearchIndex(poems: poems, collections: collections, authors: authorsCache)
        poemSearchTextByID = index.poems
        collectionSearchTextByID = index.collections
        authorSearchTextByID = index.authors
        return index
    }

    nonisolated static func normalizedSearchText(_ value: String) -> String {
        let lowered = value.lowercased()
        let folded = foldedSearchText(lowered)
        let aliases = poemerySearchAliases.reduce(into: [String]()) { result, alias in
            if lowered.localizedStandardContains(alias.key) || folded.localizedStandardContains(alias.key) {
                result.append(alias.value)
            }
        }
        return ([lowered, folded] + aliases).joined(separator: " ")
    }

    nonisolated static func foldedSearchText(_ value: String) -> String {
        String(value.lowercased().map { poemerySearchCharacterMap[$0] ?? $0 })
    }

    nonisolated private static func searchTokenVariants(_ query: String) -> [[String]] {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(separator: " ")
            .map { token in
                let raw = String(token)
                let normalized = normalizedSearchText(raw)
                    .split(separator: " ")
                    .map(String.init)
                return Array(Set([raw] + normalized))
            }
            .filter { !$0.isEmpty }
    }

    private static func loadBundledCatalog() -> PoemSeedCatalog {
        do {
            return try decodeCatalog(at: bundledCatalogURL())
        } catch {
            assertionFailure("Failed to load PoemsSeed.json: \(error)")
            return fallbackCatalog
        }
    }

    nonisolated private static func bundledCatalogURL() throws -> URL {
        guard let url = Bundle.main.url(forResource: "PoemsSeed", withExtension: "json") else {
            throw PoemLibraryLoadError.missingBundledCatalog
        }
        return url
    }

    nonisolated private static func decodeCatalog(at url: URL) throws -> PoemSeedCatalog {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PoemSeedCatalog.self, from: data)
        } catch {
            throw PoemLibraryLoadError.failedToReadBundledCatalog(String(describing: error))
        }
    }

    private static let fallbackCatalog = PoemSeedCatalog(
        poems: [
            Poem(
                id: "fallback-jing-ye-si",
                title: "静夜思",
                author: "李白",
                dynasty: "唐",
                form: "五言绝句",
                tags: ["唐诗", "思乡"],
                summary: "以月光写乡愁。",
                lines: [
                    PoemLine(id: "fallback-jing-ye-si-1", order: 0, text: "床前明月光，"),
                    PoemLine(id: "fallback-jing-ye-si-2", order: 1, text: "疑是地上霜。"),
                    PoemLine(id: "fallback-jing-ye-si-3", order: 2, text: "举头望明月，"),
                    PoemLine(id: "fallback-jing-ye-si-4", order: 3, text: "低头思故乡。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: .fallback
            ),
            Poem(
                id: "fallback-chun-xiao",
                title: "春晓",
                author: "孟浩然",
                dynasty: "唐",
                form: "五言绝句",
                tags: ["唐诗", "春景"],
                summary: "春晨醒来，借风雨落花写自然流转。",
                lines: [
                    PoemLine(id: "fallback-chun-xiao-1", order: 0, text: "春眠不觉晓，"),
                    PoemLine(id: "fallback-chun-xiao-2", order: 1, text: "处处闻啼鸟。"),
                    PoemLine(id: "fallback-chun-xiao-3", order: 2, text: "夜来风雨声，"),
                    PoemLine(id: "fallback-chun-xiao-4", order: 3, text: "花落知多少。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#2F6658", secondaryHex: "#D3B56D", tertiaryHex: "#232F2D", glyph: "春")
            ),
            Poem(
                id: "fallback-deng-guan-que-lou",
                title: "登鹳雀楼",
                author: "王之涣",
                dynasty: "唐",
                form: "五言绝句",
                tags: ["唐诗", "哲理"],
                summary: "以登临视野写胸襟与进取。",
                lines: [
                    PoemLine(id: "fallback-deng-guan-que-lou-1", order: 0, text: "白日依山尽，"),
                    PoemLine(id: "fallback-deng-guan-que-lou-2", order: 1, text: "黄河入海流。"),
                    PoemLine(id: "fallback-deng-guan-que-lou-3", order: 2, text: "欲穷千里目，"),
                    PoemLine(id: "fallback-deng-guan-que-lou-4", order: 3, text: "更上一层楼。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#355B72", secondaryHex: "#A9D0CA", tertiaryHex: "#242E36", glyph: "楼")
            )
        ],
        collections: [
            PoemCollection(
                id: "fallback-classics",
                title: "入门三首",
                subtitle: "先从熟悉的诗开始",
                kind: .featured,
                poemIDs: ["fallback-jing-ye-si", "fallback-chun-xiao", "fallback-deng-guan-que-lou"],
                accent: .fallback
            )
        ],
        categories: [
            PoemCategory(
                id: "fallback-category-tang",
                title: "唐诗",
                subtitle: "入门精选",
                tag: "唐诗",
                artworkStyle: .fallback,
                symbol: "book.closed.fill"
            )
        ]
    )
}

enum PoemLibraryLoadError: LocalizedError {
    case missingBundledCatalog
    case failedToReadBundledCatalog(String)

    var errorDescription: String? {
        switch self {
        case .missingBundledCatalog:
            "Missing PoemsSeed.json from the app bundle."
        case .failedToReadBundledCatalog(let reason):
            "Failed to read PoemsSeed.json: \(reason)"
        }
    }
}

private struct IndexedPoemCatalog: Sendable {
    let catalog: PoemSeedCatalog
    let index: PoemLibraryIndex
}

private struct PoemLibraryIndex: Sendable {
    let poemsByID: [Poem.ID: Poem]
    let poemOrderByID: [Poem.ID: Int]
    let poemScoreByID: [Poem.ID: Int]
    let popularPoems: [Poem]
    let authors: [AuthorResult]
    let forms: [String]
    let dynasties: [String]

    init(catalog: PoemSeedCatalog) {
        let poemOrderByID = Dictionary(uniqueKeysWithValues: catalog.poems.enumerated().map { index, poem in
            (poem.id, index)
        })
        let poemScoreByID = Dictionary(uniqueKeysWithValues: catalog.poems.map { poem in
            (poem.id, Self.popularityScore(for: poem))
        })
        let popularPoems = Self.popularSortedPoems(
            catalog.poems,
            poemOrderByID: poemOrderByID,
            poemScoreByID: poemScoreByID
        )
        let authors = Self.makeAuthors(
            poems: catalog.poems,
            poemOrderByID: poemOrderByID,
            poemScoreByID: poemScoreByID
        )

        self.poemsByID = Dictionary(uniqueKeysWithValues: catalog.poems.map { ($0.id, $0) })
        self.poemOrderByID = poemOrderByID
        self.poemScoreByID = poemScoreByID
        self.popularPoems = popularPoems
        self.authors = authors
        self.forms = Self.sortedValues(poems: catalog.poems, keyPath: \.form)
        self.dynasties = Self.sortedValues(poems: catalog.poems, keyPath: \.dynasty)
    }

    static func popularSortedPoems(
        _ candidates: [Poem],
        poemOrderByID: [Poem.ID: Int],
        poemScoreByID: [Poem.ID: Int]
    ) -> [Poem] {
        candidates.sorted { lhs, rhs in
            let lhsScore = poemScoreByID[lhs.id] ?? popularityScore(for: lhs)
            let rhsScore = poemScoreByID[rhs.id] ?? popularityScore(for: rhs)

            if lhsScore == rhsScore {
                return poemOrder(for: lhs, poemOrderByID: poemOrderByID) < poemOrder(for: rhs, poemOrderByID: poemOrderByID)
            }

            return lhsScore > rhsScore
        }
    }

    private static func makeAuthors(
        poems: [Poem],
        poemOrderByID: [Poem.ID: Int],
        poemScoreByID: [Poem.ID: Int]
    ) -> [AuthorResult] {
        let authors = Dictionary(grouping: poems, by: \.author)
            .map { author, poems in
                let dynasty = poems.first?.dynasty ?? ""
                return AuthorResult(
                    id: "\(dynasty)-\(author)",
                    name: author,
                    dynasty: dynasty,
                    poems: popularSortedPoems(
                        poems,
                        poemOrderByID: poemOrderByID,
                        poemScoreByID: poemScoreByID
                    )
                )
            }

        let authorScoreByID = Dictionary(uniqueKeysWithValues: authors.map { author in
            (author.id, popularityScore(for: author, poemScoreByID: poemScoreByID))
        })

        return authors.sorted { lhs, rhs in
            let lhsScore = authorScoreByID[lhs.id] ?? 0
            let rhsScore = authorScoreByID[rhs.id] ?? 0

            if lhsScore == rhsScore {
                return firstPoemOrder(in: lhs, poemOrderByID: poemOrderByID) < firstPoemOrder(in: rhs, poemOrderByID: poemOrderByID)
            }

            return lhsScore > rhsScore
        }
    }

    private static func sortedValues(poems: [Poem], keyPath: KeyPath<Poem, String>) -> [String] {
        Dictionary(grouping: poems, by: { $0[keyPath: keyPath] })
            .map { value, poems in (value, poems.count) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.localizedCompare(rhs.0) == .orderedAscending
                }
                return lhs.1 > rhs.1
            }
            .map(\.0)
    }

    private static func popularityScore(for author: AuthorResult, poemScoreByID: [Poem.ID: Int]) -> Int {
        let poemScore = author.poems.compactMap { poemScoreByID[$0.id] }.max() ?? 0
        let authorScore = authorPopularity[author.name] ?? 0
        return poemScore + authorScore + min(author.poems.count, 60)
    }

    private static func popularityScore(for poem: Poem) -> Int {
        let normalizedTitle = PoemLibraryStore.foldedSearchText(poem.title)
        let titleScore = popularTitleKeywords.reduce(0) { score, keyword in
            normalizedTitle.contains(keyword.title) ? max(score, keyword.score) : score
        }
        let authorScore = authorPopularity[poem.author] ?? 0
        let tagScore = poem.tags.reduce(0) { score, tag in
            score + (classicTagPopularity[tag] ?? 0)
        }

        return titleScore + authorScore + min(tagScore, 120)
    }

    private static func firstPoemOrder(in author: AuthorResult, poemOrderByID: [Poem.ID: Int]) -> Int {
        author.poems.map { poemOrder(for: $0, poemOrderByID: poemOrderByID) }.min() ?? Int.max
    }

    private static func poemOrder(for poem: Poem, poemOrderByID: [Poem.ID: Int]) -> Int {
        poemOrderByID[poem.id] ?? Int.max
    }

}

private struct PoemSearchIndex {
    let poems: [Poem.ID: String]
    let collections: [PoemCollection.ID: String]
    let authors: [AuthorResult.ID: String]

    init(poems: [Poem], collections: [PoemCollection], authors: [AuthorResult]) {
        self.poems = Dictionary(uniqueKeysWithValues: poems.map { poem in
            (poem.id, Self.searchText(for: poem))
        })
        self.collections = Dictionary(uniqueKeysWithValues: collections.map { collection in
            (collection.id, Self.searchText(for: collection))
        })
        self.authors = Dictionary(uniqueKeysWithValues: authors.map { author in
            (author.id, Self.searchText(for: author))
        })
    }

    init(poems: [Poem.ID: String], collections: [PoemCollection.ID: String], authors: [AuthorResult.ID: String]) {
        self.poems = poems
        self.collections = collections
        self.authors = authors
    }

    private static func searchText(for poem: Poem) -> String {
        let primaryText = PoemLibraryStore.normalizedSearchText([
            poem.title,
            poem.author,
            poem.dynasty,
            poem.form,
            poem.tags.joined(separator: " "),
            poem.editorialSummary,
            poem.themes.joined(separator: " "),
            poem.sourceName,
            poem.sourceLicense,
            poem.canonicalKey
        ]
        .joined(separator: " "))
        return [
            primaryText,
            poem.fullText.lowercased()
        ].joined(separator: " ")
    }

    private static func searchText(for collection: PoemCollection) -> String {
        PoemLibraryStore.normalizedSearchText("\(collection.title) \(collection.subtitle)")
    }

    private static func searchText(for author: AuthorResult) -> String {
        PoemLibraryStore.normalizedSearchText("\(author.name) \(author.dynasty) \(author.introduction)")
    }
}

private extension PoemLibraryIndex {
    static let authorPopularity: [String: Int] = [
        "李白": 900,
        "杜甫": 880,
        "苏轼": 850,
        "蘇軾": 850,
        "白居易": 820,
        "王维": 800,
        "王維": 800,
        "李商隐": 780,
        "李商隱": 780,
        "辛弃疾": 760,
        "辛棄疾": 760,
        "李清照": 740,
        "柳永": 720,
        "陆游": 700,
        "陸游": 700,
        "王昌龄": 680,
        "王昌齡": 680,
        "孟浩然": 660,
        "杜牧": 640,
        "王之涣": 620,
        "王之渙": 620,
        "关汉卿": 600,
        "關漢卿": 600
    ]

    private static let popularTitleKeywords: [(title: String, score: Int)] = [
        ("静夜思", 1000),
        ("将进酒", 980),
        ("春晓", 960),
        ("登鹳雀楼", 940),
        ("锦瑟", 920),
        ("水调歌头", 900),
        ("念奴娇", 880),
        ("雨霖铃", 860),
        ("声声慢", 840),
        ("青玉案", 820),
        ("江城子", 800),
        ("虞美人", 780),
        ("赤壁", 760)
    ]

    private static let classicTagPopularity: [String: Int] = [
        "唐诗三百首": 80,
        "宋词三百首": 80,
        "初中古诗": 50,
        "高中古诗": 50,
        "小学古诗": 50,
        "经典": 40,
        "思乡": 30,
        "爱国": 30,
        "哲理": 24,
        "抒情": 20
    ]

}

private let poemerySearchAliases: [String: String] = [
    "东坡": "苏轼 蘇軾 子瞻",
    "蘇軾": "苏轼 东坡 子瞻",
    "苏轼": "蘇軾 东坡 子瞻",
    "易安": "李清照",
    "稼轩": "辛弃疾 辛棄疾",
    "辛棄疾": "辛弃疾 稼轩",
    "青莲": "李白",
    "太白": "李白",
    "子美": "杜甫",
    "香山": "白居易",
    "摩诘": "王维 王維",
    "王維": "王维 摩诘",
    "关汉卿": "關漢卿",
    "關漢卿": "关汉卿",
    "马致远": "馬致遠",
    "馬致遠": "马致远"
]

private let poemerySearchCharacterMap: [Character: Character] = [
    "靜": "静",
    "將": "将",
    "進": "进",
    "錦": "锦",
    "曉": "晓",
    "鸛": "鹳",
    "樓": "楼",
    "調": "调",
    "頭": "头",
    "聲": "声",
    "嬌": "娇",
    "鈴": "铃",
    "體": "体",
    "詩": "诗",
    "詞": "词",
    "蘇": "苏",
    "軾": "轼",
    "棄": "弃",
    "陸": "陆",
    "關": "关",
    "漢": "汉",
    "馬": "马",
    "遠": "远",
    "維": "维",
    "齡": "龄",
    "渙": "涣",
    "隱": "隐",
    "與": "与",
    "國": "国",
    "愛": "爱",
    "鄉": "乡",
    "歸": "归",
    "風": "风",
    "雲": "云",
    "夢": "梦",
    "舊": "旧",
    "書": "书",
    "萬": "万",
    "長": "长",
    "門": "门"
]
