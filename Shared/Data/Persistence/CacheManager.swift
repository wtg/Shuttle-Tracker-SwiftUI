import Foundation
import OSLog

private let logger = Logger(subsystem: "edu.rpi.shuttletracker", category: "CacheManager")

// including a caching manager so that it is separate from the scheduling code.
// also useful if we ever switch away from FileSystem caching to UserDefaults or something.
class CacheManager {
    static let shared = CacheManager()
    private let fileManager = FileManager.default

    enum Key: String {
        case routes = "routes_cache.json"
        case aggregatedSchedule = "aggregated_schedule_cache.json"
    }

    private init() {}

    // saves any Codable object to disk
    func save<T: Codable>(_ object: T, key: Key) {
        let url = getURL(for: key)
        do {
            let data = try JSONEncoder().encode(object)
            try data.write(to: url)
        } catch {
            logger.error("Failed save-to-cache \(key.rawValue): \(error.localizedDescription)")
        }
    }

    // loads any Codable object from disk
    func load<T: Codable>(_ type: T.Type, key: Key) -> T? {
        let url = getURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let object = try JSONDecoder().decode(T.self, from: data)
            return object
        } catch {
            logger.error("Failed to load \(key.rawValue): \(error.localizedDescription)")
            return nil
        }
    }

    // removes a specific cache file
    func clear(key: Key) {
        let url = getURL(for: key)
        try? fileManager.removeItem(at: url)
    }

    // helper
    private func getURL(for key: Key) -> URL {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(key.rawValue)
    }
}
