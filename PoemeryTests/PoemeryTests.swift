import XCTest
@testable import Poemery

@MainActor
final class PoemeryTests: XCTestCase {
    func testSearchReturnsEmptyForBlankQuery() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        XCTAssertTrue(store.search("   ").isEmpty)
    }

    func testSearchMatchesMultipleTokensAcrossPoemFields() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        let results = store.search("李白 明月")

        XCTAssertEqual(results.poems.map(\.title), ["静夜思"])
        XCTAssertEqual(results.authors.map(\.name), [])
    }

    func testSearchMatchesTraditionalAndAuthorAliases() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        XCTAssertEqual(store.search("靜夜").poems.first?.title, "静夜思")
        XCTAssertEqual(store.search("太白 明月").poems.first?.author, "李白")
    }

    func testChineseScriptConverterSwitchesBetweenSimplifiedAndTraditional() {
        let traditional = ChineseTextConverter.convert("设置 诗词 龙 后", to: .traditional)
        let simplified = ChineseTextConverter.convert(traditional, to: .simplified)

        XCTAssertEqual(traditional, "設置 詩詞 龍 後")
        XCTAssertEqual(simplified, "设置 诗词 龙 后")
    }

    func testCatalogConversionKeepsIDsAndConvertsDisplayedText() {
        let catalog = Self.sampleCatalog.converted(to: .traditional)
        let poem = catalog.poems[0]

        XCTAssertEqual(poem.id, "jing-ye-si")
        XCTAssertEqual(poem.title, "靜夜思")
        XCTAssertEqual(poem.lines.first?.text, "床前明月光，疑是地上霜。")
        XCTAssertEqual(catalog.collections.first?.title, "樣本詩單")
        XCTAssertEqual(catalog.categories.first?.title, "唐詩")
    }

    func testSearchPagePaginatesShortChineseTokenMatches() async {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        let firstPage = await store.searchPage("月", limit: 1)
        let secondPage = await store.searchPage("月", cursor: firstPage.nextCursor, limit: 1)
        let combinedPage = firstPage.appending(secondPage)

        XCTAssertEqual(firstPage.totalPoemCount, 2)
        XCTAssertEqual(firstPage.poems.map(\.title), ["静夜思"])
        XCTAssertNotNil(firstPage.nextCursor)
        XCTAssertEqual(secondPage.poems.map(\.title), ["秋日"])
        XCTAssertNil(secondPage.nextCursor)
        XCTAssertEqual(combinedPage.poems.map(\.title), ["静夜思", "秋日"])
        XCTAssertEqual(combinedPage.poemIDs, ["jing-ye-si", "ordinary"])
    }

    func testSearchPageMatchesPhrasesWithChineseBigrams() async {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        let results = await store.searchPage("床前明月", limit: 10)

        XCTAssertEqual(results.poems.map(\.title), ["静夜思"])
        XCTAssertEqual(results.totalPoemCount, 1)
    }

    func testSearchPagePreservesTraditionalAndAliasMatches() async {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        let traditionalResults = await store.searchPage("靜夜", limit: 10)
        let aliasResults = await store.searchPage("太白 明月", limit: 10)

        XCTAssertEqual(traditionalResults.poems.first?.title, "静夜思")
        XCTAssertEqual(aliasResults.poems.first?.author, "李白")
    }

    func testPoemMetadataDefaultsAreCompatibleWithOldCatalogs() {
        let poem = Self.sampleCatalog.poems[0]

        XCTAssertEqual(poem.sourceLicense, "MIT")
        XCTAssertFalse(poem.sourceName.isEmpty)
        XCTAssertFalse(poem.editorialSummary.isEmpty)
        XCTAssertTrue(poem.themes.contains("唐"))
        XCTAssertGreaterThanOrEqual(poem.difficulty, 1)
        XCTAssertEqual(poem.canonicalKey, "唐|李白|静夜思")
        XCTAssertNil(poem.supplement)
    }

    func testSupplementConversionKeepsPronunciationAndConvertsEditorialText() {
        let line = PoemLine(id: "line-1", order: 0, text: "风吹万户")
        let poem = Poem(
            id: "supplement-sample",
            title: "样本",
            author: "作者",
            dynasty: "宋",
            form: "诗",
            tags: [],
            summary: "样本",
            lines: [line],
            annotations: [],
            sourceURL: nil,
            artworkStyle: .fallback,
            supplement: PoemSupplement(
                pronunciations: [PoemPronunciationLine(lineID: line.id, text: "fēng chuī wàn hù")],
                translation: "风吹过万户。",
                appreciation: "语言简练。"
            )
        )

        let converted = PoemSeedCatalog(poems: [poem], collections: [], categories: []).converted(to: .traditional).poems[0]

        XCTAssertEqual(converted.supplement?.pronunciations.first?.text, "fēng chuī wàn hù")
        XCTAssertEqual(converted.supplement?.translation, "風吹過萬戶。")
        XCTAssertEqual(converted.supplement?.appreciation, "語言簡練。")
    }

    func testBootstrapLibraryIsImmediatelyReadableAndCoversMoreDynasties() {
        let store = PoemLibraryStore.bootstrap()
        let dynasties = Set(store.dynasties())

        XCTAssertFalse(store.cachedPoems().isEmpty)
        XCTAssertNotNil(store.cachedPoems().first { $0.title == "元日" && $0.author == "王安石" }?.supplement)
        XCTAssertTrue(["汉", "魏晋", "南北朝", "五代", "明", "清"].allSatisfy(dynasties.contains))
    }

    func testPopularPoemsPreferClassicTitles() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        XCTAssertEqual(store.popularPoems(limit: 1).first?.title, "静夜思")
    }

    func testFrequentKeywordsAggregateMatchingPoems() throws {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        let keyword = try XCTUnwrap(store.frequentKeywords(limit: 4).first { $0.text == "月" })

        XCTAssertEqual(keyword.count, 2)
        XCTAssertEqual(store.poems(forKeyword: keyword).map(\.title), ["静夜思", "秋日"])
    }

    func testChartPoemsUsePopularityOrder() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        XCTAssertEqual(store.chartPoems(limit: 2).map(\.title), ["静夜思", "秋日"])
    }

    func testDisplayArtworkStyleIsStableForSamePoem() {
        let poem = Self.sampleCatalog.poems[0]

        XCTAssertEqual(poem.displayArtworkStyle, poem.displayArtworkStyle)
    }

    func testDisplayArtworkStyleVariesBetweenPoems() {
        let styles = Set(Self.sampleCatalog.poems.map(\.displayArtworkStyle))

        XCTAssertGreaterThan(styles.count, 1)
    }

    func testDisplayArtworkStyleUsesTitleGlyph() {
        let poem = Self.sampleCatalog.poems[0]

        XCTAssertEqual(poem.displayArtworkStyle.glyph, "静")
    }

    func testAuthorsAreAggregatedAndSortedByPopularity() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        let authors = store.popularAuthors(limit: 2)

        XCTAssertEqual(authors.first?.name, "李白")
        XCTAssertEqual(authors.first.map(store.poemsByAuthor)?.map(\.title), ["静夜思"])
    }

    func testAuthorLookupFindsAggregatedAuthorForPoem() throws {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)
        let poem = store.cachedPoems()[0]

        let author = try XCTUnwrap(store.author(for: poem))

        XCTAssertEqual(author.name, "李白")
        XCTAssertEqual(store.author(id: author.id)?.name, "李白")
    }

    func testAuthorIntroductionUsesKnownAndFallbackText() throws {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)
        let knownAuthor = try XCTUnwrap(store.author(for: store.cachedPoems()[0]))
        let fallbackAuthor = AuthorResult(
            id: "唐-测试作者",
            name: "测试作者",
            dynasty: "唐",
            poemCount: 1
        )

        XCTAssertTrue(knownAuthor.introduction.contains("诗仙"))
        XCTAssertTrue(fallbackAuthor.introduction.contains("当前诗库收录 1 首作品"))
    }

    func testBundledLibraryBootstrapsWithoutMaterializingTheCatalog() async throws {
        let store = try await PoemLibraryStore.loadBundled()

        XCTAssertEqual(store.totalPoemCount, 33_786)
        XCTAssertLessThanOrEqual(store.cachedPoemCount, 300)
        XCTAssertTrue(store.popularPoems(limit: 24).allSatisfy { $0.lines.isEmpty })
        XCTAssertGreaterThanOrEqual(store.collections.count, 26)
        XCTAssertGreaterThanOrEqual(store.categories.count, 15)
        let dynasties = Set(store.dynasties())
        XCTAssertTrue(["汉", "魏晋", "南北朝", "五代", "明", "清"].allSatisfy(dynasties.contains))
        XCTAssertNotNil(store.collections.first { $0.title == "全宋词" })
        XCTAssertNotNil(store.collections.first { $0.title == "楚辞" })
        XCTAssertNotNil(store.collections.first { $0.title == "曹操诗集" })
    }

    func testSQLiteQueryActorLoadsSummariesThenDetailOnDemand() async throws {
        let sqliteURL = try XCTUnwrap(PoemLibraryStore.bundledSQLiteCatalogURLForTests())
        let repository = SQLitePoemLibraryQueryActor(url: sqliteURL)
        let bootstrap = try await repository.bootstrap(script: .simplified)
        let firstPage = try await repository.poemPage(query: .all, limit: 50)

        XCTAssertEqual(bootstrap.stats.totalPoems, 33_786)
        XCTAssertEqual(firstPage.items.count, 50)
        XCTAssertTrue(firstPage.items.allSatisfy { $0.lines.isEmpty })
        XCTAssertNotNil(firstPage.nextCursor)

        let firstID = try XCTUnwrap(firstPage.items.first?.id)
        let loadedDetail = try await repository.poemDetail(id: firstID)
        let detail = try XCTUnwrap(loadedDetail)
        XCTAssertFalse(detail.lines.isEmpty)
        XCTAssertEqual(detail.id, firstID)
    }

    func testSQLiteFTSReturnsBodySnippetWithoutLoadingDetails() async throws {
        let sqliteURL = try XCTUnwrap(PoemLibraryStore.bundledSQLiteCatalogURLForTests())
        let repository = SQLitePoemLibraryQueryActor(url: sqliteURL)
        let page = try await repository.searchPage("明月光", limit: 50)

        XCTAssertFalse(page.poems.isEmpty)
        XCTAssertTrue(page.poems.contains { $0.searchMatch?.kind == .content })
    }

    func testDiscoveryIsStableForASeedAndChangesForAnotherBatch() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        let first = store.discoveryPoems(seed: "2026-08-11|0").map(\.id)
        let repeated = store.discoveryPoems(seed: "2026-08-11|0").map(\.id)
        let refreshed = store.discoveryPoems(seed: "2026-08-11|1").map(\.id)

        XCTAssertEqual(first, repeated)
        XCTAssertNotEqual(first, refreshed)
    }

    func testLibraryCanBrowseByThemeDynastyAndForm() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        XCTAssertEqual(store.poems(forTheme: "思乡").map(\.title), ["静夜思"])
        XCTAssertEqual(store.poems(forDynasty: "唐").count, 2)
        XCTAssertEqual(store.poems(forForm: "五言绝句").map(\.title), ["静夜思"])
        XCTAssertTrue(store.dynasties().contains("唐"))
        XCTAssertTrue(store.forms(limit: 2).contains("五言绝句"))
    }

    func testLimitedThemeBrowseStopsAtRequestedLimitInPopularOrder() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)

        XCTAssertEqual(store.poems(forTheme: "唐", limit: 1).map(\.title), ["静夜思"])
    }

    func testFavoritesToggleAndClear() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)
        let session = ReadingSessionStore(defaults: makeDefaults())
        let poem = store.cachedPoems()[0]

        session.toggleFavorite(poem)
        XCTAssertTrue(session.isFavorite(poem))

        session.toggleFavorite(poem)
        XCTAssertFalse(session.isFavorite(poem))

        session.toggleFavorite(poem)
        session.clearFavorites()
        XCTAssertTrue(session.favoritePoemIDs.isEmpty)
    }

    func testRecentPoemsDeduplicateAndKeepFiftyItems() {
        let poems = (0..<55).map { index in
            Self.poem(
                id: "poem-\(index)",
                title: "作品\(index)",
                author: "作者\(index)",
                text: "第\(index)首"
            )
        }
        let session = ReadingSessionStore(defaults: makeDefaults())

        for poem in poems {
            session.startReading(poem, in: .singlePoem(poem))
        }
        session.startReading(poems[10], in: .singlePoem(poems[10]))

        XCTAssertEqual(session.recentPoemIDs.count, 50)
        XCTAssertEqual(session.recentPoemIDs.first, poems[10].id)
        XCTAssertEqual(Set(session.recentPoemIDs).count, session.recentPoemIDs.count)

        session.clearRecents()
        XCTAssertTrue(session.recentPoemIDs.isEmpty)
        XCTAssertNil(session.currentPoemID)
        XCTAssertNil(session.currentQueue)
    }

    func testReadingQueueMovesForwardAndBackward() {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)
        let session = ReadingSessionStore(defaults: makeDefaults())
        let poems = Array(store.cachedPoems().prefix(2))
        let queue = ReadingQueue(title: "测试队列", poems: poems)

        session.startReading(poems[0], in: queue)

        XCTAssertEqual(session.moveToNextPoem(in: store)?.id, poems[1].id)
        XCTAssertEqual(session.moveToPreviousPoem(in: store)?.id, poems[0].id)
    }

    private func makeDefaults(file: StaticString = #filePath, line: UInt = #line) -> UserDefaults {
        let suiteName = "PoemeryTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create UserDefaults suite", file: file, line: line)
            return .standard
        }
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private static let sampleCatalog = PoemSeedCatalog(
        poems: [
            poem(
                id: "jing-ye-si",
                title: "静夜思",
                author: "李白",
                form: "五言绝句",
                tags: ["唐诗三百首", "思乡"],
                text: "床前明月光，疑是地上霜。"
            ),
            poem(
                id: "ordinary",
                title: "秋日",
                author: "佚名",
                form: "诗",
                tags: ["唐诗"],
                text: "秋月起。"
            )
        ],
        collections: [
            PoemCollection(
                id: "sample-collection",
                title: "样本诗单",
                subtitle: "2 首作品",
                kind: .featured,
                poemIDs: ["jing-ye-si", "ordinary"],
                accent: .fallback
            )
        ],
        categories: [
            PoemCategory(
                id: "sample-category",
                title: "唐诗",
                subtitle: "样本",
                tag: "唐诗",
                artworkStyle: .fallback,
                symbol: "book.closed.fill"
            )
        ]
    )

    private static func poem(
        id: String,
        title: String,
        author: String,
        dynasty: String = "唐",
        form: String = "诗",
        tags: [String] = [],
        text: String
    ) -> Poem {
        Poem(
            id: id,
            title: title,
            author: author,
            dynasty: dynasty,
            form: form,
            tags: tags,
            summary: "测试数据",
            lines: [
                PoemLine(id: "\(id)-1", order: 0, text: text)
            ],
            annotations: [],
            sourceURL: nil,
            artworkStyle: .fallback
        )
    }
}
