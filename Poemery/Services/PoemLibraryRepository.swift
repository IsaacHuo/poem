import Foundation
import OSLog
import SQLite3

enum PoemPageQuery: Sendable, Hashable {
    case all
    case popular
    case collection(PoemCollection.ID)
    case author(AuthorResult.ID)
    case dynasty(String)
    case form(String)
    case theme(String)
}

actor SQLitePoemLibraryQueryActor {
    private static let signposter = OSSignposter(
        subsystem: "com.poemery.app",
        category: "SQLiteQueries"
    )
    private let url: URL
    private nonisolated let interruptController = SQLiteInterruptController()
    private var database: SQLiteDatabase?

    init(url: URL) {
        self.url = url
    }

    func bootstrap(script: ChineseScriptPreference) throws -> PoemLibraryBootstrap {
        let state = Self.signposter.beginInterval("bootstrap")
        defer { Self.signposter.endInterval("bootstrap", state) }
        return try resolvedDatabase().readBootstrap().converted(to: script)
    }

    func poemPage(
        query: PoemPageQuery,
        cursor: PageCursor? = nil,
        limit: Int = 50
    ) throws -> PageResult<Poem> {
        let state = Self.signposter.beginInterval("poem-page")
        defer { Self.signposter.endInterval("poem-page", state) }
        return try resolvedDatabase().readPoemPage(query: query, cursor: cursor, limit: limit)
    }

    func poemDetail(id: Poem.ID) throws -> PoemDetail? {
        let state = Self.signposter.beginInterval("poem-detail")
        defer { Self.signposter.endInterval("poem-detail", state) }
        return try resolvedDatabase().readPoemDetail(id: id)
    }

    func poemSummaries(ids: [Poem.ID]) throws -> [Poem] {
        try resolvedDatabase().readPoemSummaries(ids: ids)
    }

    func authorPage(cursor: PageCursor? = nil, limit: Int = 50) throws -> PageResult<AuthorResult> {
        try resolvedDatabase().readAuthorPage(cursor: cursor, limit: limit)
    }

    func searchPage(_ query: String, cursor: SearchPageCursor? = nil, limit: Int) throws -> SearchResultsPage {
        let state = Self.signposter.beginInterval("search-page")
        defer { Self.signposter.endInterval("search-page", state) }
        return try resolvedDatabase().searchPage(query, cursor: cursor, limit: limit)
    }

    nonisolated func interrupt() {
        interruptController.interrupt()
    }

    private func resolvedDatabase() throws -> SQLiteDatabase {
        if let database {
            return database
        }
        let database = try SQLiteDatabase(url: url, immutable: true)
        interruptController.register(database.handle)
        self.database = database
        return database
    }
}

enum PoemLibraryRepositoryError: LocalizedError, Equatable {
    case missingBundledCatalog
    case sqliteOpenFailed(String)
    case sqlitePrepareFailed(String)
    case sqliteStepFailed(String)
    case invalidCollectionKind(String)

    var errorDescription: String? {
        switch self {
        case .missingBundledCatalog:
            "Missing PoemLibrary.sqlite from the app bundle."
        case .sqliteOpenFailed(let reason):
            "Failed to open PoemLibrary.sqlite: \(reason)"
        case .sqlitePrepareFailed(let reason):
            "Failed to prepare SQLite statement: \(reason)"
        case .sqliteStepFailed(let reason):
            "Failed to read SQLite rows: \(reason)"
        case .invalidCollectionKind(let rawValue):
            "Invalid collection kind in PoemLibrary.sqlite: \(rawValue)"
        }
    }
}

private final class SQLiteDatabase {
    fileprivate let handle: OpaquePointer

    init(url: URL, immutable: Bool = false) throws {
        var database: OpaquePointer?
        let flags: Int32
        let path: String
        if immutable {
            flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX
            path = url.absoluteString + "?mode=ro&immutable=1"
        } else {
            flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
            path = url.path
        }

        guard sqlite3_open_v2(path, &database, flags, nil) == SQLITE_OK, let database else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite open error"
            if let database {
                sqlite3_close(database)
            }
            throw PoemLibraryRepositoryError.sqliteOpenFailed(message)
        }

        self.handle = database
    }

    deinit {
        sqlite3_close(handle)
    }

    func interrupt() {
        sqlite3_interrupt(handle)
    }

    func readBootstrap() throws -> PoemLibraryBootstrap {
        let stats = PoemeryStats(
            totalPoems: try scalarInt("SELECT COUNT(*) AS value FROM poems"),
            totalAuthors: try scalarInt("SELECT COUNT(*) AS value FROM authors"),
            totalCollections: try scalarInt("SELECT COUNT(*) AS value FROM collections"),
            totalCategories: try scalarInt("SELECT COUNT(*) AS value FROM categories")
        )

        let collections = try readCollections()
        let categories = try readCategories()
        let authors = try rows(
            """
            SELECT a.id, a.name, a.dynasty, a.poem_count, p.profile_json
            FROM authors a LEFT JOIN author_profiles p ON p.id = a.id
            ORDER BY a.sort_order LIMIT 24
            """
        ).map { row in
            let profile = row.optionalString("profile_json").flatMap {
                AuthorProfile.decode(from: Data($0.utf8))
            }
            return AuthorResult(
                id: row.string("id"),
                name: row.string("name"),
                dynasty: row.string("dynasty"),
                poemCount: row.int("poem_count"),
                profile: profile
            )
        }
        let dynasties = try rows(
            """
            SELECT dynasty, COUNT(*) AS poem_count
            FROM poems GROUP BY dynasty
            ORDER BY poem_count DESC, dynasty
            """
        ).map { $0.string("dynasty") }
        let forms = try rows(
            """
            SELECT form, COUNT(*) AS poem_count
            FROM poems GROUP BY form
            ORDER BY poem_count DESC, form
            """
        ).map { $0.string("form") }
        let popularPoems = try readPoemPage(query: .popular, cursor: nil, limit: 24).items
        let keywords = try categories.prefix(16).map { category in
            let count = try scalarInt(
                "SELECT COUNT(DISTINCT poem_id) AS value FROM poem_tags WHERE tag = ?",
                parameters: [.text(category.tag)]
            )
            return PoemKeyword(id: category.id, text: category.tag, count: count, poemIDs: [])
        }

        return PoemLibraryBootstrap(
            stats: stats,
            collections: collections,
            categories: categories,
            authors: authors,
            keywords: keywords,
            dynasties: dynasties,
            forms: forms,
            popularPoems: popularPoems
        )
    }

    func readPoemPage(
        query: PoemPageQuery,
        cursor: PageCursor?,
        limit: Int
    ) throws -> PageResult<Poem> {
        let pageLimit = max(1, min(limit, 100))
        var parameters: [SQLiteParameter] = []
        let source: String
        let orderColumn: String
        let totalSQL: String
        let totalParameters: [SQLiteParameter]

        switch query {
        case .all:
            source = "poems p"
            orderColumn = "p.sort_order"
            totalSQL = "SELECT COUNT(*) AS value FROM poems"
            totalParameters = []
        case .popular:
            source = "poems p"
            orderColumn = "p.popularity_rank"
            totalSQL = "SELECT COUNT(*) AS value FROM poems"
            totalParameters = []
        case .collection(let id):
            source = "collection_poems link JOIN poems p ON p.id = link.poem_id"
            orderColumn = "link.poem_order"
            parameters.append(.text(id))
            totalSQL = "SELECT COUNT(*) AS value FROM collection_poems WHERE collection_id = ?"
            totalParameters = [.text(id)]
        case .author(let id):
            source = "author_poems link JOIN poems p ON p.id = link.poem_id"
            orderColumn = "link.poem_order"
            parameters.append(.text(id))
            totalSQL = "SELECT COUNT(*) AS value FROM author_poems WHERE author_id = ?"
            totalParameters = [.text(id)]
        case .dynasty(let value):
            source = "poems p"
            orderColumn = "p.popularity_rank"
            parameters.append(.text(value))
            totalSQL = "SELECT COUNT(*) AS value FROM poems WHERE dynasty = ?"
            totalParameters = [.text(value)]
        case .form(let value):
            source = "poems p"
            orderColumn = "p.popularity_rank"
            parameters.append(.text(value))
            totalSQL = "SELECT COUNT(*) AS value FROM poems WHERE form = ?"
            totalParameters = [.text(value)]
        case .theme(let value):
            source = "poem_themes link JOIN poems p ON p.id = link.poem_id"
            orderColumn = "p.popularity_rank"
            parameters.append(.text(value))
            totalSQL = "SELECT COUNT(DISTINCT poem_id) AS value FROM poem_themes WHERE theme = ?"
            totalParameters = [.text(value)]
        }

        var predicates: [String] = []
        switch query {
        case .collection: predicates.append("link.collection_id = ?")
        case .author: predicates.append("link.author_id = ?")
        case .dynasty: predicates.append("p.dynasty = ?")
        case .form: predicates.append("p.form = ?")
        case .theme: predicates.append("link.theme = ?")
        case .all, .popular: break
        }

        if let cursor {
            predicates.append("(\(orderColumn) > ? OR (\(orderColumn) = ? AND p.id > ?))")
            parameters.append(contentsOf: [.integer(cursor.order), .integer(cursor.order), .text(cursor.id)])
        }
        parameters.append(.integer(pageLimit + 1))
        let whereClause = predicates.isEmpty ? "" : "WHERE " + predicates.joined(separator: " AND ")
        let sql = """
            SELECT \(Self.summaryColumns), \(orderColumn) AS page_order
            FROM \(source)
            \(whereClause)
            ORDER BY \(orderColumn), p.id
            LIMIT ?
            """
        var pageRows = try rows(sql, parameters: parameters)
        let hasMore = pageRows.count > pageLimit
        if hasMore { pageRows.removeLast() }
        let items = pageRows.map(makePoemSummary)
        let nextCursor = hasMore ? pageRows.last.map {
            PageCursor(order: $0.int("page_order"), id: $0.string("id"))
        } : nil

        return PageResult(
            items: items,
            nextCursor: nextCursor,
            total: try scalarInt(totalSQL, parameters: totalParameters)
        )
    }

    func readPoemSummaries(ids: [Poem.ID]) throws -> [Poem] {
        guard !ids.isEmpty else { return [] }
        let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
        let found = try rows(
            "SELECT \(Self.summaryColumns) FROM poems p WHERE p.id IN (\(placeholders))",
            parameters: ids.map(SQLiteParameter.text)
        ).map(makePoemSummary)
        let byID = Dictionary(uniqueKeysWithValues: found.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    func readAuthorPage(cursor: PageCursor?, limit: Int) throws -> PageResult<AuthorResult> {
        let pageLimit = max(1, min(limit, 100))
        var predicate = ""
        var parameters: [SQLiteParameter] = []
        if let cursor {
            predicate = "WHERE a.sort_order > ? OR (a.sort_order = ? AND a.id > ?)"
            parameters = [.integer(cursor.order), .integer(cursor.order), .text(cursor.id)]
        }
        parameters.append(.integer(pageLimit + 1))
        var pageRows = try rows(
            """
            SELECT a.id, a.name, a.dynasty, a.poem_count, a.sort_order AS page_order,
                   p.profile_json
            FROM authors a LEFT JOIN author_profiles p ON p.id = a.id
            \(predicate)
            ORDER BY a.sort_order, a.id LIMIT ?
            """,
            parameters: parameters
        )
        let hasMore = pageRows.count > pageLimit
        if hasMore { pageRows.removeLast() }
        let authors = pageRows.map { row in
            let profile = row.optionalString("profile_json").flatMap {
                AuthorProfile.decode(from: Data($0.utf8))
            }
            return AuthorResult(
                id: row.string("id"), name: row.string("name"), dynasty: row.string("dynasty"),
                poemCount: row.int("poem_count"), profile: profile
            )
        }
        let nextCursor = hasMore ? pageRows.last.map {
            PageCursor(order: $0.int("page_order"), id: $0.string("id"))
        } : nil
        return PageResult(
            items: authors,
            nextCursor: nextCursor,
            total: try scalarInt("SELECT COUNT(*) AS value FROM authors")
        )
    }

    func readPoemDetail(id: Poem.ID) throws -> PoemDetail? {
        guard let row = try rows(
            "SELECT \(Self.detailColumns) FROM poems p WHERE p.id = ? LIMIT 1",
            parameters: [.text(id)]
        ).first else { return nil }

        let lines = try rows(
            "SELECT line_id, line_order, text FROM poem_lines WHERE poem_id = ? ORDER BY line_order",
            parameters: [.text(id)]
        ).map { PoemLine(id: $0.string("line_id"), order: $0.int("line_order"), text: $0.string("text")) }
        let annotations = try rows(
            """
            SELECT annotation_id, line_id, term, reading, summary, detail
            FROM poem_annotations WHERE poem_id = ? ORDER BY annotation_order
            """,
            parameters: [.text(id)]
        ).map {
            PoemAnnotation(
                id: $0.string("annotation_id"), lineID: $0.string("line_id"),
                term: $0.string("term"), reading: $0.string("reading"),
                summary: $0.string("summary"), detail: $0.string("detail")
            )
        }
        let tags = try rows(
            "SELECT tag FROM poem_tags WHERE poem_id = ? ORDER BY tag_order", parameters: [.text(id)]
        ).map { $0.string("tag") }
        let themes = try rows(
            "SELECT theme FROM poem_themes WHERE poem_id = ? ORDER BY theme_order", parameters: [.text(id)]
        ).map { $0.string("theme") }

        return makePoem(row: row, lines: lines, annotations: annotations, tags: tags, themes: themes)
    }

    func searchPage(_ query: String, cursor: SearchPageCursor?, limit: Int) throws -> SearchResultsPage {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return SearchResultsPage() }
        let safeLimit = max(1, min(limit, 50))
        let variants = Array(Set([
            trimmed,
            ChineseTextConverter.convert(trimmed, to: .simplified),
            ChineseTextConverter.convert(trimmed, to: .traditional)
        ]))
        if variants.allSatisfy({ $0.count < 3 }) {
            return try searchShortQuery(trimmed, variants: variants, cursor: cursor, limit: safeLimit)
        }
        let expression = variants
            .map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
            .joined(separator: " OR ")
        let total = try scalarInt(
            "SELECT COUNT(*) AS value FROM poem_fts WHERE poem_fts MATCH ?",
            parameters: [.text(expression)]
        )
        var cursorPredicate = ""
        var parameters: [SQLiteParameter] = [.text(expression)]
        if let cursor {
            cursorPredicate = "WHERE ranked.search_rank > ? OR (ranked.search_rank = ? AND ranked.search_rowid > ?)"
            parameters.append(contentsOf: [.real(cursor.rank), .real(cursor.rank), .integer(cursor.rowID)])
        }
        parameters.append(.integer(safeLimit + 1))
        var resultRows = try rows(
            """
            WITH ranked AS (
                SELECT rowid AS search_rowid, poem_id,
                       bm25(poem_fts, 0.0, 8.0, 6.0, 2.0, 1.0, 0.5) AS search_rank,
                       snippet(poem_fts, 4, '', '', '…', 18) AS match_snippet
                FROM poem_fts WHERE poem_fts MATCH ?
            )
            SELECT p.id, p.title, p.author, p.dynasty, p.form,
                   p.artwork_primary_hex, p.artwork_secondary_hex,
                   p.artwork_tertiary_hex, p.artwork_glyph, p.first_line,
                   ranked.match_snippet, ranked.search_rank, ranked.search_rowid
            FROM ranked JOIN poems p ON p.id = ranked.poem_id
            \(cursorPredicate)
            ORDER BY ranked.search_rank, ranked.search_rowid
            LIMIT ?
            """,
            parameters: parameters
        )
        let hasMore = resultRows.count > safeLimit
        if hasMore { resultRows.removeLast() }
        let poems = resultRows.map { row in
            PoemListItem(
                id: row.string("id"), title: row.string("title"), author: row.string("author"),
                dynasty: row.string("dynasty"), form: row.string("form"),
                artworkStyle: Self.artwork(from: row),
                searchMatch: SearchMatchSnippet(
                    kind: .content,
                    text: row.string("match_snippet"),
                    highlightedQuery: trimmed
                ),
                firstLinePreview: row.string("first_line")
            )
        }
        let nextCursor = hasMore ? resultRows.last.map {
            SearchPageCursor(rank: $0.double("search_rank"), rowID: $0.int("search_rowid"))
        } : nil
        let facets = cursor == nil ? try searchFacets(query: trimmed) : (authors: [], collections: [])
        return SearchResultsPage(
            poems: poems, authors: facets.authors, collections: facets.collections, totalPoemCount: total,
            nextCursor: nextCursor, poemIDs: poems.map(\.id)
        )
    }

    private func searchShortQuery(
        _ query: String,
        variants: [String],
        cursor: SearchPageCursor?,
        limit: Int
    ) throws -> SearchResultsPage {
        let patterns = variants.map { value in
            "%" + value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_") + "%"
        }
        let predicate = patterns.map { _ in
            "(poem_fts.title LIKE ? ESCAPE '\\' OR poem_fts.author LIKE ? ESCAPE '\\' OR poem_fts.metadata LIKE ? ESCAPE '\\' OR poem_fts.body LIKE ? ESCAPE '\\')"
        }.joined(separator: " OR ")
        let bindings = patterns.flatMap { pattern in
            Array(repeating: SQLiteParameter.text(pattern), count: 4)
        }
        let titlePredicate = patterns.map { _ in "poem_fts.title LIKE ? ESCAPE '\\'" }.joined(separator: " OR ")
        let authorPredicate = patterns.map { _ in "poem_fts.author LIKE ? ESCAPE '\\'" }.joined(separator: " OR ")
        let metadataPredicate = patterns.map { _ in "poem_fts.metadata LIKE ? ESCAPE '\\'" }.joined(separator: " OR ")
        let fieldBindings = patterns.map(SQLiteParameter.text)
        let total = try scalarInt(
            "SELECT COUNT(*) AS value FROM poem_fts WHERE \(predicate)",
            parameters: bindings
        )
        let scoreExpression = "(CAST(match_order AS REAL) * 1000000000 + popularity_rank)"
        var cursorPredicate = ""
        var cursorBindings: [SQLiteParameter] = []
        if let cursor {
            cursorPredicate = "WHERE search_rank > ? OR (search_rank = ? AND search_rowid > ?)"
            cursorBindings = [.real(cursor.rank), .real(cursor.rank), .integer(cursor.rowID)]
        }
        var resultRows = try rows(
            """
            WITH matched AS (
            SELECT p.id, p.title, p.author, p.dynasty, p.form,
                   p.artwork_primary_hex, p.artwork_secondary_hex,
                   p.artwork_tertiary_hex, p.artwork_glyph, p.first_line,
                   CASE WHEN (\(titlePredicate)) THEN 0
                        WHEN (\(authorPredicate)) THEN 1
                        WHEN (\(metadataPredicate)) THEN 2 ELSE 3 END AS match_order,
                   p.popularity_rank, poem_fts.rowid AS search_rowid
            FROM poem_fts JOIN poems p ON p.id = poem_fts.poem_id
            WHERE \(predicate)
            ), ranked AS (
                SELECT *, \(scoreExpression) AS search_rank FROM matched
            )
            SELECT * FROM ranked
            \(cursorPredicate)
            ORDER BY search_rank, search_rowid
            LIMIT ?
            """,
            parameters: fieldBindings + fieldBindings + fieldBindings
                + bindings + cursorBindings + [.integer(limit + 1)]
        )
        let hasMore = resultRows.count > limit
        if hasMore { resultRows.removeLast() }
        let items = resultRows.map { row in
            let kind: SearchMatchKind = row.int("match_order") == 0 ? .title
                : row.int("match_order") == 1 ? .author : .metadata
            let matchText = kind == .metadata ? row.string("first_line") : ""
            return PoemListItem(
                id: row.string("id"), title: row.string("title"), author: row.string("author"),
                dynasty: row.string("dynasty"), form: row.string("form"),
                artworkStyle: Self.artwork(from: row),
                searchMatch: SearchMatchSnippet(kind: kind, text: matchText, highlightedQuery: query),
                firstLinePreview: row.string("first_line")
            )
        }
        let nextCursor = hasMore ? resultRows.last.map {
            SearchPageCursor(rank: $0.double("search_rank"), rowID: $0.int("search_rowid"))
        } : nil
        let facets = cursor == nil ? try searchFacets(query: query) : (authors: [], collections: [])
        return SearchResultsPage(
            poems: items, authors: facets.authors, collections: facets.collections, totalPoemCount: total,
            nextCursor: nextCursor, poemIDs: items.map(\.id)
        )
    }

    private func searchFacets(query: String) throws -> (authors: [AuthorResult], collections: [PoemCollection]) {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        let pattern = "%\(escaped)%"
        let authors = try rows(
            """
            SELECT a.id, a.name, a.dynasty, a.poem_count, p.profile_json
            FROM authors a LEFT JOIN author_profiles p ON p.id = a.id
            WHERE a.name LIKE ? ESCAPE '\\'
            ORDER BY a.sort_order LIMIT 12
            """,
            parameters: [.text(pattern)]
        ).map { row in
            let profile = row.optionalString("profile_json").flatMap {
                AuthorProfile.decode(from: Data($0.utf8))
            }
            return AuthorResult(
                id: row.string("id"), name: row.string("name"), dynasty: row.string("dynasty"),
                poemCount: row.int("poem_count"), profile: profile
            )
        }
        let collections: [PoemCollection] = try rows(
            """
            SELECT c.id, c.title, c.subtitle, c.kind, c.accent_primary_hex,
                   c.accent_secondary_hex, c.accent_tertiary_hex, c.accent_glyph,
                   COUNT(cp.poem_id) AS poem_count
            FROM collections c LEFT JOIN collection_poems cp ON cp.collection_id = c.id
            WHERE c.title LIKE ? ESCAPE '\\' OR c.subtitle LIKE ? ESCAPE '\\'
            GROUP BY c.id ORDER BY c.sort_order LIMIT 8
            """,
            parameters: [.text(pattern), .text(pattern)]
        ).compactMap { row -> PoemCollection? in
            guard let kind = CollectionKind(rawValue: row.string("kind")) else { return nil }
            return PoemCollection(
                id: row.string("id"), title: row.string("title"), subtitle: row.string("subtitle"),
                kind: kind, poemCount: row.int("poem_count"), poemIDs: [],
                accent: ArtworkStyle(
                    primaryHex: row.string("accent_primary_hex"), secondaryHex: row.string("accent_secondary_hex"),
                    tertiaryHex: row.string("accent_tertiary_hex"), glyph: row.string("accent_glyph")
                )
            )
        }
        return (authors, collections)
    }

    private static let summaryColumns = """
        p.id, p.title, p.author, p.dynasty, p.form, p.summary,
        p.artwork_primary_hex, p.artwork_secondary_hex, p.artwork_tertiary_hex,
        p.artwork_glyph, p.first_line
        """

    private static let detailColumns = """
        \(summaryColumns), p.source_url, p.source_name, p.source_license,
        p.editorial_summary, p.difficulty, p.canonical_key
        """

    private static func artwork(from row: SQLiteRow) -> ArtworkStyle {
        ArtworkStyle(
            primaryHex: row.string("artwork_primary_hex"),
            secondaryHex: row.string("artwork_secondary_hex"),
            tertiaryHex: row.string("artwork_tertiary_hex"),
            glyph: row.string("artwork_glyph")
        )
    }

    private func makePoemSummary(_ row: SQLiteRow) -> Poem {
        Poem(
            id: row.string("id"), title: row.string("title"), author: row.string("author"),
            dynasty: row.string("dynasty"), form: row.string("form"), tags: [],
            summary: row.string("summary"), lines: [], annotations: [], sourceURL: nil,
            artworkStyle: Self.artwork(from: row), sourceName: "", sourceLicense: "",
            firstLinePreview: row.string("first_line")
        )
    }

    private func makePoem(
        row: SQLiteRow,
        lines: [PoemLine],
        annotations: [PoemAnnotation],
        tags: [String],
        themes: [String]
    ) -> Poem {
        Poem(
            id: row.string("id"), title: row.string("title"), author: row.string("author"),
            dynasty: row.string("dynasty"), form: row.string("form"), tags: tags,
            summary: row.string("summary"), lines: lines, annotations: annotations,
            sourceURL: row.url("source_url"), artworkStyle: Self.artwork(from: row),
            sourceName: row.string("source_name"), sourceLicense: row.string("source_license"),
            editorialSummary: row.optionalString("editorial_summary"), themes: themes,
            difficulty: row.int("difficulty"), canonicalKey: row.optionalString("canonical_key"),
            firstLinePreview: row.string("first_line")
        )
    }

    private func readCollections() throws -> [PoemCollection] {
        try rows(
            """
            SELECT c.id, c.title, c.subtitle, c.kind, c.accent_primary_hex,
                   c.accent_secondary_hex, c.accent_tertiary_hex, c.accent_glyph,
                   COUNT(cp.poem_id) AS poem_count
            FROM collections c
            LEFT JOIN collection_poems cp ON cp.collection_id = c.id
            GROUP BY c.id
            ORDER BY c.sort_order
            """
        ).map { row in
            guard let kind = CollectionKind(rawValue: row.string("kind")) else {
                throw PoemLibraryRepositoryError.invalidCollectionKind(row.string("kind"))
            }
            return PoemCollection(
                id: row.string("id"), title: row.string("title"), subtitle: row.string("subtitle"),
                kind: kind, poemCount: row.int("poem_count"), poemIDs: [],
                accent: ArtworkStyle(
                    primaryHex: row.string("accent_primary_hex"),
                    secondaryHex: row.string("accent_secondary_hex"),
                    tertiaryHex: row.string("accent_tertiary_hex"),
                    glyph: row.string("accent_glyph")
                )
            )
        }
    }

    private func readCategories() throws -> [PoemCategory] {
        try rows(
            """
            SELECT id, title, subtitle, tag, symbol, artwork_primary_hex,
                   artwork_secondary_hex, artwork_tertiary_hex, artwork_glyph
            FROM categories ORDER BY sort_order
            """
        ).map { row in
            PoemCategory(
                id: row.string("id"), title: row.string("title"), subtitle: row.string("subtitle"),
                tag: row.string("tag"), artworkStyle: Self.artwork(from: row), symbol: row.string("symbol")
            )
        }
    }

    private func scalarInt(_ sql: String, parameters: [SQLiteParameter] = []) throws -> Int {
        try rows(sql, parameters: parameters).first?.int("value") ?? 0
    }

    private func rows(_ sql: String, parameters: [SQLiteParameter] = []) throws -> [SQLiteRow] {
        let statement = try SQLiteStatement(database: handle, sql: sql)
        try statement.bind(parameters)
        var rows: [SQLiteRow] = []

        while true {
            let result = sqlite3_step(statement.handle)
            if result == SQLITE_ROW {
                rows.append(SQLiteRow(statement: statement.handle))
            } else if result == SQLITE_DONE {
                return rows
            } else {
                throw PoemLibraryRepositoryError.sqliteStepFailed(lastErrorMessage)
            }
        }
    }

    private var lastErrorMessage: String {
        String(cString: sqlite3_errmsg(handle))
    }
}

private final class SQLiteInterruptController: @unchecked Sendable {
    private let lock = NSLock()
    private var database: OpaquePointer?

    func register(_ database: OpaquePointer) {
        lock.withLock {
            self.database = database
        }
    }

    func interrupt() {
        lock.withLock {
            if let database {
                sqlite3_interrupt(database)
            }
        }
    }
}

private final class SQLiteStatement {
    let handle: OpaquePointer

    init(database: OpaquePointer, sql: String) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(database))
            throw PoemLibraryRepositoryError.sqlitePrepareFailed(message)
        }
        self.handle = statement
    }

    deinit {
        sqlite3_finalize(handle)
    }

    func bind(_ parameters: [SQLiteParameter]) throws {
        for (offset, parameter) in parameters.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch parameter {
            case .integer(let value):
                result = sqlite3_bind_int64(handle, index, sqlite3_int64(value))
            case .real(let value):
                result = sqlite3_bind_double(handle, index, value)
            case .text(let value):
                result = value.withCString { pointer in
                    sqlite3_bind_text(handle, index, pointer, -1, sqliteTransient)
                }
            }
            if result != SQLITE_OK {
                throw PoemLibraryRepositoryError.sqliteStepFailed("Failed to bind SQLite parameter \(offset + 1)")
            }
        }
    }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private enum SQLiteParameter {
    case integer(Int)
    case real(Double)
    case text(String)
}

private struct SQLiteRow {
    private let values: [String: SQLiteValue]

    init(statement: OpaquePointer) {
        var values: [String: SQLiteValue] = [:]

        for index in 0..<sqlite3_column_count(statement) {
            let columnName = String(cString: sqlite3_column_name(statement, index))
            switch sqlite3_column_type(statement, index) {
            case SQLITE_INTEGER:
                values[columnName] = .integer(Int(sqlite3_column_int64(statement, index)))
            case SQLITE_FLOAT:
                values[columnName] = .real(sqlite3_column_double(statement, index))
            case SQLITE_NULL:
                values[columnName] = .null
            default:
                let text = sqlite3_column_text(statement, index).map { String(cString: $0) } ?? ""
                values[columnName] = .text(text)
            }
        }

        self.values = values
    }

    func string(_ column: String) -> String {
        optionalString(column) ?? ""
    }

    func optionalString(_ column: String) -> String? {
        guard let value = values[column] else {
            return nil
        }

        switch value {
        case .integer(let value):
            return String(value)
        case .real(let value):
            return String(value)
        case .text(let value):
            return value.isEmpty ? nil : value
        case .null:
            return nil
        }
    }

    func int(_ column: String) -> Int {
        guard let value = values[column] else {
            return 0
        }

        switch value {
        case .integer(let value):
            return value
        case .real(let value):
            return Int(value)
        case .text(let value):
            return Int(value) ?? 0
        case .null:
            return 0
        }
    }

    func double(_ column: String) -> Double {
        guard let value = values[column] else { return 0 }
        switch value {
        case .integer(let value): return Double(value)
        case .real(let value): return value
        case .text(let value): return Double(value) ?? 0
        case .null: return 0
        }
    }

    func url(_ column: String) -> URL? {
        optionalString(column).flatMap(URL.init(string:))
    }
}

private enum SQLiteValue {
    case integer(Int)
    case real(Double)
    case text(String)
    case null
}
