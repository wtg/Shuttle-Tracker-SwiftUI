//
//  API.swift
//  iOS
//
//  Created by RS on 10/10/25.
//
import Foundation
import OSLog

private let logger = Logger(subsystem: "edu.rpi.shuttletracker", category: "API")

struct API {
  static let shared = API()

  private let baseURL: URL = URL(string: "https://shuttles.rpi.edu/api")!

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
    }

    guard let http = response as? HTTPURLResponse else {
      throw APIError.invalidResponse
    }
    guard (200...299).contains(http.statusCode) else {
      throw APIError.badStatus(http.statusCode)
    }

    do {
      let decoder = JSONDecoder()
      return try decoder.decode(T.self, from: data)
    } catch {
      throw APIError.decodingError(underlying: error)
    }
  }

  /// Result of a fetch attempt with background retry capability
  struct FetchResult<T> {
    let result: Result<T, Error>
    /// Background retry task (nil if initial fetch succeeded). Cancel this to stop retries.
    let retryTask: Task<Void, Never>?
  }

  /// Attempts to fetch data. On failure, spawns background retries with exponential backoff.
  /// - Parameters:
  ///   - type: The Decodable type to decode into
  ///   - endpoint: API endpoint path
  ///   - maxRetries: Maximum number of background retry attempts (default: 3)
  ///   - onRetrySuccess: Callback invoked on main thread when a background retry succeeds
  /// - Returns: FetchResult containing the immediate result and a cancellable retry task
  func fetchWithBackgroundRetry<T: Decodable>(
    _ type: T.Type,
    endpoint: String,
    maxRetries: Int = 3,
    onRetrySuccess: @escaping (T) -> Void
  ) async -> FetchResult<T> {
    // Try immediate fetch
    do {
      let result = try await fetch(type, endpoint: endpoint)
      return FetchResult(result: .success(result), retryTask: nil)
    } catch {
      // Spawn background retry task
      let retryTask = Task.detached {
        await self.backgroundRetry(
          type,
          endpoint: endpoint,
          maxRetries: maxRetries,
          onSuccess: onRetrySuccess
        )
      }
      return FetchResult(result: .failure(error), retryTask: retryTask)
    }
  }

  private func backgroundRetry<T: Decodable>(
    _ type: T.Type,
    endpoint: String,
    maxRetries: Int,
    onSuccess: @escaping (T) -> Void
  ) async {
    var delay: UInt64 = 2_000_000_000  // Start with 2 seconds

    for attempt in 1...maxRetries {
      // Check for cancellation before sleeping
      guard !Task.isCancelled else {
        logger.debug("Background retry cancelled for \(endpoint)")
        return
      }

      do {
        try await Task.sleep(nanoseconds: delay)
      } catch {
        // Task was cancelled during sleep
        logger.debug("Background retry cancelled during sleep for \(endpoint)")
        return
      }

      // Check for cancellation before fetching
      guard !Task.isCancelled else {
        logger.debug("Background retry cancelled for \(endpoint)")
        return
      }

      do {
        let result = try await fetch(type, endpoint: endpoint)
        await MainActor.run {
          onSuccess(result)
        }
        logger.info("Background retry succeeded on attempt \(attempt) for \(endpoint)")
        return
      } catch {
        logger.warning(
          "Background retry attempt \(attempt) failed for \(endpoint): \(error.localizedDescription)"
        )
        delay *= 2  // Exponential backoff: 2s, 4s, 8s
      }
    }
    logger.error("All background retries exhausted for \(endpoint)")
  }
}
