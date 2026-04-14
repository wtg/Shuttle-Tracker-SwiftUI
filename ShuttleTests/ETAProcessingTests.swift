import Testing
import Foundation
@testable import ShuttleTrackerApp

struct ETAProcessorTests {
    @Test("ETAs are correctly grouped by route and sorted by time")
    func testGetGroupedETAs() {
        let routes: ShuttleRouteData = [
            "WEST": RouteDirectionData(color: "#0000FF", stops: ["UNION"], polylineStops: [], routes: [], stopDetails: ["UNION": ShuttleStopData(coordinates: [], offset: 0, name: "Student Union")]),
            "NORTH": RouteDirectionData(color: "#FF0000", stops: ["ECAV"], polylineStops: [], routes: [], stopDetails: ["ECAV": ShuttleStopData(coordinates: [], offset: 0, name: "ECAV")])
        ]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        let timeIn5Mins = formatter.string(from: now.addingTimeInterval(300))
        let timeIn10Mins = formatter.string(from: now.addingTimeInterval(600))

        let vehicle1 = VehicleLocationData(name: "412", latitude: 0, longitude: 0, headingDegrees: 0, speedMph: 0, timestamp: "", formattedLocation: "", routeName: "WEST", isAtStop: false, currentStop: nil, stopEtaTimes: ["UNION": timeIn10Mins])
        let vehicle2 = VehicleLocationData(name: "408", latitude: 0, longitude: 0, headingDegrees: 0, speedMph: 0, timestamp: "", formattedLocation: "", routeName: "NORTH", isAtStop: false, currentStop: nil, stopEtaTimes: ["ECAV": timeIn5Mins])

        let groupedETAs = ETAProcessor.getGroupedETAs(vehicles: [vehicle1, vehicle2], routes: routes)

        #expect(groupedETAs.count == 2)
        let northGroup = groupedETAs.first(where: { $0.id == "NORTH" })
        #expect(northGroup != nil)
        #expect(northGroup?.etas.count == 1)
        #expect(northGroup?.etas.first?.stopKey == "ECAV")

        // North should have the 5 min ETA, West should have the 10 min ETA
        #expect(northGroup?.etas.first?.vehicleName == "408")
    }

    @Test("VehicleLocationData correctly filters future ETAs and finds the soonest")
    func testFutureEtasAndSoonest() {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let pastDate = now.addingTimeInterval(-300) // 5 mins ago
        let pastToleranceDate = now.addingTimeInterval(-30) // 30 secs ago (within -120s tolerance)
        let futureDate1 = now.addingTimeInterval(300) // 5 mins into the future
        let futureDate2 = now.addingTimeInterval(600) // 10 mins into the future

        let etas = [
            "STOP_PAST": formatter.string(from: pastDate),
            "STOP_TOLERANCE": formatter.string(from: pastToleranceDate),
            "STOP_FUTURE_1": formatter.string(from: futureDate1),
            "STOP_FUTURE_2": formatter.string(from: futureDate2)
        ]

        let vehicle = VehicleLocationData(
            name: "TestBus", latitude: 0, longitude: 0, headingDegrees: 0, speedMph: 0,
            timestamp: formatter.string(from: now), formattedLocation: "Test",
            routeName: "WEST", isAtStop: false, currentStop: nil, stopEtaTimes: etas
        )

        let futureEtas = vehicle.futureEtas

        // should only drop STOP_PAST
        #expect(futureEtas.count == 3)
        #expect(futureEtas["STOP_PAST"] == nil)
        #expect(futureEtas["STOP_TOLERANCE"] != nil)

        let soonest = vehicle.soonestFutureEta(for: ["STOP_FUTURE_1", "STOP_FUTURE_2", "STOP_PAST"])
        #expect(soonest == formatter.string(from: futureDate1))
    }
}
