import Testing
import Foundation
@testable import ShuttleTrackerApp

struct APIClientTests {
    func makeMockClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)
        return APIClient(session: mockSession)
    }

    @Test("Fetch successfully decodes location data")
    func fetchLocationsSuccess() async throws {
        let client = makeMockClient()
        let targetURL = URL(string: "https://api-shuttles.rpi.edu/api/locations")!
        let mockJSON = """
        {
            "12345": {
                "name": "412",
                "latitude": 42.7302,
                "longitude": -73.6766,
                "heading_degrees": 90.0,
                "speed_mph": 15.5,
                "formatted_location": "Student Union",
                "timestamp": "2025-10-10T12:00:00Z"
            }
        }
        """.data(using: .utf8)!

        MockURLProtocol.mockResponses[targetURL] = .success(mockJSON)

        let locations = try await client.fetch([String: VehicleLocationDTO].self, endpoint: .vehicleLocations)
        #expect(locations.count == 1)
        #expect(locations["12345"]?.name == "412")
        #expect(locations["12345"]?.speedMph == 15.5)
        #expect(locations["12345"]?.formattedLocation == "Student Union")
    }

    @Test("Fetch throws network error when connection fails")
    func fetchHandlesNetworkFailure() async {
        let client = makeMockClient()

        let targetURL = URL(string: "https://api-shuttles.rpi.edu/api/velocities")!

        let mockError = URLError(.notConnectedToInternet)
        MockURLProtocol.mockResponses[targetURL] = .failure(mockError)

        await #expect(throws: APIClient.APIError.self) {
            _ = try await client.fetch([String: VehicleVelocityDTO].self, endpoint: .vehicleVelocities)
        }
    }

    @Test("Fetch throws decoding error on invalid JSON")
    func fetchHandlesBadJSON() async {
        let client = makeMockClient()
        let targetURL = URL(string: "https://api-shuttles.rpi.edu/api/schedule")!

        let badJSON = "{ \"missing_fields\": true }".data(using: .utf8)!
        MockURLProtocol.mockResponses[targetURL] = .success(badJSON)

        await #expect(throws: APIClient.APIError.self) {
            _ = try await client.fetch(ScheduleData.self, endpoint: .schedule)
        }
    }
}
