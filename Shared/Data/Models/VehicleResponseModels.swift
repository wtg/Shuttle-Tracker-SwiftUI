import Foundation

// Data transfer objects for vehicle-related api get-requests
// Note that some data is unecessary and thus not included

// /api/locations
struct VehicleLocationDTO: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let headingDegrees: Double
    let speedMph: Double
    let formattedLocation: String
    let timestamp: String // this will be the only timestamp we grab for now
    enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, timestamp
        case headingDegrees = "heading_degrees"
        case speedMph = "speed_mph"
        case formattedLocation = "formatted_location"
    }
}

// /api/velocities
struct VehicleVelocityDTO: Decodable {
    // speed_kmh seems redundant to the location data, TODO: ask backend the difference
    let routeName: String?
    let isAtStop: Bool
    let currentStop: String?
    enum CodingKeys: String, CodingKey {
        case routeName = "route_name"
        case isAtStop = "is_at_stop"
        case currentStop = "current_stop"
    }
}

// /api/etas
struct VehicleETADTO: Decodable {
    // Stop Name -> ISO Date String
    let stopEtaTimes: [String: String]
    enum CodingKeys: String, CodingKey {
        case stopEtaTimes = "stop_times"
    }
}
