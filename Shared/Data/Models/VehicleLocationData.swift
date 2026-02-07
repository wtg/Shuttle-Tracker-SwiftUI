//
//  VehicleLocationData.swift
//  iOS
//
//  Created by RS on 10/7/25.
//

import Foundation
import CoreLocation

// aggregates data from /locations, /velocities, and /etas
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
    let stopTimes: [String: String]

    // helper
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

typealias VehicleInformationMap = [String: VehicleLocationData]
