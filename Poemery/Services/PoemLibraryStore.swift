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
    private var popularPoemsCache: [Poem]
    private var authorsCache: [AuthorResult]

    init(catalog: PoemSeedCatalog = PoemLibraryStore.loadBundledCatalog()) {
        self.poems = catalog.poems
        self.collections = catalog.collections
        self.categories = catalog.categories
        self.poemsByID = Dictionary(uniqueKeysWithValues: catalog.poems.map { ($0.id, $0) })
        self.poemOrderByID = Dictionary(uniqueKeysWithValues: catalog.poems.enumerated().map { index, poem in
            (poem.id, index)
        })
        self.popularPoemsCache = []
        self.authorsCache = []
        self.popularPoemsCache = popularSortedPoems(catalog.poems)
        self.authorsCache = makeAuthors()
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

    func popularPoems(limit: Int) -> [Poem] {
        Array(popularPoemsCache.prefix(limit))
    }

    func popularAuthors(limit: Int) -> [AuthorResult] {
        Array(authorsCache.prefix(limit))
    }

    private func makeAuthors() -> [AuthorResult] {
        Dictionary(grouping: poems, by: \.author)
            .map { author, poems in
                let dynasty = poems.first?.dynasty ?? ""
                return AuthorResult(
                    id: "\(dynasty)-\(author)",
                    name: author,
                    dynasty: dynasty,
                    poems: popularSortedPoems(poems)
                )
            }
            .sorted { lhs, rhs in
                let lhsScore = popularityScore(for: lhs)
                let rhsScore = popularityScore(for: rhs)

                if lhsScore == rhsScore {
                    return firstPoemOrder(in: lhs) < firstPoemOrder(in: rhs)
                }

                return lhsScore > rhsScore
            }
    }

    func search(_ query: String) -> SearchResults {
        let tokens = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(separator: " ")
            .map(String.init)

        guard !tokens.isEmpty else {
            return SearchResults()
        }

        let matchedPoems = poems.filter { poem in
            let searchable = [
                poem.title,
                poem.author,
                poem.dynasty,
                poem.form,
                poem.fullText,
                poem.tags.joined(separator: " ")
            ]
            .joined(separator: " ")
            .lowercased()

            return tokens.allSatisfy { searchable.localizedStandardContains($0) }
        }

        let matchedCollections = collections.filter { collection in
            let searchable = "\(collection.title) \(collection.subtitle)".lowercased()
            return tokens.allSatisfy { searchable.localizedStandardContains($0) }
        }

        let matchedAuthors = authors().filter { author in
            let searchable = "\(author.name) \(author.dynasty)".lowercased()
            return tokens.allSatisfy { searchable.localizedStandardContains($0) }
        }

        return SearchResults(
            poems: popularSortedPoems(matchedPoems),
            authors: matchedAuthors,
            collections: matchedCollections
        )
    }

    private func popularSortedPoems(_ candidates: [Poem]) -> [Poem] {
        candidates.sorted { lhs, rhs in
            let lhsScore = popularityScore(for: lhs)
            let rhsScore = popularityScore(for: rhs)

            if lhsScore == rhsScore {
                return poemOrder(for: lhs) < poemOrder(for: rhs)
            }

            return lhsScore > rhsScore
        }
    }

    private func popularityScore(for author: AuthorResult) -> Int {
        let poemScore = author.poems.map(popularityScore(for:)).max() ?? 0
        let authorScore = Self.authorPopularity[author.name] ?? 0
        return poemScore + authorScore + min(author.poems.count, 60)
    }

    private func popularityScore(for poem: Poem) -> Int {
        let titleScore = Self.popularTitleKeywords.reduce(0) { score, keyword in
            poem.title.localizedStandardContains(keyword.title) ? max(score, keyword.score) : score
        }
        let authorScore = Self.authorPopularity[poem.author] ?? 0
        let tagScore = poem.tags.reduce(0) { score, tag in
            score + (Self.classicTagPopularity[tag] ?? 0)
        }

        return titleScore + authorScore + min(tagScore, 120)
    }

    private func firstPoemOrder(in author: AuthorResult) -> Int {
        author.poems.map(poemOrder(for:)).min() ?? Int.max
    }

    private func poemOrder(for poem: Poem) -> Int {
        poemOrderByID[poem.id] ?? Int.max
    }

    private static let authorPopularity: [String: Int] = [
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
        ("靜夜思", 1000),
        ("将进酒", 980),
        ("將進酒", 980),
        ("春晓", 960),
        ("春曉", 960),
        ("登鹳雀楼", 940),
        ("登鸛雀樓", 940),
        ("锦瑟", 920),
        ("錦瑟", 920),
        ("水调歌头", 900),
        ("水調歌頭", 900),
        ("念奴娇", 880),
        ("念奴嬌", 880),
        ("雨霖铃", 860),
        ("雨霖鈴", 860),
        ("声声慢", 840),
        ("聲聲慢", 840),
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

    private static func loadBundledCatalog() -> PoemSeedCatalog {
        guard let url = Bundle.main.url(forResource: "PoemsSeed", withExtension: "json") else {
            assertionFailure("Missing PoemsSeed.json from app bundle.")
            return fallbackCatalog
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(PoemSeedCatalog.self, from: data)
        } catch {
            assertionFailure("Failed to decode PoemsSeed.json: \(error)")
            return fallbackCatalog
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
            )
        ],
        collections: [],
        categories: []
    )
}
