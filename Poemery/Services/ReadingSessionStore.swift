import Foundation
import Observation

struct ReadingQueue: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let poemIDs: [Poem.ID]

    init(id: String = UUID().uuidString, title: String, poemIDs: [Poem.ID]) {
        self.id = id
        self.title = title
        self.poemIDs = poemIDs
    }

    init(title: String, poems: [Poem]) {
        self.init(title: title, poemIDs: poems.map(\.id))
    }

    static func singlePoem(_ poem: Poem) -> ReadingQueue {
        ReadingQueue(title: poem.title, poemIDs: [poem.id])
    }
}

@MainActor
@Observable
final class ReadingSessionStore {
    private let favoritesKey = "poemery.favoritePoemIDs"
    private let recentsKey = "poemery.recentPoemIDs"
    private let defaults: UserDefaults

    private(set) var favoritePoemIDs: [Poem.ID]
    private(set) var recentPoemIDs: [Poem.ID]
    private(set) var currentPoemID: Poem.ID?
    private(set) var currentQueue: ReadingQueue?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.favoritePoemIDs = defaults.stringArray(forKey: favoritesKey) ?? []
        self.recentPoemIDs = defaults.stringArray(forKey: recentsKey) ?? []
        self.currentPoemID = nil
        self.currentQueue = nil
    }

    func favoritePoems(in library: PoemLibraryStore) -> [Poem] {
        favoritePoemIDs.compactMap { library.poem(id: $0) }
    }

    func recentPoems(in library: PoemLibraryStore) -> [Poem] {
        recentPoemIDs.compactMap { library.poem(id: $0) }
    }

    func currentPoem(in library: PoemLibraryStore) -> Poem? {
        currentPoemID.flatMap { library.poem(id: $0) }
    }

    var canMoveInCurrentQueue: Bool {
        (currentQueue?.poemIDs.count ?? 0) > 1
    }

    func isFavorite(_ poem: Poem) -> Bool {
        favoritePoemIDs.contains(poem.id)
    }

    func toggleFavorite(_ poem: Poem) {
        if let index = favoritePoemIDs.firstIndex(of: poem.id) {
            favoritePoemIDs.remove(at: index)
        } else {
            favoritePoemIDs.insert(poem.id, at: 0)
        }
        persistFavorites()
    }

    func clearFavorites() {
        favoritePoemIDs.removeAll()
        persistFavorites()
    }

    func markRecent(_ poem: Poem) {
        currentPoemID = poem.id
        recentPoemIDs.removeAll { $0 == poem.id }
        recentPoemIDs.insert(poem.id, at: 0)
        if recentPoemIDs.count > 20 {
            recentPoemIDs = Array(recentPoemIDs.prefix(20))
        }
        persistRecents()
    }

    func clearRecents() {
        currentPoemID = nil
        currentQueue = nil
        recentPoemIDs.removeAll()
        persistRecents()
    }

    func startReading(_ poem: Poem, in queue: ReadingQueue) {
        currentQueue = queue.poemIDs.contains(poem.id) ? queue : .singlePoem(poem)
        markRecent(poem)
    }

    @discardableResult
    func moveToNextPoem(in library: PoemLibraryStore) -> Poem? {
        moveCurrentPoem(by: 1, in: library)
    }

    @discardableResult
    func moveToPreviousPoem(in library: PoemLibraryStore) -> Poem? {
        moveCurrentPoem(by: -1, in: library)
    }

    private func persistFavorites() {
        defaults.set(favoritePoemIDs, forKey: favoritesKey)
    }

    private func persistRecents() {
        defaults.set(recentPoemIDs, forKey: recentsKey)
    }

    private func moveCurrentPoem(by offset: Int, in library: PoemLibraryStore) -> Poem? {
        guard
            let currentPoemID,
            let currentQueue,
            currentQueue.poemIDs.count > 1,
            let currentIndex = currentQueue.poemIDs.firstIndex(of: currentPoemID)
        else {
            return nil
        }

        let nextIndex = (currentIndex + offset + currentQueue.poemIDs.count) % currentQueue.poemIDs.count
        guard let poem = library.poem(id: currentQueue.poemIDs[nextIndex]) else {
            return nil
        }

        startReading(poem, in: currentQueue)
        return poem
    }
}
