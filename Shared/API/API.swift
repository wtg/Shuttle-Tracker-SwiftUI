//
//  API.swift
//  iOS
//
//  Created by RS on 10/10/25.
//
import Foundation

struct API {
    static let shared = API()
    
    private let baseURL: URL = URL(string: "https://shuttles.rpi.edu/api")!
    
    enum NetworkError: Error {
        case badStatus(Int)
        case invalidResponse
    }

    func fetch<T: Decodable>(_ type: T.Type, endpoint: String) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw NetworkError.badStatus(http.statusCode) }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
