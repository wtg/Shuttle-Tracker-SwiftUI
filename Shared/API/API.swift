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

    /// Fetches and decodes a JSON object of type `T` from a given API endpoint.
    /// Performs an asynchronous network request, validates the HTTP response,
    /// and decodes the data into the specified type.
    /// - Requires:
    ///   - type: The Decodable type to decode the JSON into.
    ///   - endpoint: The API endpoint to append to the base URL (/schedule/ for instance)
    /// - Modifies: None
    /// - Returns: A decoded instance of type `T`.
    /// - Throws: `NetworkError` if the response is invalid or decoding fails.
    func fetch<T: Decodable>(_ type: T.Type, endpoint: String) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw NetworkError.badStatus(http.statusCode) }
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
