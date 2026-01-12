//
//  API.swift
//  iOS
//
//  Created by RS on 10/10/25.
//
import Foundation

struct API {
<<<<<<< Updated upstream
    static let shared = API()
    
    private let baseURL: URL = URL(string: "https://shuttles.rpi.edu/api")!
    
    enum NetworkError: Error {
        case badStatus(Int)
        case invalidResponse
=======
  static let shared = API()

  private let baseURL: URL = URL(string: "https://api-shuttles.rpi.edu/api")!

  /// Typed API errors for better error handling
  enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case badStatus(Int)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)

    var errorDescription: String? {
      switch self {
      case .invalidURL:
        return "Invalid URL"
      case .invalidResponse:
        return "Invalid response from server"
      case .badStatus(let code):
        return "Server returned status code \(code)"
      case .networkError(let error):
        return "Network error: \(error.localizedDescription)"
      case .decodingError(let error):
        return "Failed to decode response: \(error.localizedDescription)"
      }
    }
  }

  func fetch<T: Decodable>(_ type: T.Type, endpoint: String) async throws -> T {
    let url = baseURL.appendingPathComponent(endpoint)
    let data: Data
    let response: URLResponse

    do {
      (data, response) = try await URLSession.shared.data(from: url)
    } catch {
      throw APIError.networkError(underlying: error)
>>>>>>> Stashed changes
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
