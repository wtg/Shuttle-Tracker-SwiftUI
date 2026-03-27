import Foundation

struct MockEndpointDataGenerator {
    private static let sampleVehicleIDs = [
        "281474977371235", "212014918767475", "193847562910293",
        "847562910293847", "574839201928374", "384756102938475"
    ]
    private static let sampleNames = ["412", "425", "408", "410", "415", "422"]
    private static let sampleLocations = [
        "1511 15th Street, City of Troy, NY, 12180",
        "1423 6th Avenue, City of Troy, NY, 12180",
        "89 Congress Street, City of Troy, NY, 12180",
        "210 River Street, City of Troy, NY, 12180",
        "375 Hoosick Street, City of Troy, NY, 12180"
    ]
    private static let westStops = [
        "STUDENT_UNION", "ACADEMY_HALL", "POLYTECHNIC", "CITY_STATION",
        "BLITMAN", "CHASAN", "FEDERAL_6TH", "WEST_HALL", "STUDENT_UNION_RETURN"
    ]
    private static let northStops = [
        "STUDENT_UNION", "COLONIE", "GEORGIAN", "STAC_1",
        "STAC_2", "STAC_3", "ECAV", "HOUSTON_FIELD_HOUSE", "STUDENT_UNION_RETURN"
    ]

    // assign route based on vehicle id
    private static func route(for id: String) -> String {
        return (id.hashValue % 2 == 0) ? "WEST" : "NORTH"
    }
    private static func validStops(for route: String) -> [String] {
        return route == "WEST" ? westStops : northStops
    }

    static func generateLocations(count: Int = 3) -> [String: VehicleLocationDTO] {
        var mockLocations: [String: VehicleLocationDTO] = [:]
        let actualCount = min(max(count, 1), sampleVehicleIDs.count)
        for i in 0..<actualCount {
            let id = sampleVehicleIDs[i]
            mockLocations[id] = VehicleLocationDTO(
                name: sampleNames[i],
                latitude: Double.random(in: 42.7200...42.7350),
                longitude: Double.random(in: -73.6900...(-73.6700)),
                headingDegrees: Double.random(in: 0...360),
                speedMph: Double.random(in: 10...25),
                formattedLocation: sampleLocations.randomElement() ?? sampleLocations[0],
                timestamp: generateISOString(offsetMinutes: Int.random(in: -1...0))
            )
        }
        return mockLocations
    }

    static func generateVelocities(for vehicleIDs: [String]) -> [String: VehicleVelocityDTO] {
        var mockVelocities: [String: VehicleVelocityDTO] = [:]
        for id in vehicleIDs {
            let routeName = route(for: id)
            let isAtStop = Bool.random()
            let stops = validStops(for: routeName)
            mockVelocities[id] = VehicleVelocityDTO(
                routeName: routeName,
                isAtStop: isAtStop,
                currentStop: isAtStop ? stops.randomElement() : nil
            )
        }
        return mockVelocities
    }

    static func generateETAs(for vehicleIDs: [String]) -> [String: VehicleETADTO] {
        var mockETAs: [String: VehicleETADTO] = [:]
        for id in vehicleIDs {
            let routeName = route(for: id)
            let stops = validStops(for: routeName)

            // pick random continuous sequence of 3-5 stops for the eta
            let stopCount = Int.random(in: 3...5)
            let startIndex = Int.random(in: 0...(stops.count - stopCount))
            let sequence = Array(stops[startIndex..<(startIndex + stopCount)])

            var stopEtaTimes: [String: String] = [:]
            var currentOffsetMinutes = Double.random(in: 1.0...3.0)

            for stop in sequence {
                stopEtaTimes[stop] = generateISOString(offsetMinutes: Int(currentOffsetMinutes))
                // add 1 to 3 minutes for the next stop in the sequence
                currentOffsetMinutes += Double.random(in: 1.0...3.0)
            }
            mockETAs[id] = VehicleETADTO(stopEtaTimes: stopEtaTimes)
        }
        return mockETAs
    }

    static func generateMergedSimulation(count: Int = 3) -> [VehicleLocationData] {
        let locations = generateLocations(count: count)
        let ids = Array(locations.keys)
        let velocities = generateVelocities(for: ids)
        let etas = generateETAs(for: ids)
        return VehicleDTOMerger.merge(locations: locations, velocities: velocities, etas: etas)
    }

    private static func generateISOString(offsetMinutes: Int) -> String {
        let date = Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: Date()) ?? Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
