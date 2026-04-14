import AppIntents
import Foundation

struct ShuttleStop: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Shuttle Stop"
    static var defaultQuery = ShuttleStopQuery()

    static let defaultStop = ShuttleStop(id: "STUDENT_UNION", displayString: "Student Union (N&W)")
    static let allStops = ShuttleStop(id: "ALL_STOPS", displayString: "All Routes & Stops")

    var stopKey: String {
        if let idx = id.range(of: "@")?.lowerBound { return String(id[..<idx]) }
        return id
    }
    var routeKey: String? {
        if let idx = id.range(of: "@")?.upperBound { return String(id[idx...]) }
        return nil
    }

    var lookupKeys: [String] {
        if id == "ALL_STOPS" { return [] }
        /* we will recognize arrival and departure from student union as the same in terms of ETA */
        let base = stopKey
        if base == "STUDENT_UNION" || base == "STUDENT_UNION_RETURN" {
            return ["STUDENT_UNION", "STUDENT_UNION_RETURN"]
        }
        return [base]
    }

    var id: String              /* STUDENT_UNION */
    var displayString: String   /* Student Union */
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(displayString)") }
}

struct ShuttleStopQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ShuttleStop] {
        var allStops = await fetchAllStops()
        allStops.append(ShuttleStop.allStops)
        allStops.append(ShuttleStop.defaultStop)
        return allStops.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ShuttleStop] {
        var stops = await fetchAllStops()
        stops.insert(ShuttleStop.allStops, at: 0)
        stops.insert(ShuttleStop.defaultStop, at: 1)
        return stops
    }

    private func fetchAllStops() async -> [ShuttleStop] {
        do {
            let routeData = try await APIClient.shared.fetch(ShuttleRouteData.self, endpoint: .routes)
            var stops: [ShuttleStop] = []
            for (routeName, route) in routeData {
                if routeName != "WEST" && routeName != "NORTH" { continue; }
                for (key, details) in route.stopDetails {
                    if key == "STUDENT_UNION_RETURN" { continue; }
                    if key == "STUDENT_UNION" {
                        /* student union can be both west and north route */
                        let id = "\(key)@\(routeName)"
                        let display = "\(details.name) (\(routeName[routeName.startIndex]))"
                        if !stops.contains(where: { $0.id == id }) {
                            stops.append(ShuttleStop(id: id, displayString: display))
                        }
                    } else {
                        /* all other stops are disjoint in routes */
                        if !stops.contains(where: { $0.id == key }) {
                            stops.append(ShuttleStop(id: key, displayString: details.name))
                        }
                    }
                }
            }
            return stops.sorted { $0.displayString < $1.displayString }
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
