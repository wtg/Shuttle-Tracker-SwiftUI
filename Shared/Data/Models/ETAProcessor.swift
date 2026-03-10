import Foundation

struct EtasForRoute: Identifiable {
    let id: String
    let color: String
    let etas: [StopETA]
}
struct StopETA: Identifiable {
    // stopName, routeName, etaDate, vehicleName
    var id: String { stopKey + routeName }
    let stopKey: String
    let stopName: String
    let routeName: String
    let etaDate: Date
    let vehicleName: String
}

struct ETAProcessor {
    /* get the shortest etas for each route */
    static func getGroupedETAs(vehicles: [VehicleLocationData], routes: ShuttleRouteData) -> [EtasForRoute] {
        let allEtas = getShortestETAs(vehicles: vehicles, routes: routes)
        let grouped = Dictionary(grouping: allEtas) { $0.routeName }
        let sections = grouped.map { (routeName, etas) -> EtasForRoute in
            let sortedETAs = etas.sorted { $0.etaDate < $1.etaDate }
            let routeColor = routes[routeName]?.color ?? "#000000"
            return EtasForRoute(id: routeName, color: routeColor, etas: sortedETAs)
        }
        return sections.sorted { $0.id < $1.id }
    }

    /* get the shortest etas for each stop in all routes */
    static private func getShortestETAs(vehicles: [VehicleLocationData], routes: ShuttleRouteData) -> [StopETA] {
        // map to store the soonest ETA found so far for each unique stop key
        var shortestEtas: [String: StopETA] = [:]
        for vehicle in vehicles {
            /* from future etas only */
            for (stopKey, timeString) in vehicle.futureEtas {
                guard let etaDate = timeString.isoTimeToDate else { continue }
                var currentStopName = stopKey
                if let route = routes[vehicle.routeName],
                    let details = route.stopDetails[stopKey] {
                        currentStopName = details.name
                }
                let newETA = StopETA(
                        stopKey: stopKey,
                        stopName: currentStopName,
                        routeName: vehicle.routeName,
                        etaDate: etaDate,
                        vehicleName: vehicle.name
                        )

                let routeStopKey = stopKey + "_" + vehicle.routeName

                if let existing = shortestEtas[routeStopKey] {
                    if newETA.etaDate < existing.etaDate {
                        shortestEtas[routeStopKey] = newETA
                    }
                } else {
                    shortestEtas[routeStopKey] = newETA
                }
            }
        }
        return Array(shortestEtas.values).sorted { $0.etaDate < $1.etaDate }
    }
}
