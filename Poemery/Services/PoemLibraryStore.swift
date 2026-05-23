import Foundation
import Observation

@MainActor
@Observable
final class PoemLibraryStore {
    private(set) var poems: [Poem]
    private(set) var collections: [PoemCollection]
    private(set) var categories: [PoemCategory]

    private var poemsByID: [Poem.ID: Poem]

    init(catalog: PoemSeedCatalog = PoemLibraryStore.loadBundledCatalog()) {
        self.poems = catalog.poems
        self.collections = catalog.collections
        self.categories = catalog.categories
        self.poemsByID = Dictionary(uniqueKeysWithValues: catalog.poems.map { ($0.id, $0) })
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
        Dictionary(grouping: poems, by: \.author)
            .map { author, poems in
                let dynasty = poems.first?.dynasty ?? ""
                return AuthorResult(
                    id: "\(dynasty)-\(author)",
                    name: author,
                    dynasty: dynasty,
                    poems: poems.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
                )
            }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
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
            poems: matchedPoems,
            authors: matchedAuthors,
            collections: matchedCollections
        )
    }

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
