import Foundation

// This should include all available API endpoints that are used in the codebase
enum Endpoint {
    case vehicleLocations
    case vehicleVelocities
    case vehicleEtas
    case routes
    case schedule
    case aggregatedSchedule
    var path: String {
        switch self {
        case .vehicleLocations:
            return "locations"
        case .vehicleVelocities:
            return "velocities"
        case .vehicleEtas:
            return "etas"
        case .routes:
            return "routes"
        case .schedule:
            return "schedule"
        case .aggregatedSchedule:
            return "aggregated-schedule"
        }
    }
}
