import Testing
import Foundation
@testable import ShuttleTrackerApp

struct VehicleMergerTests {
    @Test("Merger handles missing velocity and ETA data")
    func testMergeWithIncompleteData() {
        // base location data -- should be the only required data
        let locations: [String: VehicleLocationDTO] = [
            "bus_1": VehicleLocationDTO(name: "412", latitude: 42.7302, longitude: -73.6766, headingDegrees: 0, speedMph: 15, formattedLocation: "Union", timestamp: "2026-04-14T12:00:00Z"),
            "bus_2": VehicleLocationDTO(name: "408", latitude: 42.7310, longitude: -73.6700, headingDegrees: 90, speedMph: 20, formattedLocation: "ECAV", timestamp: "2026-04-14T12:00:00Z")
        ]

        // velocity missing for bus_2
        let velocities: [String: VehicleVelocityDTO] = [
            "bus_1": VehicleVelocityDTO(routeName: "WEST", isAtStop: true, currentStop: "STUDENT_UNION")
        ]

        // ETA is nil
        let etas: [String: VehicleETADTO]? = nil
        let merged = VehicleDTOMerger.merge(locations: locations, velocities: velocities, etas: etas)

        #expect(merged.count == 2)

        // verify bus_1 has velocity data mapped correctly
        let bus1 = merged.first(where: { $0.id == "412" })!
        #expect(bus1.routeName == "WEST")
        #expect(bus1.isAtStop == true)
        #expect(bus1.currentStop == "STUDENT_UNION")
        #expect(bus1.stopEtaTimes.isEmpty)

        // verify bus_2 uses safe fallbacks without crashing
        let bus2 = merged.first(where: { $0.id == "408" })!
        #expect(bus2.routeName == "unknown")
        #expect(bus2.isAtStop == false)
        #expect(bus2.currentStop == nil)
        #expect(bus2.stopEtaTimes.isEmpty)
    }

    @Test("Merger intentionally drops vehicles if location data is missing")
    func testMergeRequiresLocation() {
        let locations: [String: VehicleLocationDTO] = [:]

        // we have velocity and ETA data, but no location for "bus_1"
        let velocities: [String: VehicleVelocityDTO] = [
            "bus_1": VehicleVelocityDTO(routeName: "WEST", isAtStop: false, currentStop: nil)
        ]
        let etas: [String: VehicleETADTO] = [
            "bus_1": VehicleETADTO(stopEtaTimes: ["STUDENT_UNION": "2026-04-14T12:05:00Z"])
        ]

        let merged = VehicleDTOMerger.merge(locations: locations, velocities: velocities, etas: etas)

        // vehicle shouldn't exist on the map without coordinates
        #expect(merged.isEmpty)
    }
}
