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

    func testPoemMetadataDefaultsAreCompatibleWithOldCatalogs() {
        let poem = Self.sampleCatalog.poems[0]

        XCTAssertEqual(poem.sourceLicense, "MIT")
        XCTAssertFalse(poem.sourceName.isEmpty)
        XCTAssertFalse(poem.editorialSummary.isEmpty)
        XCTAssertTrue(poem.themes.contains("唐"))
        XCTAssertGreaterThanOrEqual(poem.difficulty, 1)
        XCTAssertEqual(poem.canonicalKey, "唐|李白|静夜思")
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
        XCTAssertEqual(authors.first?.poems.map(\.title), ["静夜思"])
    }

    func testAuthorLookupFindsAggregatedAuthorForPoem() throws {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)
        let poem = store.poems[0]

        let author = try XCTUnwrap(store.author(for: poem))

        XCTAssertEqual(author.name, "李白")
        XCTAssertEqual(store.author(id: author.id)?.name, "李白")
    }

    func testAuthorIntroductionUsesKnownAndFallbackText() throws {
        let store = PoemLibraryStore(catalog: Self.sampleCatalog)
        let knownAuthor = try XCTUnwrap(store.author(for: store.poems[0]))
        let fallbackAuthor = AuthorResult(
            id: "唐-测试作者",
            name: "测试作者",
            dynasty: "唐",
            poems: [store.poems[1]]
        )

        XCTAssertTrue(knownAuthor.introduction.contains("诗仙"))
        XCTAssertTrue(fallbackAuthor.introduction.contains("当前诗库收录 1 首作品"))
    }

    func testBundledCatalogHasExpectedShape() async throws {
        let store = try await PoemLibraryStore.loadBundled()

        XCTAssertEqual(store.poems.count, 12042)
        XCTAssertGreaterThanOrEqual(store.collections.count, 26)
        XCTAssertGreaterThanOrEqual(store.categories.count, 13)
        XCTAssertEqual(store.poems(forTheme: "论语").count, 20)
        XCTAssertEqual(store.poems(forTheme: "诗经").count, 305)
        XCTAssertEqual(store.poems(forTheme: "四书五经").count, 16)
        XCTAssertTrue(store.collections.allSatisfy { collection in
            !store.poems(for: collection).isEmpty
        })
        XCTAssertTrue(store.poems.allSatisfy { poem in
            !poem.sourceName.isEmpty
                && !poem.sourceLicense.isEmpty
                && !poem.editorialSummary.isEmpty
                && !poem.themes.isEmpty
                && (1...5).contains(poem.difficulty)
                && !poem.canonicalKey.isEmpty
        })
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
        let poem = store.poems[0]

        session.toggleFavorite(poem)
        XCTAssertTrue(session.isFavorite(poem))

        session.toggleFavorite(poem)
        XCTAssertFalse(session.isFavorite(poem))

        session.toggleFavorite(poem)
        session.clearFavorites()
        XCTAssertTrue(session.favoritePoemIDs.isEmpty)
    }

    func testRecentPoemsDeduplicateAndKeepTwentyItems() {
        let poems = (0..<25).map { index in
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

        XCTAssertEqual(session.recentPoemIDs.count, 20)
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
        let poems = Array(store.poems.prefix(2))
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
