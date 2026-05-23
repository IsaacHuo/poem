import Foundation
import Observation

@MainActor
@Observable
final class ReadingSessionStore {
    private let favoritesKey = "poemery.favoritePoemIDs"
    private let recentsKey = "poemery.recentPoemIDs"
    private let defaults: UserDefaults

    private(set) var favoritePoemIDs: [Poem.ID]
    private(set) var recentPoemIDs: [Poem.ID]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.favoritePoemIDs = defaults.stringArray(forKey: favoritesKey) ?? []
        self.recentPoemIDs = defaults.stringArray(forKey: recentsKey) ?? []
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

    func markRecent(_ poem: Poem) {
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
