//
//  RouteDataManager.swift
//  iOS
//
//  Created by Antigravity on 12/13/25.
//

import Combine
import Foundation
import Network

/// Centralized manager for route data with caching, periodic refresh, and retry logic
@MainActor
class RouteDataManager: ObservableObject {
  /// Filtered routes for the current day (only routes in today's aggregated schedule)
  @Published private(set) var routes: ShuttleRouteData = [:]

  /// Set of route names that are active today based on aggregated schedule
  @Published private(set) var activeRouteNames: Set<String> = []

  /// Whether the initial data load is complete (from cache or network)
  @Published private(set) var isLoaded: Bool = false

  private var allRoutes: ShuttleRouteData = [:]
  private var aggregatedSchedule: AggregatedSchedule = []
  private var refreshTimer: Timer?
  private var lastFetchDate: Date?
  private let pathMonitor = NWPathMonitor()
  private var isOnWiFi = false

  // Active background retry tasks (cancel these when starting new fetches)
  private var routesRetryTask: Task<Void, Never>?
  private var scheduleRetryTask: Task<Void, Never>?

  // Cache file paths
  private var routesCacheURL: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("routes_cache.json")
  }
  private var scheduleCacheURL: URL {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("aggregated_schedule_cache.json")
  }
  private var lastFetchDateKey: String { "RouteDataManager.lastFetchDate" }

  init() {
    setupNetworkMonitor()
    loadCachedData()
    Task {
      await fetchData()
    }
    startRefreshTimer()
  }

  deinit {
    refreshTimer?.invalidate()
    pathMonitor.cancel()
    routesRetryTask?.cancel()
    scheduleRetryTask?.cancel()
  }

  // MARK: - Network Monitoring

  private func setupNetworkMonitor() {
    pathMonitor.pathUpdateHandler = { [weak self] path in
      let usesWiFi = path.usesInterfaceType(.wifi)
      Task { @MainActor in
        self?.isOnWiFi = usesWiFi
      }
    }
    pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
  }

  // MARK: - Caching

  private func loadCachedData() {
    // Load cached routes
    if let data = try? Data(contentsOf: routesCacheURL),
      let cached = try? JSONDecoder().decode(ShuttleRouteData.self, from: data)
    {
      allRoutes = cached
    }

    // Load cached schedule
    if let data = try? Data(contentsOf: scheduleCacheURL),
      let cached = try? JSONDecoder().decode(AggregatedSchedule.self, from: data)
    {
      aggregatedSchedule = cached
    }

    // Load last fetch date
    if let date = UserDefaults.standard.object(forKey: lastFetchDateKey) as? Date {
      lastFetchDate = date
    }

    // Apply filtering with cached data
    updateFilteredRoutes()

    if !allRoutes.isEmpty {
      isLoaded = true
    }
  }

  private func saveToCache() {
    // Save routes
    if let data = try? JSONEncoder().encode(allRoutes) {
      try? data.write(to: routesCacheURL)
    }

    // Save schedule
    if let data = try? JSONEncoder().encode(aggregatedSchedule) {
      try? data.write(to: scheduleCacheURL)
    }

    // Save fetch date
    lastFetchDate = Date()
    UserDefaults.standard.set(lastFetchDate, forKey: lastFetchDateKey)
  }

  // MARK: - Data Fetching

  private func fetchData() async {
    // Check if day changed - invalidate cache if so
    if let lastDate = lastFetchDate, !Calendar.current.isDateInToday(lastDate) {
      print("Day changed, invalidating cache")
    }

    await fetchRoutes()
    await fetchAggregatedSchedule()
    updateFilteredRoutes()
    saveToCache()
    isLoaded = true
  }

  private func fetchRoutes() async {
    // Cancel any pending background retries before starting new fetch
    routesRetryTask?.cancel()
    routesRetryTask = nil

    let fetchResult = await API.shared.fetchWithBackgroundRetry(
      ShuttleRouteData.self,
      endpoint: "routes"
    ) { [weak self] routes in
      Task { @MainActor in
        self?.allRoutes = routes
        self?.updateFilteredRoutes()
        self?.saveToCache()
      }
    }

    // Store the retry task so we can cancel it later if needed
    routesRetryTask = fetchResult.retryTask

    switch fetchResult.result {
    case .success(let routes):
      allRoutes = routes
    case .failure(let error):
      print("Initial routes fetch failed (using cache): \(error)")
    }
  }

  private func fetchAggregatedSchedule() async {
    // Cancel any pending background retries before starting new fetch
    scheduleRetryTask?.cancel()
    scheduleRetryTask = nil

    let fetchResult = await API.shared.fetchWithBackgroundRetry(
      AggregatedSchedule.self,
      endpoint: "aggregated-schedule"
    ) { [weak self] schedule in
      Task { @MainActor in
        self?.aggregatedSchedule = schedule
        self?.updateFilteredRoutes()
        self?.saveToCache()
      }
    }

    // Store the retry task so we can cancel it later if needed
    scheduleRetryTask = fetchResult.retryTask

    switch fetchResult.result {
    case .success(let schedule):
      aggregatedSchedule = schedule
    case .failure(let error):
      print("Initial aggregated schedule fetch failed (using cache): \(error)")
    }
  }

  // MARK: - Route Filtering

  private func updateFilteredRoutes() {
    activeRouteNames = aggregatedSchedule.activeRouteNames()

    // If we have aggregated schedule data, filter routes by active routes
    if !activeRouteNames.isEmpty {
      routes = allRoutes.filter { activeRouteNames.contains($0.key) }
    } else {
      // Fallback: show all routes if schedule unavailable
      routes = allRoutes
    }
  }

  // MARK: - Periodic Refresh

  private func startRefreshTimer() {
    // Refresh every 5 minutes, but only on WiFi
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
      Task { @MainActor in
        guard let self = self else { return }

        // Only refresh on WiFi to save mobile data
        if self.isOnWiFi {
          print("Refreshing route data (WiFi detected)")
          await self.fetchData()
        } else {
          print("Skipping refresh (not on WiFi)")
        }

        // Always check for day change regardless of network
        if let lastDate = self.lastFetchDate, !Calendar.current.isDateInToday(lastDate) {
          print("Day changed, forcing refresh")
          await self.fetchData()
        }
      }
    }
  }

  /// Force a manual refresh of route data
  func refresh() async {
    await fetchData()
  }
}
