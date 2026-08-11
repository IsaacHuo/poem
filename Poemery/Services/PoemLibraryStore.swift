import Foundation
import Observation

@MainActor
@Observable
final class PoemLibraryStore {
    private var poems: [Poem]
    private(set) var collections: [PoemCollection]
    private(set) var categories: [PoemCategory]

    private var poemsByID: [Poem.ID: Poem]
    private var popularPoemsCache: [Poem]
    private var authorsCache: [AuthorResult]
    private var keywordsCache: [PoemKeyword]
    private var formsCache: [String]
    private var dynastiesCache: [String]
    private var statsCache: PoemeryStats
    private let interactionDatabase: SQLitePoemLibraryQueryActor?
    private let searchDatabase: SQLitePoemLibraryQueryActor?
    private var detailCacheOrder: [Poem.ID] = []
    private var summaryCacheOrder: [Poem.ID] = []
    private var pageCursors: [PoemPageQuery: [Int: PageCursor]] = [:]
    private var authorPageCursors: [Int: PageCursor] = [:]

    convenience init(catalog: PoemSeedCatalog) {
        self.init(catalog: catalog, databaseURL: nil)
    }

    private init(catalog: PoemSeedCatalog, databaseURL: URL?) {
        let popularPoems = Self.localPopularPoems(catalog.poems)
        let authors = Self.localAuthors(catalog.poems, profiles: catalog.authorProfiles)
        self.poems = catalog.poems
        self.collections = catalog.collections
        self.categories = catalog.categories
        self.poemsByID = Dictionary(uniqueKeysWithValues: catalog.poems.map { ($0.id, $0) })
        self.popularPoemsCache = popularPoems
        self.authorsCache = authors
        self.keywordsCache = Self.localKeywords(catalog.poems, orderedBy: popularPoems)
        self.formsCache = Self.localFacetValues(catalog.poems, keyPath: \.form)
        self.dynastiesCache = Self.localFacetValues(catalog.poems, keyPath: \.dynasty)
        self.statsCache = PoemeryStats(
            totalPoems: catalog.poems.count,
            totalAuthors: authors.count,
            totalCollections: catalog.collections.count,
            totalCategories: catalog.categories.count
        )
        self.interactionDatabase = databaseURL.map(SQLitePoemLibraryQueryActor.init(url:))
        self.searchDatabase = databaseURL.map(SQLitePoemLibraryQueryActor.init(url:))
        self.summaryCacheOrder = catalog.poems.map(\.id)
        self.detailCacheOrder = catalog.poems.filter { !$0.lines.isEmpty }.map(\.id)
    }

    var totalPoemCount: Int {
        statsCache.totalPoems
    }

    var totalAuthorCount: Int {
        statsCache.totalAuthors
    }

    var totalCollectionCount: Int {
        statsCache.totalCollections
    }

    var totalCategoryCount: Int {
        statsCache.totalCategories
    }

    var cachedPoemCount: Int {
        poems.count
    }

    func cachedPoems(limit: Int? = nil) -> [Poem] {
        limited(poems, limit: limit)
    }

    func firstCachedPoem() -> Poem? {
        poems.first
    }

    func relatedPoems(to poem: Poem, limit: Int = 4) -> [Poem] {
        Array(poems.lazy.filter { candidate in
            candidate.id != poem.id && candidate.tags.contains { poem.tags.contains($0) }
        }.prefix(limit))
    }

    static func bootstrap(script: ChineseScriptPreference = .simplified) -> PoemLibraryStore {
        let catalog = mergedCatalog(base: fallbackCatalog, enhancement: curatedCatalog()).converted(to: script)
        let databaseURL = Bundle.main.url(forResource: "PoemLibrary", withExtension: "sqlite")
        return PoemLibraryStore(
            catalog: catalog,
            databaseURL: databaseURL
        )
    }

    nonisolated static func loadBundled(script: ChineseScriptPreference = .simplified) async throws -> PoemLibraryStore {
        let store = await MainActor.run { bootstrap(script: script) }
        try await store.prepare(script: script)
        return store
    }

    func prepare(script: ChineseScriptPreference) async throws {
        guard let interactionDatabase else {
            return
        }
        let bootstrap = try await interactionDatabase.bootstrap(script: script)
        statsCache = bootstrap.stats
        collections = bootstrap.collections
        categories = bootstrap.categories
        authorsCache = bootstrap.authors
        keywordsCache = bootstrap.keywords
        formsCache = bootstrap.forms
        dynastiesCache = bootstrap.dynasties
        popularPoemsCache = bootstrap.popularPoems
        rememberSummaries(bootstrap.popularPoems)
    }

    func poem(id: Poem.ID) -> Poem? {
        poemsByID[id]
    }

    func remember(_ poem: Poem) {
        rememberSummaries([poem])
    }

    func handleMemoryWarning(keeping currentDetailID: Poem.ID?) {
        for id in detailCacheOrder where id != currentDetailID {
            if let poem = poemsByID[id], !poem.lines.isEmpty {
                poemsByID[id] = Poem(
                    id: poem.id, title: poem.title, author: poem.author, dynasty: poem.dynasty,
                    form: poem.form, tags: [], summary: poem.summary, lines: [], annotations: [],
                    sourceURL: nil, artworkStyle: poem.artworkStyle, sourceName: "", sourceLicense: "",
                    firstLinePreview: poem.firstLinePreview
                )
            }
        }
        detailCacheOrder = currentDetailID.map { [$0] } ?? []
        pageCursors.removeAll(keepingCapacity: true)
        authorPageCursors.removeAll(keepingCapacity: true)
        synchronizeCachedPoems()
    }

    func poems(for collection: PoemCollection) -> [Poem] {
        collection.poemIDs.compactMap { poemsByID[$0] }
    }

    func loadPoemDetailIfNeeded(id: Poem.ID, script: ChineseScriptPreference) async {
        if poemsByID[id]?.lines.isEmpty == false {
            touchDetail(id)
            return
        }
        guard let interactionDatabase else { return }
        do {
            guard let poem = try await interactionDatabase.poemDetail(id: id)?.converted(to: script) else { return }
            poemsByID[id] = poem
            touchDetail(id)
            synchronizeCachedPoems()
        } catch {
            return
        }
    }

    func loadPoemsPage(page: Int, script: ChineseScriptPreference) async -> PagedPoems {
        await loadPage(query: .all, page: page, script: script)
    }

    func loadCollectionPoems(collection: PoemCollection, page: Int, script: ChineseScriptPreference) async -> PagedPoems {
        await loadPage(query: .collection(collection.id), page: page, script: script)
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

    func loadAuthorsPage(page: Int, script: ChineseScriptPreference) async -> PagedAuthors {
        guard let interactionDatabase else {
            return localAuthorsPage(authorsCache, page: page)
        }
        let safePage = max(1, page)
        let cursor = safePage == 1 ? nil : authorPageCursors[safePage]
        guard safePage == 1 || cursor != nil else {
            return PagedAuthors(authors: [], page: safePage, totalPages: safePage - 1, total: 0)
        }
        do {
            let result = try await interactionDatabase.authorPage(cursor: cursor, limit: 50)
            let converted = result.items.map { $0.converted(to: script) }
            for author in converted where !authorsCache.contains(where: { $0.id == author.id }) {
                authorsCache.append(author)
            }
            if let nextCursor = result.nextCursor {
                authorPageCursors[safePage + 1] = nextCursor
            }
            let totalPages = Int(ceil(Double(result.total) / 50.0))
            return PagedAuthors(
                authors: converted, page: safePage, totalPages: totalPages, total: result.total
            )
        } catch {
            return PagedAuthors(authors: [], page: safePage, totalPages: 0, total: 0)
        }
    }

    func loadAuthorPoems(author: AuthorResult, page: Int, script: ChineseScriptPreference) async -> PagedPoems {
        await loadPage(query: .author(author.id), page: page, script: script)
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

    func discoveryPoems(seed: String, excluding excludedIDs: Set<Poem.ID> = [], limit: Int = 8) -> [Poem] {
        let candidates = poems
            .filter { !excludedIDs.contains($0.id) }
            .sorted { Self.stableHash("\(seed)|\($0.id)") < Self.stableHash("\(seed)|\($1.id)") }
        var authorCounts: [String: Int] = [:]
        var dynastyCounts: [String: Int] = [:]
        var result: [Poem] = []

        for poem in candidates {
            guard authorCounts[poem.author, default: 0] < 2,
                  dynastyCounts[poem.dynasty, default: 0] < 3 else { continue }
            result.append(poem)
            authorCounts[poem.author, default: 0] += 1
            dynastyCounts[poem.dynasty, default: 0] += 1
            if result.count == limit { break }
        }
        return result
    }

    func personalizedRecommendations(recent: [Poem], favorites: [Poem], limit: Int = 6) -> [Poem] {
        let history = Array((recent + favorites).prefix(20))
        guard !history.isEmpty else { return popularPoems(limit: limit) }
        let excluded = Set(history.map(\.id))
        let authors = Set(history.map(\.author))
        let dynasties = Set(history.map(\.dynasty))
        let forms = Set(history.map(\.form))
        let themes = Set(history.flatMap(\.themes))

        var scored: [(poem: Poem, score: Int)] = []
        for poem in poems where !excluded.contains(poem.id) {
            var score = 0
            if authors.contains(poem.author) { score += 8 }
            if dynasties.contains(poem.dynasty) { score += 3 }
            if forms.contains(poem.form) { score += 4 }
            for theme in poem.themes where themes.contains(theme) { score += 2 }
            score += Self.localPopularityScore(for: poem) / 20
            scored.append((poem, score))
        }
        scored.sort { lhs, rhs in
            lhs.score == rhs.score ? lhs.poem.id < rhs.poem.id : lhs.score > rhs.score
        }
        return scored.prefix(limit).map(\.poem)
    }

    func search(_ query: String) -> SearchResults {
        let page = localSearchPage(query, cursor: nil, limit: Int.max)

        return SearchResults(
            poems: page.poemIDs.compactMap { poemsByID[$0] },
            authors: page.authors,
            collections: page.collections
        )
    }

    func searchPage(
        _ query: String,
        cursor: SearchPageCursor? = nil,
        limit: Int = 100,
        script: ChineseScriptPreference = .simplified
    ) async -> SearchResultsPage {
        guard let searchDatabase else {
            return localSearchPage(query, cursor: cursor, limit: limit)
        }
        do {
            let page = try await searchDatabase.searchPage(query, cursor: cursor, limit: limit)
            return page.converted(to: script)
        } catch {
            return SearchResultsPage()
        }
    }

    func cancelSearch() {
        guard let searchDatabase else { return }
        searchDatabase.interrupt()
    }

    func loadSummaries(ids: [Poem.ID], script: ChineseScriptPreference) async -> [Poem] {
        let cached = Dictionary(uniqueKeysWithValues: ids.compactMap { id in poemsByID[id].map { (id, $0) } })
        let missing = ids.filter { cached[$0] == nil }
        if let interactionDatabase, !missing.isEmpty,
           let loaded = try? await interactionDatabase.poemSummaries(ids: missing) {
            rememberSummaries(loaded.map { $0.converted(to: script) })
        }
        return ids.compactMap { poemsByID[$0] }
    }

    func loadDiscovery(
        seed: String,
        excluding excludedIDs: Set<Poem.ID>,
        limit: Int,
        script: ChineseScriptPreference
    ) async -> [Poem] {
        guard let interactionDatabase else {
            return discoveryPoems(seed: seed, excluding: excludedIDs, limit: limit)
        }
        let start = Int(Self.stableHash(seed) % UInt64(max(totalPoemCount, 1)))
        let firstCursor = PageCursor(order: max(0, start - 1), id: "")
        let first = try? await interactionDatabase.poemPage(query: .all, cursor: firstCursor, limit: 96)
        var candidates = first?.items ?? []
        if candidates.count < 96,
           let wrapped = try? await interactionDatabase.poemPage(query: .all, cursor: nil, limit: 96 - candidates.count) {
            candidates.append(contentsOf: wrapped.items)
        }
        let converted = candidates.map { $0.converted(to: script) }
        rememberSummaries(converted)
        var authorCounts: [String: Int] = [:]
        var dynastyCounts: [String: Int] = [:]
        var result: [Poem] = []
        for poem in converted where !excludedIDs.contains(poem.id) {
            guard authorCounts[poem.author, default: 0] < 2,
                  dynastyCounts[poem.dynasty, default: 0] < 3 else { continue }
            result.append(poem)
            authorCounts[poem.author, default: 0] += 1
            dynastyCounts[poem.dynasty, default: 0] += 1
            if result.count == limit { break }
        }
        return result
    }

    func loadRecommendations(
        recentIDs: [Poem.ID],
        favoriteIDs: [Poem.ID],
        limit: Int,
        script: ChineseScriptPreference
    ) async -> [Poem] {
        let historyIDs = Array((recentIDs + favoriteIDs).prefix(20))
        let excluded = Set(recentIDs + favoriteIDs)
        guard let interactionDatabase else {
            return popularPoems(limit: limit).filter { !excluded.contains($0.id) }
        }
        let history = await loadSummaries(ids: historyIDs, script: script)
        guard !history.isEmpty else {
            guard let page = try? await interactionDatabase.poemPage(query: .popular, cursor: nil, limit: 50) else {
                return []
            }
            let converted = page.items.map { $0.converted(to: script) }
            rememberSummaries(converted)
            return Array(converted.lazy.filter { !excluded.contains($0.id) }.prefix(limit))
        }

        let authorIDs = Set(history.compactMap { poem in
            authorsCache.first { $0.name == poem.author && $0.dynasty == poem.dynasty }?.id
        })
        let dynasties = Set(history.map(\.dynasty))
        let forms = Set(history.map(\.form))
        var candidatesByID: [Poem.ID: Poem] = [:]
        let queries = authorIDs.prefix(3).map(PoemPageQuery.author)
            + dynasties.prefix(3).map(PoemPageQuery.dynasty)
            + forms.prefix(2).map(PoemPageQuery.form)
        for query in queries where candidatesByID.count < 200 {
            guard let page = try? await interactionDatabase.poemPage(query: query, cursor: nil, limit: 50) else { continue }
            for poem in page.items where candidatesByID.count < 200 {
                candidatesByID[poem.id] = poem.converted(to: script)
            }
        }

        let authorNames = Set(history.map(\.author))
        var scored: [(poem: Poem, score: Int)] = []
        for poem in candidatesByID.values where !excluded.contains(poem.id) {
            var score = 0
            if authorNames.contains(poem.author) { score += 8 }
            if forms.contains(poem.form) { score += 4 }
            if dynasties.contains(poem.dynasty) { score += 3 }
            scored.append((poem: poem, score: score))
        }
        scored.sort { lhs, rhs in
            lhs.score == rhs.score ? lhs.poem.id < rhs.poem.id : lhs.score > rhs.score
        }
        let ranked = scored.prefix(limit).map(\.poem)
        rememberSummaries(Array(candidatesByID.values))
        return Array(ranked)
    }

    func loadFacetPoems(
        kind: String,
        value: String,
        page: Int,
        script: ChineseScriptPreference
    ) async -> PagedPoems {
        let query: PoemPageQuery
        switch kind {
        case "dynasty": query = .dynasty(value)
        case "form": query = .form(value)
        default: query = .theme(value)
        }
        return await loadPage(query: query, page: page, script: script)
    }

    private func popularSortedPoems(_ candidates: [Poem]) -> [Poem] {
        Self.localPopularPoems(candidates)
    }

    func poemsByAuthor(_ author: AuthorResult) -> [Poem] {
        let authorNameVariants = Self.searchTokenVariants(author.name).flatMap { $0 }
        let dynastyVariants = Self.searchTokenVariants(author.dynasty).flatMap { $0 }

        return popularSortedPoems(poems.filter { poem in
            let poemAuthor = Self.normalizedSearchText(poem.author)
            let poemDynasty = Self.normalizedSearchText(poem.dynasty)
            let authorMatches = authorNameVariants.contains { poemAuthor.localizedStandardContains($0) }
            let dynastyMatches = dynastyVariants.isEmpty || dynastyVariants.contains { poemDynasty.localizedStandardContains($0) }
            return authorMatches && dynastyMatches
        })
    }

    private func loadPage(
        query: PoemPageQuery,
        page: Int,
        script: ChineseScriptPreference
    ) async -> PagedPoems {
        guard let interactionDatabase else {
            return localPoemsPage(poems, page: page)
        }
        let safePage = max(1, page)
        let cursor = safePage == 1 ? nil : pageCursors[query]?[safePage]
        guard safePage == 1 || cursor != nil else {
            return PagedPoems(poems: [], page: safePage, totalPages: safePage - 1, total: 0)
        }
        do {
            let result = try await interactionDatabase.poemPage(query: query, cursor: cursor, limit: 50)
            let converted = result.items.map { $0.converted(to: script) }
            rememberSummaries(converted)
            if pageCursors[query] == nil { pageCursors[query] = [:] }
            if let nextCursor = result.nextCursor {
                pageCursors[query]?[safePage + 1] = nextCursor
            }
            let totalPages = Int(ceil(Double(result.total) / 50.0))
            return PagedPoems(poems: converted, page: safePage, totalPages: totalPages, total: result.total)
        } catch {
            return PagedPoems(poems: [], page: safePage, totalPages: 0, total: 0)
        }
    }

    private func rememberSummaries(_ summaries: [Poem]) {
        for poem in summaries {
            if poemsByID[poem.id]?.lines.isEmpty == false, poem.lines.isEmpty {
                touchSummary(poem.id)
                continue
            }
            poemsByID[poem.id] = poem
            touchSummary(poem.id)
        }
        while summaryCacheOrder.count > 300 {
            let evicted = summaryCacheOrder.removeFirst()
            if !detailCacheOrder.contains(evicted) {
                poemsByID.removeValue(forKey: evicted)
            }
        }
        synchronizeCachedPoems()
    }

    private func touchSummary(_ id: Poem.ID) {
        summaryCacheOrder.removeAll { $0 == id }
        summaryCacheOrder.append(id)
    }

    private func touchDetail(_ id: Poem.ID) {
        detailCacheOrder.removeAll { $0 == id }
        detailCacheOrder.append(id)
        touchSummary(id)
        while detailCacheOrder.count > 20 {
            let evicted = detailCacheOrder.removeFirst()
            if let poem = poemsByID[evicted], !poem.lines.isEmpty {
                poemsByID[evicted] = Poem(
                    id: poem.id, title: poem.title, author: poem.author, dynasty: poem.dynasty,
                    form: poem.form, tags: [], summary: poem.summary, lines: [], annotations: [],
                    sourceURL: nil, artworkStyle: poem.artworkStyle, sourceName: "", sourceLicense: "",
                    firstLinePreview: poem.firstLinePreview
                )
            }
        }
    }

    private func synchronizeCachedPoems() {
        poems = summaryCacheOrder.compactMap { poemsByID[$0] }
    }

    private func localPoemsPage(_ source: [Poem], page: Int, pageSize: Int = 100) -> PagedPoems {
        guard !source.isEmpty else {
            return PagedPoems(poems: [], page: 1, totalPages: 0, total: 0)
        }

        let safePage = max(1, page)
        let start = min((safePage - 1) * pageSize, source.count)
        let end = min(start + pageSize, source.count)
        return PagedPoems(
            poems: Array(source[start..<end]),
            page: safePage,
            totalPages: Int(ceil(Double(source.count) / Double(pageSize))),
            total: source.count
        )
    }

    private func localAuthorsPage(_ source: [AuthorResult], page: Int, pageSize: Int = 100) -> PagedAuthors {
        guard !source.isEmpty else {
            return PagedAuthors(authors: [], page: 1, totalPages: 0, total: 0)
        }

        let safePage = max(1, page)
        let start = min((safePage - 1) * pageSize, source.count)
        let end = min(start + pageSize, source.count)
        return PagedAuthors(
            authors: Array(source[start..<end]),
            page: safePage,
            totalPages: Int(ceil(Double(source.count) / Double(pageSize))),
            total: source.count
        )
    }

    private func limited(_ poems: [Poem], limit: Int?) -> [Poem] {
        guard let limit else {
            return poems
        }
        return Array(poems.prefix(limit))
    }

    private func localSearchPage(_ query: String, cursor: SearchPageCursor?, limit: Int) -> SearchResultsPage {
        let tokenVariants = Self.searchTokenVariants(query)
        guard !tokenVariants.isEmpty else { return SearchResultsPage() }

        let matches = popularPoemsCache.filter { poem in
            let searchable = Self.normalizedSearchText([
                poem.title, poem.author, poem.dynasty, poem.form,
                poem.tags.joined(separator: " "), poem.fullText
            ].joined(separator: " "))
            return tokenVariants.allSatisfy { variants in
                variants.contains { searchable.localizedStandardContains($0) }
            }
        }
        let safeOffset = min(max(0, Int(cursor?.rank ?? 0)), matches.count)
        let safeLimit = max(1, limit)
        let end = min(matches.count, safeOffset + min(safeLimit, matches.count - safeOffset))
        let page = matches[safeOffset..<end]
        let authors = authorsCache.filter { author in
            let searchable = Self.normalizedSearchText("\(author.name) \(author.dynasty) \(author.introduction)")
            return tokenVariants.allSatisfy { variants in
                variants.contains { searchable.localizedStandardContains($0) }
            }
        }
        let matchingCollections = collections.filter { collection in
            let searchable = Self.normalizedSearchText("\(collection.title) \(collection.subtitle)")
            return tokenVariants.allSatisfy { variants in
                variants.contains { searchable.localizedStandardContains($0) }
            }
        }

        return SearchResultsPage(
            poems: page.map { PoemListItem(poem: $0) },
            authors: authors,
            collections: matchingCollections,
            totalPoemCount: matches.count,
            nextCursor: end < matches.count ? SearchPageCursor(rank: Double(end), rowID: 0) : nil,
            poemIDs: matches.map(\.id)
        )
    }

    private func poemThemeMatches(_ poem: Poem, tokenVariants: [[String]]) -> Bool {
        let searchable = Self.normalizedSearchText(
            ([poem.dynasty, poem.form] + poem.themes + poem.tags).joined(separator: " ")
        )

        return tokenVariants.allSatisfy { variants in
            variants.contains { searchable.localizedStandardContains($0) }
        }
    }

    nonisolated static func normalizedSearchText(_ value: String) -> String {
        let lowered = value.lowercased()
        let scriptVariants = uniqueValues([
            lowered,
            ChineseTextConverter.convert(lowered, to: .simplified),
            ChineseTextConverter.convert(lowered, to: .traditional)
        ])
        let foldedVariants = scriptVariants.map(foldedSearchText)
        let searchVariants = uniqueValues(scriptVariants + foldedVariants)
        let aliases = poemerySearchAliases.reduce(into: [String]()) { result, alias in
            if searchVariants.contains(where: { $0.localizedStandardContains(alias.key) }) {
                result.append(alias.value)
            }
        }
        return uniqueValues(searchVariants + aliases).joined(separator: " ")
    }

    nonisolated static func foldedSearchText(_ value: String) -> String {
        String(value.lowercased().map { poemerySearchCharacterMap[$0] ?? $0 })
    }

    nonisolated private static func stableHash(_ value: String) -> UInt64 {
        value.utf8.reduce(0xCBF2_9CE4_8422_2325) { hash, byte in
            (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
    }

    private static func localPopularPoems(_ poems: [Poem]) -> [Poem] {
        poems.enumerated().sorted { lhs, rhs in
            let lhsScore = localPopularityScore(for: lhs.element)
            let rhsScore = localPopularityScore(for: rhs.element)
            return lhsScore == rhsScore ? lhs.offset < rhs.offset : lhsScore > rhsScore
        }.map(\.element)
    }

    private static func localAuthors(_ poems: [Poem], profiles: [AuthorProfile]) -> [AuthorResult] {
        let profilesByKey = Dictionary(uniqueKeysWithValues: profiles.map {
            ("\($0.dynasty)|\($0.name)", $0)
        })
        return Dictionary(grouping: poems, by: { "\($0.dynasty)|\($0.author)" })
            .compactMap { key, poems in
                guard let poem = poems.first else { return nil }
                return AuthorResult(
                    id: key,
                    name: poem.author,
                    dynasty: poem.dynasty,
                    poemCount: poems.count,
                    profile: profilesByKey[key]
                )
            }
            .sorted { lhs, rhs in
                let lhsScore = (authorPopularity[lhs.name] ?? 0) + min(lhs.poemCount, 60)
                let rhsScore = (authorPopularity[rhs.name] ?? 0) + min(rhs.poemCount, 60)
                return lhsScore == rhsScore
                    ? lhs.name.localizedCompare(rhs.name) == .orderedAscending
                    : lhsScore > rhsScore
            }
    }

    private static func localFacetValues(_ poems: [Poem], keyPath: KeyPath<Poem, String>) -> [String] {
        var counts: [String: Int] = [:]
        for poem in poems {
            counts[poem[keyPath: keyPath], default: 0] += 1
        }
        var sorted: [(value: String, count: Int)] = []
        for (value, count) in counts {
            sorted.append((value: value, count: count))
        }
        sorted.sort { lhs, rhs in
            if lhs.count == rhs.count {
                return lhs.value.localizedCompare(rhs.value) == .orderedAscending
            }
            return lhs.count > rhs.count
        }
        return sorted.map { $0.value }
    }

    private static func localKeywords(_ poems: [Poem], orderedBy orderedPoems: [Poem]) -> [PoemKeyword] {
        let buckets = poems.reduce(into: [String: Set<Poem.ID>]()) { result, poem in
            let text = poem.fullText + poem.title
            for keyword in highFrequencyKeywordCandidates where text.localizedStandardContains(keyword) {
                result[keyword, default: []].insert(poem.id)
            }
        }
        return buckets.map { keyword, ids in
            PoemKeyword(
                id: keyword,
                text: keyword,
                count: ids.count,
                poemIDs: Array(orderedPoems.lazy.filter { ids.contains($0.id) }.map(\.id))
            )
        }
        .filter { $0.count >= 2 }
        .sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs.text.localizedCompare(rhs.text) == .orderedAscending : lhs.count > rhs.count
        }
    }

    private static func localPopularityScore(for poem: Poem) -> Int {
        let normalizedTitle = foldedSearchText(poem.title)
        let titleScore = popularTitleKeywords.reduce(0) { score, keyword in
            normalizedTitle.contains(keyword.title) ? max(score, keyword.score) : score
        }
        let tagScore = poem.tags.reduce(0) { $0 + (classicTagPopularity[$1] ?? 0) }
        return titleScore + (authorPopularity[poem.author] ?? 0) + min(tagScore, 120)
    }

    nonisolated private static func uniqueValues(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
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

    nonisolated private static func mergedCatalog(
        base: PoemSeedCatalog,
        enhancement: PoemSeedCatalog
    ) -> PoemSeedCatalog {
        var poems = base.poems
        var canonicalIndex: [String: Int] = [:]
        var resolvedEnhancementIDs: [Poem.ID: Poem.ID] = [:]

        for (index, poem) in poems.enumerated() {
            canonicalIndex[normalizedCatalogKey(poem.canonicalKey)] = index
        }

        for poem in enhancement.poems {
            let key = normalizedCatalogKey(poem.canonicalKey)
            if let existingIndex = canonicalIndex[key] {
                let existingID = poems[existingIndex].id
                poems[existingIndex] = poem.replacingID(existingID)
                resolvedEnhancementIDs[poem.id] = existingID
            } else {
                canonicalIndex[key] = poems.count
                poems.append(poem)
                resolvedEnhancementIDs[poem.id] = poem.id
            }
        }

        var collections = base.collections
        let existingCollectionIDs = Set(collections.map(\.id))
        collections.append(contentsOf: enhancement.collections
            .filter { !existingCollectionIDs.contains($0.id) }
            .map { collection in
                PoemCollection(
                    id: collection.id,
                    title: collection.title,
                    subtitle: collection.subtitle,
                    kind: collection.kind,
                    poemCount: collection.poemCount,
                    poemIDs: collection.poemIDs.map { resolvedEnhancementIDs[$0] ?? $0 },
                    accent: collection.accent
                )
            })

        var categories = base.categories
        let existingCategoryIDs = Set(categories.map(\.id))
        categories.append(contentsOf: enhancement.categories.filter { !existingCategoryIDs.contains($0.id) })

        let profileIDs = Set(base.authorProfiles.map(\.id))
        let authorProfiles = base.authorProfiles + enhancement.authorProfiles.filter { !profileIDs.contains($0.id) }
        return PoemSeedCatalog(
            poems: poems,
            collections: collections,
            categories: categories,
            authorProfiles: authorProfiles
        )
    }

    nonisolated private static func normalizedCatalogKey(_ value: String) -> String {
        foldedSearchText(ChineseTextConverter.convert(value, to: .simplified))
            .filter { !$0.isWhitespace && $0 != "|" }
    }

    nonisolated private static func curatedCatalog() -> PoemSeedCatalog {
        let yuanRiLines = [
            PoemLine(id: "curated-yuan-ri-1", order: 0, text: "爆竹声中一岁除，春风送暖入屠苏。"),
            PoemLine(id: "curated-yuan-ri-2", order: 1, text: "千门万户曈曈日，总把新桃换旧符。")
        ]

        let poems = [
            Poem(
                id: "curated-yuan-ri",
                title: "元日",
                author: "王安石",
                dynasty: "宋",
                form: "七言绝句",
                tags: ["宋诗", "节令", "春节", "辞旧迎新"],
                summary: "在爆竹、屠苏和桃符的节俗中，写新年初日的温暖与更新。",
                lines: yuanRiLines,
                annotations: [
                    PoemAnnotation(id: "curated-yuan-ri-note-1", lineID: yuanRiLines[0].id, term: "一岁除", reading: "yí suì chú", summary: "一年已经过去。", detail: "“除”有逝去、终了之意，这里指旧的一年结束。"),
                    PoemAnnotation(id: "curated-yuan-ri-note-2", lineID: yuanRiLines[0].id, term: "屠苏", reading: "tú sū", summary: "古代岁首饮用的屠苏酒。", detail: "古人在新年饮屠苏酒，寄托迎新祈福之意。"),
                    PoemAnnotation(id: "curated-yuan-ri-note-3", lineID: yuanRiLines[1].id, term: "曈曈", reading: "tóng tóng", summary: "太阳初升、光亮温暖的样子。", detail: "诗中以明亮的日光烘托新年万象更新的气氛。"),
                    PoemAnnotation(id: "curated-yuan-ri-note-4", lineID: yuanRiLines[1].id, term: "桃符", reading: "táo fú", summary: "古代新年悬挂在门旁的桃木板。", detail: "桃符上常题神名或吉语，后来逐渐发展为春联。")
                ],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#B84034", secondaryHex: "#E9A755", tertiaryHex: "#303535", glyph: "元"),
                sourceName: "古典文学公版文本 · Poemery 校订",
                sourceLicense: "古典原文公版；注音、译文与赏析为 Poemery 原创编辑",
                editorialSummary: "王安石以新年节俗串联听觉、温度与光线，写出辞旧迎新的明快力量。",
                themes: ["节令", "新年", "春节", "岁首", "新春", "辞旧迎新"],
                difficulty: 2,
                canonicalKey: "宋|王安石|元日",
                supplement: PoemSupplement(
                    pronunciations: [
                        PoemPronunciationLine(lineID: yuanRiLines[0].id, text: "bào zhú shēng zhōng yí suì chú，chūn fēng sòng nuǎn rù tú sū。"),
                        PoemPronunciationLine(lineID: yuanRiLines[1].id, text: "qiān mén wàn hù tóng tóng rì，zǒng bǎ xīn táo huàn jiù fú。")
                    ],
                    translation: "爆竹声中旧的一年过去了，温暖的春风送来新岁，人们畅饮屠苏酒。初升的太阳照亮千家万户，大家都用新的桃符换下旧桃符。",
                    appreciation: "全诗紧扣岁首习俗展开。爆竹先以声音唤起节日现场，春风与屠苏带来温暖的体感；后两句把视线推向日光下的千门万户，并以更换桃符收束。诗人没有停留在节俗罗列，而是借“除”“暖”“新”“换”等词写出时间更新、生活向前的共同愿望。",
                    sourceName: "Poemery 编辑内容",
                    sourceLicense: "Poemery 原创编辑"
                )
            ),
            Poem(
                id: "curated-guan-cang-hai",
                title: "观沧海",
                author: "曹操",
                dynasty: "汉",
                form: "四言古诗",
                tags: ["汉诗", "山水", "抒怀"],
                summary: "登临碣石远望大海，以壮阔景象寄托胸襟。",
                lines: [
                    PoemLine(id: "curated-guan-cang-hai-1", order: 0, text: "东临碣石，以观沧海。"),
                    PoemLine(id: "curated-guan-cang-hai-2", order: 1, text: "水何澹澹，山岛竦峙。"),
                    PoemLine(id: "curated-guan-cang-hai-3", order: 2, text: "树木丛生，百草丰茂。"),
                    PoemLine(id: "curated-guan-cang-hai-4", order: 3, text: "秋风萧瑟，洪波涌起。"),
                    PoemLine(id: "curated-guan-cang-hai-5", order: 4, text: "日月之行，若出其中；"),
                    PoemLine(id: "curated-guan-cang-hai-6", order: 5, text: "星汉灿烂，若出其里。"),
                    PoemLine(id: "curated-guan-cang-hai-7", order: 6, text: "幸甚至哉，歌以咏志。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#24596B", secondaryHex: "#86B8B0", tertiaryHex: "#26333A", glyph: "海"),
                sourceName: "古典文学公版文本 · Poemery 校订",
                sourceLicense: "古典原文公版",
                themes: ["山水", "大海", "登临", "胸襟", "秋景"],
                canonicalKey: "汉|曹操|观沧海"
            ),
            Poem(
                id: "curated-yin-jiu-5",
                title: "饮酒·其五",
                author: "陶渊明",
                dynasty: "魏晋",
                form: "五言古诗",
                tags: ["魏晋诗", "田园", "隐逸"],
                summary: "从人境中的宁静写到采菊见山，表达心远自静的人生体会。",
                lines: [
                    PoemLine(id: "curated-yin-jiu-5-1", order: 0, text: "结庐在人境，而无车马喧。"),
                    PoemLine(id: "curated-yin-jiu-5-2", order: 1, text: "问君何能尔？心远地自偏。"),
                    PoemLine(id: "curated-yin-jiu-5-3", order: 2, text: "采菊东篱下，悠然见南山。"),
                    PoemLine(id: "curated-yin-jiu-5-4", order: 3, text: "山气日夕佳，飞鸟相与还。"),
                    PoemLine(id: "curated-yin-jiu-5-5", order: 4, text: "此中有真意，欲辨已忘言。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#53633B", secondaryHex: "#D2C278", tertiaryHex: "#293129", glyph: "菊"),
                sourceName: "古典文学公版文本 · Poemery 校订",
                sourceLicense: "古典原文公版",
                themes: ["田园", "隐逸", "自然", "菊花", "人生哲理"],
                canonicalKey: "魏晋|陶渊明|饮酒·其五"
            ),
            Poem(
                id: "curated-chi-le-ge",
                title: "敕勒歌",
                author: "佚名",
                dynasty: "南北朝",
                form: "乐府民歌",
                tags: ["南北朝民歌", "草原", "民歌"],
                summary: "以简洁开阔的语言描绘北方草原与牛羊风光。",
                lines: [
                    PoemLine(id: "curated-chi-le-ge-1", order: 0, text: "敕勒川，阴山下。"),
                    PoemLine(id: "curated-chi-le-ge-2", order: 1, text: "天似穹庐，笼盖四野。"),
                    PoemLine(id: "curated-chi-le-ge-3", order: 2, text: "天苍苍，野茫茫，风吹草低见牛羊。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#48705B", secondaryHex: "#BFCB83", tertiaryHex: "#28352E", glyph: "野"),
                sourceName: "古典文学公版文本 · Poemery 校订",
                sourceLicense: "古典原文公版",
                themes: ["草原", "北方", "山河", "牛羊", "民歌"],
                canonicalKey: "南北朝|佚名|敕勒歌"
            ),
            Poem(
                id: "curated-yu-mei-ren",
                title: "虞美人·春花秋月何时了",
                author: "李煜",
                dynasty: "五代",
                form: "词",
                tags: ["五代词", "故国", "怀旧"],
                summary: "由春花秋月触发故国之思，以一江春水写绵延不尽的愁绪。",
                lines: [
                    PoemLine(id: "curated-yu-mei-ren-1", order: 0, text: "春花秋月何时了？往事知多少。"),
                    PoemLine(id: "curated-yu-mei-ren-2", order: 1, text: "小楼昨夜又东风，故国不堪回首月明中。"),
                    PoemLine(id: "curated-yu-mei-ren-3", order: 2, text: "雕栏玉砌应犹在，只是朱颜改。"),
                    PoemLine(id: "curated-yu-mei-ren-4", order: 3, text: "问君能有几多愁？恰似一江春水向东流。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#50618B", secondaryHex: "#B8AED9", tertiaryHex: "#292A3A", glyph: "愁"),
                sourceName: "古典文学公版文本 · Poemery 校订",
                sourceLicense: "古典原文公版",
                themes: ["故国", "怀旧", "春水", "月夜", "愁绪"],
                canonicalKey: "五代|李煜|虞美人·春花秋月何时了"
            ),
            Poem(
                id: "curated-shi-hui-yin",
                title: "石灰吟",
                author: "于谦",
                dynasty: "明",
                form: "七言绝句",
                tags: ["明诗", "咏物", "言志"],
                summary: "借石灰的锤炼过程写坚守清白、不惧磨难的品格。",
                lines: [
                    PoemLine(id: "curated-shi-hui-yin-1", order: 0, text: "千锤万凿出深山，烈火焚烧若等闲。"),
                    PoemLine(id: "curated-shi-hui-yin-2", order: 1, text: "粉骨碎身浑不怕，要留清白在人间。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#697278", secondaryHex: "#DAD4BE", tertiaryHex: "#2D3336", glyph: "石"),
                sourceName: "古典文学公版文本 · Poemery 校订",
                sourceLicense: "古典原文公版",
                themes: ["咏物", "品格", "清白", "坚守", "励志"],
                canonicalKey: "明|于谦|石灰吟"
            ),
            Poem(
                id: "curated-ji-hai-za-shi-5",
                title: "己亥杂诗·其五",
                author: "龚自珍",
                dynasty: "清",
                form: "七言绝句",
                tags: ["清诗", "落花", "言志"],
                summary: "离京惜别之际，以落花化泥写离开之后仍愿护持新生。",
                lines: [
                    PoemLine(id: "curated-ji-hai-za-shi-5-1", order: 0, text: "浩荡离愁白日斜，吟鞭东指即天涯。"),
                    PoemLine(id: "curated-ji-hai-za-shi-5-2", order: 1, text: "落红不是无情物，化作春泥更护花。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#8C4A52", secondaryHex: "#D9A693", tertiaryHex: "#31292D", glyph: "花"),
                sourceName: "古典文学公版文本 · Poemery 校订",
                sourceLicense: "古典原文公版",
                themes: ["离别", "落花", "奉献", "春天", "新生"],
                canonicalKey: "清|龚自珍|己亥杂诗·其五"
            ),
            Poem(
                id: "curated-chang-xiang-si",
                title: "长相思·山一程",
                author: "纳兰性德",
                dynasty: "清",
                form: "词",
                tags: ["清词", "行旅", "思乡"],
                summary: "在山水关程与风雪夜声中，写旅途劳顿和深切乡思。",
                lines: [
                    PoemLine(id: "curated-chang-xiang-si-1", order: 0, text: "山一程，水一程，身向榆关那畔行，夜深千帐灯。"),
                    PoemLine(id: "curated-chang-xiang-si-2", order: 1, text: "风一更，雪一更，聒碎乡心梦不成，故园无此声。")
                ],
                annotations: [],
                sourceURL: nil,
                artworkStyle: ArtworkStyle(primaryHex: "#405D72", secondaryHex: "#B7CCD1", tertiaryHex: "#263039", glyph: "雪"),
                sourceName: "古典文学公版文本 · Poemery 校订",
                sourceLicense: "古典原文公版",
                themes: ["行旅", "思乡", "风雪", "边塞", "夜晚"],
                canonicalKey: "清|纳兰性德|长相思·山一程"
            )
        ]

        return PoemSeedCatalog(
            poems: poems,
            collections: [
                PoemCollection(
                    id: "curated-through-the-ages",
                    title: "千年诗路",
                    subtitle: "从汉魏风骨到明清新声",
                    kind: .featured,
                    poemIDs: poems.map(\.id),
                    accent: ArtworkStyle(primaryHex: "#A74437", secondaryHex: "#DDB66F", tertiaryHex: "#263438", glyph: "年")
                )
            ],
            categories: [
                PoemCategory(id: "curated-category-festival", title: "岁时节令", subtitle: "在诗里遇见传统节日", tag: "节令", artworkStyle: ArtworkStyle(primaryHex: "#B84034", secondaryHex: "#E9A755", tertiaryHex: "#303535", glyph: "节"), symbol: "sparkles"),
                PoemCategory(id: "curated-category-later-dynasties", title: "明清诗词", subtitle: "发现主库之外的时代新声", tag: "清诗", artworkStyle: ArtworkStyle(primaryHex: "#405D72", secondaryHex: "#B7CCD1", tertiaryHex: "#263039", glyph: "清"), symbol: "books.vertical.fill")
            ]
        )
    }

    nonisolated static func bundledSQLiteCatalogURLForTests() -> URL? {
        Bundle.main.url(forResource: "PoemLibrary", withExtension: "sqlite")
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

private extension Poem {
    func replacingID(_ id: Poem.ID) -> Poem {
        let lineIDMap = Dictionary(uniqueKeysWithValues: lines.map { ($0.id, "\(id)-line-\($0.order)") })
        let updatedLines = lines.map { line in
            PoemLine(id: lineIDMap[line.id] ?? line.id, order: line.order, text: line.text)
        }
        let updatedAnnotations = annotations.map { annotation in
            PoemAnnotation(
                id: "\(id)-annotation-\(annotation.id)",
                lineID: lineIDMap[annotation.lineID] ?? annotation.lineID,
                term: annotation.term,
                reading: annotation.reading,
                summary: annotation.summary,
                detail: annotation.detail
            )
        }
        let updatedSupplement = supplement.map { supplement in
            PoemSupplement(
                pronunciations: supplement.pronunciations.map { pronunciation in
                    PoemPronunciationLine(
                        lineID: lineIDMap[pronunciation.lineID] ?? pronunciation.lineID,
                        text: pronunciation.text
                    )
                },
                translation: supplement.translation,
                appreciation: supplement.appreciation,
                sourceName: supplement.sourceName,
                sourceURL: supplement.sourceURL,
                sourceLicense: supplement.sourceLicense
            )
        }

        return Poem(
            id: id,
            title: title,
            author: author,
            dynasty: dynasty,
            form: form,
            tags: tags,
            summary: summary,
            lines: updatedLines,
            annotations: updatedAnnotations,
            sourceURL: sourceURL,
            artworkStyle: artworkStyle,
            sourceName: sourceName,
            sourceLicense: sourceLicense,
            editorialSummary: editorialSummary,
            themes: themes,
            difficulty: difficulty,
            canonicalKey: canonicalKey,
            supplement: updatedSupplement,
            searchMatch: searchMatch
        )
    }
}

private extension PoemLibraryStore {
    nonisolated static let authorPopularity: [String: Int] = [
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

    nonisolated static let popularTitleKeywords: [(title: String, score: Int)] = [
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

    nonisolated static let classicTagPopularity: [String: Int] = [
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

    nonisolated static let highFrequencyKeywordCandidates = [
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
