import Foundation
import Combine
import OSLog
import WidgetKit

private let logger = Logger(subsystem: "edu.rpi.shuttletracker", category: "VehicleService")

@MainActor
class VehicleService: ObservableObject {
    @Published var vehicles: [VehicleLocationData] = []

    private var timer: Timer?
    private let client = APIClient.shared

    init() {
        startPolling()
    }

    func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { await self?.refreshVehicles() }
        }
        Task { await refreshVehicles() }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    /* Fetches the locations, velocities, and ETAs in parallel then merges them.
     * Manual refresh is available from the ETAListView, because that is where
     *  up-to-date information is most important.
     */
    func refreshVehicles(isManualRefresh: Bool = false) async {
        let isDevMode = UserDefaults.standard.bool(forKey: "isDeveloperMode")
        let isMockEnabled = isDevMode && UserDefaults.standard.bool(forKey: "useMockData")
        if isMockEnabled {
            let scenario = UserDefaults.standard.string(forKey: "mockScenario") ?? "standard"
            let mockData = MockEndpointDataGenerator.generateMergedSimulation(scenario: scenario)
            await MainActor.run { self.vehicles = mockData }
            if isManualRefresh { WidgetCenter.shared.reloadAllTimelines() }
            return
        }

        do {
            async let locationsMap = client.fetch([String: VehicleLocationDTO].self, endpoint: .vehicleLocations)
            async let velocitiesMap = try? client.fetch([String: VehicleVelocityDTO].self, endpoint: .vehicleVelocities)
            async let etasMap = try? client.fetch([String: VehicleETADTO].self, endpoint: .vehicleEtas)

            let (locations, velocities, etas) = try await (locationsMap, velocitiesMap, etasMap)
            self.vehicles = VehicleDTOMerger.merge(locations: locations, velocities: velocities, etas: etas)

            if isManualRefresh {
                printRawETAs(self.vehicles) /* for debugging purposes */
                WidgetCenter.shared.reloadAllTimelines()
            }
        } catch {
            logger.error("Failed to refresh vehicles: \(error.localizedDescription)")
        }
    }
    private func printRawETAs(_ vehicles: [VehicleLocationData]) {
        print("\n=== Manual Refresh: Raw Vehicle ETAS ===")
        print("Current time: \(Date().formattedTimeWithSeconds)")
        for vehicle in vehicles {
            print("Shuttle: \(vehicle.name) | Route: \(vehicle.routeName) | Updated: \(vehicle.timestamp.formattedTimeWithSeconds)")
            if vehicle.stopEtaTimes.isEmpty {
                print("   No ETAs available.")
            } else {
                let sortedEtas = vehicle.stopEtaTimes.sorted {
                    let date1 = $0.value.isoTimeToDate ?? Date.distantFuture
                    let date2 = $1.value.isoTimeToDate ?? Date.distantFuture
                    return date1 < date2
                }
                for (stop, time) in sortedEtas {
                    print("   - \(stop): \(time.formattedTimeWithSeconds)")
                }
            }
        }
        print("========================================\n")
    }
}
