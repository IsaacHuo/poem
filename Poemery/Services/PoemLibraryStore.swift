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
    private var poemThemeSearchTextByID: [Poem.ID: String]
    private var popularPoemsCache: [Poem]
    private var authorsCache: [AuthorResult]
    private var keywordsCache: [PoemKeyword]
    private var searchEngine: PoemSearchEngine
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
        self.poemThemeSearchTextByID = index.poemThemeSearchTextByID
        self.popularPoemsCache = index.popularPoems
        self.authorsCache = index.authors
        self.keywordsCache = index.keywords
        self.searchEngine = index.searchEngine
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

    func frequentKeywords(limit: Int) -> [PoemKeyword] {
        Array(keywordsCache.prefix(limit))
    }

    func poems(forKeyword keyword: PoemKeyword, limit: Int? = nil) -> [Poem] {
        limited(keyword.poemIDs.compactMap { poemsByID[$0] }, limit: limit)
    }

    func chartPoems(limit: Int? = nil) -> [Poem] {
        limited(popularPoemsCache, limit: limit)
    }

    func poems(forTheme theme: String, limit: Int? = nil) -> [Poem] {
        let themeTokenVariants = Self.searchTokenVariants(theme)
        guard !themeTokenVariants.isEmpty else {
            return []
        }

        var matches: [Poem] = []

        for poem in popularPoemsCache where poemThemeMatches(poem, tokenVariants: themeTokenVariants) {
            matches.append(poem)

            if let limit, matches.count >= limit {
                break
            }
        }

        return matches
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
        let page = searchEngine.search(query, offset: 0, limit: Int.max)

        return SearchResults(
            poems: page.poemIDs.compactMap { poemsByID[$0] },
            authors: page.authors,
            collections: page.collections
        )
    }

    func searchPage(_ query: String, offset: Int = 0, limit: Int = 100) async -> SearchResultsPage {
        let engine = searchEngine
        let safeOffset = max(0, offset)
        let safeLimit = max(1, limit)

        return await Task.detached(priority: .userInitiated) {
            engine.search(query, offset: safeOffset, limit: safeLimit)
        }.value
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

    private func poemThemeMatches(_ poem: Poem, tokenVariants: [[String]]) -> Bool {
        guard let searchable = poemThemeSearchTextByID[poem.id] else {
            return false
        }

        return tokenVariants.allSatisfy { variants in
            variants.contains { searchable.localizedStandardContains($0) }
        }
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

    nonisolated static func searchTokenVariants(_ query: String) -> [[String]] {
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
    let poemThemeSearchTextByID: [Poem.ID: String]
    let popularPoems: [Poem]
    let authors: [AuthorResult]
    let keywords: [PoemKeyword]
    let searchEngine: PoemSearchEngine
    let forms: [String]
    let dynasties: [String]

    init(catalog: PoemSeedCatalog) {
        let poemOrderByID = Dictionary(uniqueKeysWithValues: catalog.poems.enumerated().map { index, poem in
            (poem.id, index)
        })
        let poemScoreByID = Dictionary(uniqueKeysWithValues: catalog.poems.map { poem in
            (poem.id, Self.popularityScore(for: poem))
        })
        let poemThemeSearchTextByID = Dictionary(uniqueKeysWithValues: catalog.poems.map { poem in
            (poem.id, Self.themeSearchText(for: poem))
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
        let keywords = Self.makeKeywords(
            poems: catalog.poems,
            poemOrderByID: poemOrderByID,
            poemScoreByID: poemScoreByID
        )
        let searchEngine = PoemSearchEngine(
            poems: popularPoems,
            collections: catalog.collections,
            authors: authors
        )

        self.poemsByID = Dictionary(uniqueKeysWithValues: catalog.poems.map { ($0.id, $0) })
        self.poemOrderByID = poemOrderByID
        self.poemScoreByID = poemScoreByID
        self.poemThemeSearchTextByID = poemThemeSearchTextByID
        self.popularPoems = popularPoems
        self.authors = authors
        self.keywords = keywords
        self.searchEngine = searchEngine
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

    private static func makeKeywords(
        poems: [Poem],
        poemOrderByID: [Poem.ID: Int],
        poemScoreByID: [Poem.ID: Int]
    ) -> [PoemKeyword] {
        let buckets = poems.reduce(into: [String: Set<Poem.ID>]()) { result, poem in
            for keyword in keywords(in: poem) {
                result[keyword, default: []].insert(poem.id)
            }
        }

        return buckets
            .map { keyword, poemIDs in
                let sortedPoems = popularSortedPoems(
                    poems.filter { poemIDs.contains($0.id) },
                    poemOrderByID: poemOrderByID,
                    poemScoreByID: poemScoreByID
                )
                return PoemKeyword(
                    id: keyword,
                    text: keyword,
                    count: poemIDs.count,
                    poemIDs: sortedPoems.map(\.id)
                )
            }
            .filter { $0.count >= 2 }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.text.localizedCompare(rhs.text) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
    }

    private static func keywords(in poem: Poem) -> [String] {
        let text = poem.fullText + poem.title
        let rawKeywords = highFrequencyKeywordCandidates.filter { keyword in
            text.localizedStandardContains(keyword)
        }
        return Array(Set(rawKeywords)).sorted {
            $0.localizedCompare($1) == .orderedAscending
        }
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

    private static func themeSearchText(for poem: Poem) -> String {
        PoemLibraryStore.normalizedSearchText(
            ([poem.dynasty, poem.form] + poem.themes + poem.tags)
                .joined(separator: " ")
        )
    }
}

private struct PoemSearchEngine: Sendable {
    private let poemRecords: [PoemSearchRecord]
    private let collections: [CollectionSearchRecord]
    private let authors: [AuthorSearchRecord]
    private let gramIndex: [String: [Int]]

    init(poems: [Poem], collections: [PoemCollection], authors: [AuthorResult]) {
        let poemRecords = poems.map { poem in
            PoemSearchRecord(
                id: poem.id,
                listItem: PoemListItem(poem: poem),
                searchText: Self.searchText(for: poem)
            )
        }

        self.poemRecords = poemRecords
        self.collections = collections.map { collection in
            CollectionSearchRecord(
                collection: collection,
                searchText: Self.searchText(for: collection)
            )
        }
        self.authors = authors.map { author in
            AuthorSearchRecord(
                author: author,
                searchText: Self.searchText(for: author)
            )
        }
        self.gramIndex = Self.makeGramIndex(records: poemRecords)
    }

    func search(_ query: String, offset: Int, limit: Int) -> SearchResultsPage {
        let tokenVariants = PoemLibraryStore.searchTokenVariants(query)

        guard !tokenVariants.isEmpty else {
            return SearchResultsPage()
        }

        let matchedPoemIndices = matchedPoemIndices(for: tokenVariants)
        let totalPoemCount = matchedPoemIndices.count
        let safeOffset = min(max(0, offset), totalPoemCount)
        let safeLimit = max(1, limit)
        let endOffset = min(totalPoemCount, safeOffset + min(safeLimit, totalPoemCount - safeOffset))
        let pageIndices = matchedPoemIndices[safeOffset..<endOffset]
        let nextOffset = endOffset < totalPoemCount ? endOffset : nil

        return SearchResultsPage(
            poems: pageIndices.map { poemRecords[$0].listItem },
            authors: matchedAuthors(for: tokenVariants),
            collections: matchedCollections(for: tokenVariants),
            totalPoemCount: totalPoemCount,
            nextOffset: nextOffset,
            poemIDs: matchedPoemIndices.map { poemRecords[$0].id }
        )
    }

    private func matchedPoemIndices(for tokenVariants: [[String]]) -> [Int] {
        var matchedIndices: Set<Int>?

        for variants in tokenVariants {
            let tokenMatches = variants.reduce(into: Set<Int>()) { result, variant in
                result.formUnion(candidatePoemIndices(for: variant))
            }

            guard !tokenMatches.isEmpty else {
                return []
            }

            if var currentMatches = matchedIndices {
                currentMatches.formIntersection(tokenMatches)
                matchedIndices = currentMatches
            } else {
                matchedIndices = tokenMatches
            }
        }

        return (matchedIndices ?? [])
            .filter { index in
                tokenVariants.allSatisfy { variants in
                    variants.contains { poemRecords[index].searchText.localizedStandardContains($0) }
                }
            }
            .sorted()
    }

    private func candidatePoemIndices(for variant: String) -> Set<Int> {
        let grams = Self.searchGrams(for: variant)
        guard !grams.isEmpty else {
            return []
        }

        var matchedIndices: Set<Int>?

        for gram in grams {
            guard let postings = gramIndex[gram] else {
                return []
            }

            let postingSet = Set(postings)
            if var currentMatches = matchedIndices {
                currentMatches.formIntersection(postingSet)
                matchedIndices = currentMatches
            } else {
                matchedIndices = postingSet
            }
        }

        return matchedIndices ?? []
    }

    private func matchedCollections(for tokenVariants: [[String]]) -> [PoemCollection] {
        collections
            .filter { record in
                tokenVariants.allSatisfy { variants in
                    variants.contains { record.searchText.localizedStandardContains($0) }
                }
            }
            .map(\.collection)
    }

    private func matchedAuthors(for tokenVariants: [[String]]) -> [AuthorResult] {
        authors
            .filter { record in
                tokenVariants.allSatisfy { variants in
                    variants.contains { record.searchText.localizedStandardContains($0) }
                }
            }
            .map(\.author)
    }

    private static func makeGramIndex(records: [PoemSearchRecord]) -> [String: [Int]] {
        var index: [String: [Int]] = [:]

        for (recordIndex, record) in records.enumerated() {
            for gram in Set(indexGrams(for: record.searchText)) {
                index[gram, default: []].append(recordIndex)
            }
        }

        return index
    }

    private static func indexGrams(for value: String) -> [String] {
        let characters = compactCharacters(value)
        guard !characters.isEmpty else {
            return []
        }

        var grams = characters.map(String.init)
        if characters.count > 1 {
            for index in 0..<(characters.count - 1) {
                grams.append(String(characters[index]) + String(characters[index + 1]))
            }
        }

        return grams
    }

    private static func searchGrams(for value: String) -> [String] {
        let characters = compactCharacters(value)
        guard !characters.isEmpty else {
            return []
        }

        if characters.count == 1 {
            return [String(characters[0])]
        }

        return (0..<(characters.count - 1)).map { index in
            String(characters[index]) + String(characters[index + 1])
        }
    }

    private static func compactCharacters(_ value: String) -> [Character] {
        value
            .lowercased()
            .filter { !$0.isWhitespace }
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

private struct PoemSearchRecord: Sendable {
    let id: Poem.ID
    let listItem: PoemListItem
    let searchText: String
}

private struct CollectionSearchRecord: Sendable {
    let collection: PoemCollection
    let searchText: String
}

private struct AuthorSearchRecord: Sendable {
    let author: AuthorResult
    let searchText: String
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

    private static let highFrequencyKeywordCandidates = [
        "春",
        "风",
        "花",
        "月",
        "夜",
        "山",
        "水",
        "江",
        "云",
        "雨",
        "秋",
        "酒",
        "人",
        "客",
        "愁",
        "梦",
        "归",
        "天",
        "柳",
        "烟",
        "雪",
        "日",
        "长",
        "故",
        "心",
        "君",
        "清",
        "落",
        "空",
        "乡"
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
