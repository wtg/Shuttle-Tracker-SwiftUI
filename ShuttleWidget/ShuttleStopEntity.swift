import AppIntents
import Foundation

struct ShuttleStop: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Shuttle Stop"
    static var defaultQuery = ShuttleStopQuery()
    var id: String              /* STUDENT_UNION */
    var displayString: String   /* Student Union */
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(displayString)") }
}

struct ShuttleStopQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ShuttleStop] {
        let allStops = await fetchAllStops()
        return allStops.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ShuttleStop] {
        return await fetchAllStops()
    }

    private func fetchAllStops() async -> [ShuttleStop] {
        do {
            let routeData = try await APIClient.shared.fetch(ShuttleRouteData.self, endpoint: .routes)
            var uniqueStops: [String: ShuttleStop] = [:]
            for (_, route) in routeData {
                for (key, details) in route.stopDetails {
                    if uniqueStops[key] == nil {
                        uniqueStops[key] = ShuttleStop(id: key, displayString: details.name)
                    }
                }
            }
            return Array(uniqueStops.values).sorted { $0.displayString < $1.displayString }
        } catch {
            // fallback
            return [
                ShuttleStop(id: "STUDENT_UNION", displayString: "Student Union"),
                ShuttleStop(id: "BLITMAN", displayString: "Blitman"),
                ShuttleStop(id: "ECAV", displayString: "ECAV")
            ]
        }
    }
}
