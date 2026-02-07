//
//  RouteDataManager.swift
//  iOS
//
//  Created by RS on 12/13/25.
//

import Foundation
import Combine
import OSLog
import UIKit

private let logger = Logger(subsystem: "edu.rpi.shuttletracker", category: "RouteService")

/// Centralized manager for route data with caching, periodic refresh, and retry logic
@MainActor
class RouteService: ObservableObject {
    /// Filtered routes for the current day (only routes in today's aggregated schedule)
    @Published private(set) var activeRoutes: ShuttleRouteData = [:]
    @Published var isLoaded: Bool = false

    /// All routes downloaded from the server (even ones not running today).
    private var allRoutes: ShuttleRouteData = [:]
    private let client = APIClient.shared
    private let cache = CacheManager.shared
    private let lastFetchDateKey = "RouteService.lastFetchDate"

    private var currentSchedule: AggregatedSchedule?

    init() {
        loadFromCache()

        // only refresh the data if it's a new day.
        // we don't need to be refreshing the schedule on a timer.
        Task { self.checkForRefresh() }

        // creates a trigger for significant time changes (i.e. midnight)
        NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.checkForRefresh(force: true) }
        }
    }

    // should be called from the view when forcing a refresh
    func checkForRefresh(force: Bool = false) {
        let lastDate = UserDefaults.standard.object(forKey: lastFetchDateKey) as? Date
        if force || lastDate == nil || !Calendar.current.isDateInToday(lastDate!) {
            logger.info("Refreshing Routes & Schedule...")
            Task { await refreshData() }
        }
    }

    // refresh both Route Geometry and Schedule Status in parallel
    func refreshData() async {
        async let routesResult = client.fetchWithBackgroundRetry(ShuttleRouteData.self, endpoint: .routes) { _ in }
        async let scheduleResult = client.fetchWithBackgroundRetry(AggregatedSchedule.self, endpoint: .aggregatedSchedule) { _ in }

        let (routesParams, scheduleParams) = await (routesResult, scheduleResult)

        // update 'all routes'
        if case .success(let routes) = routesParams.result {
            self.allRoutes = routes
            cache.save(routes, key: .routes)
        }

        // update schedule
        if case .success(let schedule) = scheduleParams.result {
            self.currentSchedule = schedule
            cache.save(schedule, key: .aggregatedSchedule)
        }

        if case .success = routesParams.result {
            UserDefaults.standard.set(Date(), forKey: lastFetchDateKey)
        }

        if let schedule = self.currentSchedule {
            filterRoutes(using: schedule)
        } else {
            // fallback if we don't get the routes, just display everything
            self.activeRoutes = self.allRoutes
        }

        self.isLoaded = true
    }

    private func filterRoutes(using schedule: AggregatedSchedule) {
        let activeNames = schedule.activeRouteNames()
        if activeNames.isEmpty {
            self.activeRoutes = self.allRoutes
        } else {
            self.activeRoutes = self.allRoutes.filter { activeNames.contains($0.key) }
        }
        logger.info("Updated active routes: \(self.activeRoutes.keys.joined(separator: ", "))")
    }

    private func loadFromCache() {
        if let cachedRoutes = cache.load(ShuttleRouteData.self, key: .routes) {
            self.allRoutes = cachedRoutes
            // always re-filter cache on load to apply the new day's schedule logic
            if let cachedSchedule = cache.load(AggregatedSchedule.self, key: .aggregatedSchedule) {
                self.currentSchedule = cachedSchedule
                filterRoutes(using: cachedSchedule)
            } else {
                self.activeRoutes = cachedRoutes
            }
            self.isLoaded = true
        }
    }
}
