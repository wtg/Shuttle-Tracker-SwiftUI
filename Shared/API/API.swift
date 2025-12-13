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
        var delay: UInt64 = 2_000_000_000 // Start with 2 seconds
        
        for attempt in 1...maxRetries {
            // Check for cancellation before sleeping
            guard !Task.isCancelled else {
                print("Background retry cancelled for \(endpoint)")
                return
            }
            
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                // Task was cancelled during sleep
                print("Background retry cancelled during sleep for \(endpoint)")
                return
            }
            
            // Check for cancellation before fetching
            guard !Task.isCancelled else {
                print("Background retry cancelled for \(endpoint)")
                return
            }
            
            do {
                let result = try await fetch(type, endpoint: endpoint)
                await MainActor.run {
                    onSuccess(result)
                }
                print("Background retry succeeded on attempt \(attempt) for \(endpoint)")
                return
            } catch {
                print("Background retry attempt \(attempt) failed for \(endpoint): \(error)")
                delay *= 2 // Exponential backoff: 2s, 4s, 8s
            }
        }
        print("All background retries exhausted for \(endpoint)")
    }
}
