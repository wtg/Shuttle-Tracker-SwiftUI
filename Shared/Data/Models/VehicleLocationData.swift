//
//  VehicleLocationData.swift
//  iOS
//
//  Created by RS on 10/7/25.
//

import Foundation
import CoreLocation

// aggregates data from /locations, /velocities, and /etas
// filled within VehicleService.refreshVehicles
struct VehicleLocationData: Identifiable {
    var id: String { name } // for ForEach loops

    // from /locations (assuming optionals based on frontend impl)
    let name: String
    let latitude: Double
    let longitude: Double
    let headingDegrees: Double
    let speedMph: Double
    let timestamp: String
    let formattedLocation: String

    // from /velocities
    let routeName: String
    let isAtStop: Bool
    let currentStop: String?

    // from /etas
    let stopEtaTimes: [String: String]

    // helpers
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // finds this vehicles eta stops that are in the future
    var futureEtas: [String: String] {
        let now = Date()
        return stopEtaTimes.filter { _, timeString in
            guard let etaDate = timeString.isoTimeToDate else { return false }
            return etaDate > now
        }
    }

    // finds this vehicle's nearest eta to a set of stops: ["STUDENT_UNION", "STUDENT_UNION_RETURN"]
    func soonestFutureEta(for keys: [String]) -> String? {
        let now = Date()
        return keys
            .compactMap { key -> (string: String, date: Date)? in
                guard let timeStr = stopEtaTimes[key],
                      let date = timeStr.isoTimeToDate, date > now else { return nil }
                return (timeStr, date)
            }
            .min(by: { $0.date < $1.date })?
            .string
    }
}

enum VehicleDTOMerger {
    // merges the separate API DTOs into a VehicleLocationData array.
    static func merge(
        locations: [String: VehicleLocationDTO],
        velocities: [String: VehicleVelocityDTO]? = nil,
        etas: [String: VehicleETADTO]? = nil
    ) -> [VehicleLocationData] {
        var mergedVehicles: [VehicleLocationData] = []
        for (id, loc) in locations {
            let velocity = velocities?[id]
            let eta = etas?[id]
            let vehicle = VehicleLocationData(
                // location
                name: loc.name,
                latitude: loc.latitude,
                longitude: loc.longitude,
                headingDegrees: loc.headingDegrees,
                speedMph: loc.speedMph,
                timestamp: loc.timestamp,
                formattedLocation: loc.formattedLocation,

                // velocities
                routeName: velocity?.routeName ?? "unknown",
                isAtStop: velocity?.isAtStop ?? false,
                currentStop: velocity?.currentStop,

                // etas
                stopEtaTimes: eta?.stopEtaTimes ?? [:]
            )
            mergedVehicles.append(vehicle)
        }
        return mergedVehicles.sorted { $0.name < $1.name }
    }
}
