import Foundation
import Observation

@MainActor
@Observable
final class ReadingSessionStore {
    private let favoritesKey = "poemery.favoritePoemIDs"
    private let recentsKey = "poemery.recentPoemIDs"
    private let currentPoemKey = "poemery.currentPoemID"
    private let defaults: UserDefaults

    private(set) var favoritePoemIDs: [Poem.ID]
    private(set) var recentPoemIDs: [Poem.ID]
    private(set) var queuePoemIDs: [Poem.ID]
    var currentPoemID: Poem.ID? {
        didSet {
            defaults.set(currentPoemID, forKey: currentPoemKey)
        }
    }

    init(defaults: UserDefaults = .standard, initialQueue: [Poem.ID] = []) {
        self.defaults = defaults
        self.favoritePoemIDs = defaults.stringArray(forKey: favoritesKey) ?? []
        self.recentPoemIDs = defaults.stringArray(forKey: recentsKey) ?? []
        self.currentPoemID = defaults.string(forKey: currentPoemKey)
        self.queuePoemIDs = initialQueue
    }

    func configureIfNeeded(with library: PoemLibraryStore) {
        guard currentPoemID == nil else {
            if queuePoemIDs.isEmpty {
                queuePoemIDs = library.poems.map(\.id)
            }
            return
        }

        currentPoemID = recentPoemIDs.first ?? library.poems.first?.id
        queuePoemIDs = library.poems.map(\.id)
    }

    func currentPoem(in library: PoemLibraryStore) -> Poem? {
        currentPoemID.flatMap { library.poem(id: $0) } ?? library.poems.first
    }

    func favoritePoems(in library: PoemLibraryStore) -> [Poem] {
        favoritePoemIDs.compactMap { library.poem(id: $0) }
    }

    func recentPoems(in library: PoemLibraryStore) -> [Poem] {
        recentPoemIDs.compactMap { library.poem(id: $0) }
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

    func startReading(_ poem: Poem, queue: [Poem] = []) {
        currentPoemID = poem.id
        queuePoemIDs = queue.isEmpty ? [poem.id] : queue.map(\.id)
        markRecent(poem)
    }

    func continueReading(_ library: PoemLibraryStore) {
        if currentPoemID == nil {
            currentPoemID = recentPoemIDs.first ?? library.poems.first?.id
        }

        if let poem = currentPoem(in: library) {
            markRecent(poem)
        }
    }

    func playNext(in library: PoemLibraryStore) {
        let fallbackQueue = queuePoemIDs.isEmpty ? library.poems.map(\.id) : queuePoemIDs
        guard !fallbackQueue.isEmpty else { return }

        let current = currentPoemID ?? fallbackQueue.first
        let currentIndex = current.flatMap { fallbackQueue.firstIndex(of: $0) } ?? -1
        let nextIndex = fallbackQueue.index(after: currentIndex)
        let safeIndex = fallbackQueue.indices.contains(nextIndex) ? nextIndex : fallbackQueue.startIndex
        currentPoemID = fallbackQueue[safeIndex]

        if let poem = currentPoem(in: library) {
            markRecent(poem)
        }
    }

    private func markRecent(_ poem: Poem) {
        recentPoemIDs.removeAll { $0 == poem.id }
        recentPoemIDs.insert(poem.id, at: 0)
        if recentPoemIDs.count > 20 {
            recentPoemIDs = Array(recentPoemIDs.prefix(20))
        }
        persistRecents()
    }

    private func persistFavorites() {
        defaults.set(favoritePoemIDs, forKey: favoritesKey)
    }

    private func persistRecents() {
        defaults.set(recentPoemIDs, forKey: recentsKey)
    }
}
