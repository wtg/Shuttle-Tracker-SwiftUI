//
//  RouteDataManager.swift
//  iOS
//
//  Created by RS on 12/13/25.
//

import Combine
import Foundation
import Network
import OSLog

private let logger = Logger(subsystem: "edu.rpi.shuttletracker", category: "RouteData")

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

  // Constants
  private static let refreshInterval: TimeInterval = 300  // 5 minutes

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

  // Note: Cleanup is handled via stored references that will be released when this object deallocates.
  // Timer and NWPathMonitor will stop when their references are released.
  // For explicit cleanup, call cleanup() before releasing the object.
  func cleanup() {
    refreshTimer?.invalidate()
    refreshTimer = nil
    pathMonitor.cancel()
    routesRetryTask?.cancel()
    routesRetryTask = nil
    scheduleRetryTask?.cancel()
    scheduleRetryTask = nil
  }

  // MARK: - Network Monitoring

  private func setupNetworkMonitor() {
    pathMonitor.pathUpdateHandler = { [weak self] path in
      let usesWiFi = path.usesInterfaceType(.wifi)
      guard let strongSelf = self else { return }
      Task { @MainActor in
        strongSelf.isOnWiFi = usesWiFi
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

  private func invalidateCache() {
    logger.info("Invalidating cache due to day change")
    allRoutes = [:]
    aggregatedSchedule = []
    try? FileManager.default.removeItem(at: routesCacheURL)
    try? FileManager.default.removeItem(at: scheduleCacheURL)
  }

  // MARK: - Data Fetching

  private func fetchData() async {
    // Check if day changed - invalidate cache if so
    if let lastDate = lastFetchDate, !Calendar.current.isDateInToday(lastDate) {
      invalidateCache()
    }

    await fetchRoutes()
    // await fetchAggregatedSchedule()
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
      logger.warning("Initial routes fetch failed (using cache): \(error.localizedDescription)")
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
      logger.warning(
        "Initial aggregated schedule fetch failed (using cache): \(error.localizedDescription)")
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
    refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) {
      [weak self] _ in
      Task { @MainActor in
        guard let self = self else { return }

        // Check for day change first - always refresh if day changed
        let dayChanged =
          self.lastFetchDate.map { !Calendar.current.isDateInToday($0) } ?? false

        if dayChanged {
          logger.info("Day changed, forcing refresh")
          await self.fetchData()
        } else if self.isOnWiFi {
          // Only refresh on WiFi to save mobile data
          logger.debug("Refreshing route data (WiFi detected)")
          await self.fetchData()
        } else {
          logger.debug("Skipping refresh (not on WiFi)")
        }
      }
    }
  }

  /// Force a manual refresh of route data
  func refresh() async {
    await fetchData()
  }
}
