import Foundation
import SQLite3

protocol PoemLibraryRepository: Sendable {
    func loadCatalog() throws -> PoemSeedCatalog
}

struct JSONPoemLibraryRepository: PoemLibraryRepository {
    let url: URL

    func loadCatalog() throws -> PoemSeedCatalog {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PoemSeedCatalog.self, from: data)
    }
}

struct SQLitePoemLibraryRepository: PoemLibraryRepository {
    let url: URL

    func loadCatalog() throws -> PoemSeedCatalog {
        let database = try SQLiteDatabase(url: url)
        return try database.readCatalog()
    }
}

enum PoemLibraryRepositoryError: LocalizedError, Equatable {
    case missingBundledCatalog
    case missingBundledJSONCatalog
    case sqliteOpenFailed(String)
    case sqlitePrepareFailed(String)
    case sqliteStepFailed(String)
    case invalidCollectionKind(String)

    var errorDescription: String? {
        switch self {
        case .missingBundledCatalog:
            "Missing PoemLibrary.sqlite and PoemsSeed.json from the app bundle."
        case .missingBundledJSONCatalog:
            "Missing PoemsSeed.json from the app bundle."
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
    private let handle: OpaquePointer

    init(url: URL) throws {
        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX

        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK, let database else {
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

    func readCatalog() throws -> PoemSeedCatalog {
        let lineRows = try rows(
            """
            SELECT poem_id, line_id, line_order, text
            FROM poem_lines
            ORDER BY poem_id, line_order
            """
        )
        let linesByPoemID = Dictionary(grouping: lineRows, by: { $0.string("poem_id") })
            .mapValues { rows in
                rows.map { row in
                    PoemLine(
                        id: row.string("line_id"),
                        order: row.int("line_order"),
                        text: row.string("text")
                    )
                }
            }

        let annotationRows = try rows(
            """
            SELECT poem_id, annotation_id, line_id, term, reading, summary, detail, annotation_order
            FROM poem_annotations
            ORDER BY poem_id, annotation_order
            """
        )
        let annotationsByPoemID = Dictionary(grouping: annotationRows, by: { $0.string("poem_id") })
            .mapValues { rows in
                rows.map { row in
                    PoemAnnotation(
                        id: row.string("annotation_id"),
                        lineID: row.string("line_id"),
                        term: row.string("term"),
                        reading: row.string("reading"),
                        summary: row.string("summary"),
                        detail: row.string("detail")
                    )
                }
            }

        let tagRows = try rows(
            """
            SELECT poem_id, tag
            FROM poem_tags
            ORDER BY poem_id, tag_order
            """
        )
        let tagsByPoemID = Dictionary(grouping: tagRows, by: { $0.string("poem_id") })
            .mapValues { rows in rows.map { $0.string("tag") } }

        let themeRows = try rows(
            """
            SELECT poem_id, theme
            FROM poem_themes
            ORDER BY poem_id, theme_order
            """
        )
        let themesByPoemID = Dictionary(grouping: themeRows, by: { $0.string("poem_id") })
            .mapValues { rows in rows.map { $0.string("theme") } }

        let poems = try rows(
            """
            SELECT id, title, author, dynasty, form, summary, source_url, source_name,
                   source_license, editorial_summary, difficulty, canonical_key,
                   artwork_primary_hex, artwork_secondary_hex, artwork_tertiary_hex,
                   artwork_glyph
            FROM poems
            ORDER BY sort_order
            """
        )
        .map { row in
            let poemID = row.string("id")
            return Poem(
                id: poemID,
                title: row.string("title"),
                author: row.string("author"),
                dynasty: row.string("dynasty"),
                form: row.string("form"),
                tags: tagsByPoemID[poemID, default: []],
                summary: row.string("summary"),
                lines: linesByPoemID[poemID, default: []],
                annotations: annotationsByPoemID[poemID, default: []],
                sourceURL: row.url("source_url"),
                artworkStyle: ArtworkStyle(
                    primaryHex: row.string("artwork_primary_hex"),
                    secondaryHex: row.string("artwork_secondary_hex"),
                    tertiaryHex: row.string("artwork_tertiary_hex"),
                    glyph: row.string("artwork_glyph")
                ),
                sourceName: row.string("source_name"),
                sourceLicense: row.string("source_license"),
                editorialSummary: row.optionalString("editorial_summary"),
                themes: themesByPoemID[poemID, default: []],
                difficulty: row.int("difficulty"),
                canonicalKey: row.optionalString("canonical_key")
            )
        }

        let collectionPoemRows = try rows(
            """
            SELECT collection_id, poem_id
            FROM collection_poems
            ORDER BY collection_id, poem_order
            """
        )
        let poemIDsByCollectionID = Dictionary(grouping: collectionPoemRows, by: { $0.string("collection_id") })
            .mapValues { rows in rows.map { $0.string("poem_id") } }

        let collections = try rows(
            """
            SELECT id, title, subtitle, kind, accent_primary_hex, accent_secondary_hex,
                   accent_tertiary_hex, accent_glyph
            FROM collections
            ORDER BY sort_order
            """
        )
        .map { row in
            let kindRawValue = row.string("kind")
            guard let kind = CollectionKind(rawValue: kindRawValue) else {
                throw PoemLibraryRepositoryError.invalidCollectionKind(kindRawValue)
            }

            let collectionID = row.string("id")
            return PoemCollection(
                id: collectionID,
                title: row.string("title"),
                subtitle: row.string("subtitle"),
                kind: kind,
                poemIDs: poemIDsByCollectionID[collectionID, default: []],
                accent: ArtworkStyle(
                    primaryHex: row.string("accent_primary_hex"),
                    secondaryHex: row.string("accent_secondary_hex"),
                    tertiaryHex: row.string("accent_tertiary_hex"),
                    glyph: row.string("accent_glyph")
                )
            )
        }

        let categories = try rows(
            """
            SELECT id, title, subtitle, tag, symbol, artwork_primary_hex,
                   artwork_secondary_hex, artwork_tertiary_hex, artwork_glyph
            FROM categories
            ORDER BY sort_order
            """
        )
        .map { row in
            PoemCategory(
                id: row.string("id"),
                title: row.string("title"),
                subtitle: row.string("subtitle"),
                tag: row.string("tag"),
                artworkStyle: ArtworkStyle(
                    primaryHex: row.string("artwork_primary_hex"),
                    secondaryHex: row.string("artwork_secondary_hex"),
                    tertiaryHex: row.string("artwork_tertiary_hex"),
                    glyph: row.string("artwork_glyph")
                ),
                symbol: row.string("symbol")
            )
        }

        return PoemSeedCatalog(poems: poems, collections: collections, categories: categories)
    }

    private func rows(_ sql: String) throws -> [SQLiteRow] {
        let statement = try SQLiteStatement(database: handle, sql: sql)
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
        case .text(let value):
            return Int(value) ?? 0
        case .null:
            return 0
        }
    }

    func url(_ column: String) -> URL? {
        optionalString(column).flatMap(URL.init(string:))
    }
}

private enum SQLiteValue {
    case integer(Int)
    case text(String)
    case null
}
