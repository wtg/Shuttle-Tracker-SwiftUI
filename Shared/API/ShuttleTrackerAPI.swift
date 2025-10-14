import Foundation

//
//  ShuttleTrackerAPI.swift
//  iOS
//
//  Created by RS on 10/10/25.
//

struct ShuttleTrackerAPI {
    static let shared = ShuttleTrackerAPI()
    
    enum NetworkError: Error {
        case badStatus(Int)
        case invalidResponse
    }

    private func fetchJSON<T: Decodable>(from url: URL, as type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw NetworkError.badStatus(http.statusCode) }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    func fetchVehicleLocations() async throws -> VehicleInformationMap {
        try await fetchJSON(from: URL(string: "https://shuttles.rpi.edu/api/locations")!, as: VehicleInformationMap.self)
    }

    func fetchSchedule() async throws -> ScheduleData {
        try await fetchJSON(from: URL(string: "https://shuttles.rpi.edu/api/schedule")!, as: ScheduleData.self)
    }

    func fetchRoutes() async throws -> ShuttleRouteData {
        try await fetchJSON(from: URL(string: "https://shuttles.rpi.edu/api/routes")!, as: ShuttleRouteData.self)
    }
}
