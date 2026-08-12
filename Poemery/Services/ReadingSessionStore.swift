import Foundation
import Observation

struct UserPlaylist: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    var poemIDs: [Poem.ID]
}

enum UserPlaylistError: LocalizedError, Equatable {
    case invalidName
    case duplicateName
    case playlistNotFound
    case persistenceFailed

    var errorDescription: String? {
        switch self {
        case .invalidName:
            return "诗单名称需要包含 1 至 40 个字符。"
        case .duplicateName:
            return "已经有同名诗单。"
        case .playlistNotFound:
            return "这个诗单已经不存在。"
        case .persistenceFailed:
            return "诗单未能保存到本机，请稍后重试。"
        }
    }
}

@MainActor
@Observable
final class UserPlaylistStore {
    private(set) var playlists: [UserPlaylist]

    private let fileURL: URL
    private let fileManager: FileManager

    convenience init() {
        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.init(
            fileURL: applicationSupport
                .appendingPathComponent("Poemery", isDirectory: true)
                .appendingPathComponent("UserPlaylists.json"),
            fileManager: fileManager
        )
    }

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.playlists = Self.load(from: fileURL)
    }

    @discardableResult
    func createPlaylist(named name: String, adding poemID: Poem.ID? = nil) throws -> UserPlaylist {
        let normalizedName = try validatedName(name, excluding: nil)
        let now = Date()
        let playlist = UserPlaylist(
            id: UUID(),
            name: normalizedName,
            createdAt: now,
            updatedAt: now,
            poemIDs: poemID.map { [$0] } ?? []
        )
        playlists.insert(playlist, at: 0)
        try persistOrRevert { playlists.removeAll { $0.id == playlist.id } }
        return playlist
    }

    func renamePlaylist(id: UserPlaylist.ID, to name: String) throws {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else {
            throw UserPlaylistError.playlistNotFound
        }
        let normalizedName = try validatedName(name, excluding: id)
        let previous = playlists[index]
        playlists[index].name = normalizedName
        playlists[index].updatedAt = Date()
        try persistOrRevert { playlists[index] = previous }
    }

    func deletePlaylist(id: UserPlaylist.ID) throws {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else {
            throw UserPlaylistError.playlistNotFound
        }
        let removed = playlists.remove(at: index)
        try persistOrRevert { playlists.insert(removed, at: min(index, playlists.count)) }
    }

    func add(poemID: Poem.ID, to playlistID: UserPlaylist.ID) throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else {
            throw UserPlaylistError.playlistNotFound
        }
        guard !playlists[index].poemIDs.contains(poemID) else {
            return
        }
        let previous = playlists[index]
        playlists[index].poemIDs.append(poemID)
        playlists[index].updatedAt = Date()
        try persistOrRevert { playlists[index] = previous }
    }

    func removePoems(at offsets: IndexSet, from playlistID: UserPlaylist.ID) throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else {
            throw UserPlaylistError.playlistNotFound
        }
        let previous = playlists[index]
        for offset in offsets.sorted(by: >) where playlists[index].poemIDs.indices.contains(offset) {
            playlists[index].poemIDs.remove(at: offset)
        }
        playlists[index].updatedAt = Date()
        try persistOrRevert { playlists[index] = previous }
    }

    func movePoems(from offsets: IndexSet, to destination: Int, in playlistID: UserPlaylist.ID) throws {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else {
            throw UserPlaylistError.playlistNotFound
        }
        let previous = playlists[index]
        let validOffsets = offsets.sorted().filter { playlists[index].poemIDs.indices.contains($0) }
        let movedIDs = validOffsets.map { playlists[index].poemIDs[$0] }
        for offset in validOffsets.reversed() {
            playlists[index].poemIDs.remove(at: offset)
        }
        let removedBeforeDestination = validOffsets.filter { $0 < destination }.count
        let insertionIndex = min(
            max(0, destination - removedBeforeDestination),
            playlists[index].poemIDs.count
        )
        playlists[index].poemIDs.insert(contentsOf: movedIDs, at: insertionIndex)
        playlists[index].updatedAt = Date()
        try persistOrRevert { playlists[index] = previous }
    }

    func contains(poemID: Poem.ID, in playlistID: UserPlaylist.ID) -> Bool {
        playlists.first(where: { $0.id == playlistID })?.poemIDs.contains(poemID) == true
    }

    func playlist(id: UserPlaylist.ID) -> UserPlaylist? {
        playlists.first { $0.id == id }
    }

    private func validatedName(_ name: String, excluding playlistID: UserPlaylist.ID?) throws -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 40 else {
            throw UserPlaylistError.invalidName
        }
        let alreadyExists = playlists.contains { playlist in
            playlist.id != playlistID
                && playlist.name.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        guard !alreadyExists else {
            throw UserPlaylistError.duplicateName
        }
        return normalized
    }

    private func persistOrRevert(_ revert: () -> Void) throws {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(playlists).write(to: fileURL, options: [.atomic])
        } catch {
            revert()
            throw UserPlaylistError.persistenceFailed
        }
    }

    private static func load(from fileURL: URL) -> [UserPlaylist] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([UserPlaylist].self, from: data)) ?? []
    }
}

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

struct ReadingLogEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let poemID: Poem.ID
    let startedAt: Date
    let duration: TimeInterval

    init(id: UUID = UUID(), poemID: Poem.ID, startedAt: Date, duration: TimeInterval) {
        self.id = id
        self.poemID = poemID
        self.startedAt = startedAt
        self.duration = duration
    }
}

struct ReadingDayStat: Identifiable, Hashable, Sendable {
    let date: Date
    let duration: TimeInterval
    let count: Int

    var id: Date { date }
}

struct ReadingStatistics: Sendable {
    var totalDuration: TimeInterval = 0
    var todayDuration: TimeInterval = 0
    var totalReads: Int = 0
    var activeDays: Int = 0
    var currentStreakDays: Int = 0
    var last7Days: [ReadingDayStat] = []
    var recentEntries: [ReadingLogEntry] = []
}

@MainActor
@Observable
final class ReadingSessionStore {
    private let favoritesKey = "poemery.favoritePoemIDs"
    private let recentsKey = "poemery.recentPoemIDs"
    private let readingPositionsKey = "poemery.readingPositions"
    private let readingLogKey = "poemery.readingLog"
    private let defaults: UserDefaults

    private(set) var favoritePoemIDs: [Poem.ID]
    private(set) var recentPoemIDs: [Poem.ID]
    private(set) var currentPoemID: Poem.ID?
    private(set) var currentQueue: ReadingQueue?
    private(set) var readingPositions: [Poem.ID: PoemLine.ID]
    private(set) var readingLog: [ReadingLogEntry]
    private var activeReadingStart: Date?
    private var activeReadingPoemID: Poem.ID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.favoritePoemIDs = defaults.stringArray(forKey: favoritesKey) ?? []
        self.recentPoemIDs = defaults.stringArray(forKey: recentsKey) ?? []
        self.currentPoemID = nil
        self.currentQueue = nil
        self.readingPositions = defaults.dictionary(forKey: readingPositionsKey) as? [Poem.ID: PoemLine.ID] ?? [:]
        self.readingLog = defaults.data(forKey: readingLogKey)
            .flatMap { try? JSONDecoder().decode([ReadingLogEntry].self, from: $0) } ?? []
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
        if recentPoemIDs.count > 50 {
            recentPoemIDs = Array(recentPoemIDs.prefix(50))
        }
        persistRecents()
    }

    func clearRecents() {
        currentPoemID = nil
        currentQueue = nil
        recentPoemIDs.removeAll()
        readingPositions.removeAll()
        clearReadingLog()
        persistRecents()
        persistReadingPositions()
    }

    func beginReadingLog(poemID: Poem.ID) {
        endReadingLog()
        activeReadingStart = Date()
        activeReadingPoemID = poemID
    }

    func endReadingLog() {
        guard let startedAt = activeReadingStart, let poemID = activeReadingPoemID else {
            activeReadingStart = nil
            activeReadingPoemID = nil
            return
        }
        activeReadingStart = nil
        activeReadingPoemID = nil
        let duration = Date().timeIntervalSince(startedAt)
        appendReadingLogEntry(poemID: poemID, startedAt: startedAt, duration: duration)
    }

    func clearReadingLog() {
        activeReadingStart = nil
        activeReadingPoemID = nil
        readingLog.removeAll()
        persistReadingLog()
    }

    var statistics: ReadingStatistics {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        let totalDuration = readingLog.reduce(0) { $0 + $1.duration }
        let todayDuration = readingLog
            .filter { calendar.isDate($0.startedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.duration }
        let daysWithReads = Set(readingLog.map { calendar.startOfDay(for: $0.startedAt) })

        var streak = 0
        var streakDay = startOfToday
        if !daysWithReads.contains(streakDay) {
            streakDay = calendar.date(byAdding: .day, value: -1, to: streakDay) ?? streakDay
        }
        while daysWithReads.contains(streakDay) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: streakDay) else { break }
            streakDay = previous
        }

        let last7Days: [ReadingDayStat] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else {
                return nil
            }
            let entries = readingLog.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            return ReadingDayStat(
                date: date,
                duration: entries.reduce(0) { $0 + $1.duration },
                count: entries.count
            )
        }

        return ReadingStatistics(
            totalDuration: totalDuration,
            todayDuration: todayDuration,
            totalReads: readingLog.count,
            activeDays: daysWithReads.count,
            currentStreakDays: streak,
            last7Days: last7Days,
            recentEntries: Array(readingLog.suffix(20).reversed())
        )
    }

    func readingPosition(for poemID: Poem.ID) -> PoemLine.ID? {
        readingPositions[poemID]
    }

    func saveReadingPosition(lineID: PoemLine.ID, for poemID: Poem.ID) {
        readingPositions[poemID] = lineID
        let retainedIDs = Set(recentPoemIDs.prefix(50))
        readingPositions = readingPositions.filter { retainedIDs.contains($0.key) }
        persistReadingPositions()
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

    private func persistReadingPositions() {
        defaults.set(readingPositions, forKey: readingPositionsKey)
    }

    private func appendReadingLogEntry(poemID: Poem.ID, startedAt: Date, duration: TimeInterval) {
        let cappedDuration = min(max(duration, 0), 4 * 60 * 60)
        guard cappedDuration >= 1 else {
            return
        }
        readingLog.append(ReadingLogEntry(poemID: poemID, startedAt: startedAt, duration: cappedDuration))
        if readingLog.count > 600 {
            readingLog = Array(readingLog.suffix(600))
        }
        persistReadingLog()
    }

    private func persistReadingLog() {
        if let data = try? JSONEncoder().encode(readingLog) {
            defaults.set(data, forKey: readingLogKey)
        }
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
