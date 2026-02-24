import AppIntents
import Foundation

struct ShuttleStop: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Shuttle Stop"
    static var defaultQuery = ShuttleStopQuery()

    static let defaultStop = ShuttleStop(id: "STUDENT_UNION", displayString: "Student Union")
    static let allStops = ShuttleStop(id: "ALL_STOPS", displayString: "All Routes & Stops")

    var lookupKeys: [String] {
        if id == "ALL_STOPS" { return [] }
        /* we will recognize arrival and departure from student union as the same in terms of ETA */
        if id == "STUDENT_UNION" || id == "STUDENT_UNION_RETURN" {
            return ["STUDENT_UNION", "STUDENT_UNION_RETURN"]
        }
        return [id]
    }

    var id: String              /* STUDENT_UNION */
    var displayString: String   /* Student Union */
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(displayString)") }
}

struct ShuttleStopQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ShuttleStop] {
        var allStops = await fetchAllStops()
        allStops.append(ShuttleStop.allStops)
        return allStops.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ShuttleStop] {
        var stops = await fetchAllStops()
        stops.insert(ShuttleStop.allStops, at: 0)
        return stops
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
                ShuttleStop.defaultStop,
                ShuttleStop(id: "BLITMAN", displayString: "Blitman"),
                ShuttleStop(id: "ECAV", displayString: "ECAV")
            ]
        }
    }
}
