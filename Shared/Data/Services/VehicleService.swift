import Foundation
import Combine
import OSLog

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

    // Fetches the locations, velocities, and ETAs in parallel then merges them
    func refreshVehicles() async {
        do {
            async let locationsMap = client.fetch([String: VehicleLocationDTO].self, endpoint: .vehicleLocations)
            async let velocitiesMap = client.fetch([String: VehicleVelocityDTO].self, endpoint: .vehicleVelocities)
            async let etasMap = client.fetch([String: VehicleETADTO].self, endpoint: .vehicleEtas)

            let (locations, velocities, etas) = try await (locationsMap, velocitiesMap, etasMap)

            var mergedVehicles: [VehicleLocationData] = []
            for (id, loc) in locations {
                // get the corresponding response for this bus id from velocities and eta data
                let velocity = velocities[id]
                let eta = etas[id]
                let vehicle = VehicleLocationData(
                    // location
                    name: loc.name,
                    latitude: loc.latitude,
                    longitude: loc.longitude,
                    headingDegrees: loc.headingDegrees,
                    speedMph: loc.speedMph,
                    timestamp: loc.timestamp,
                    formattedLocation: loc.formattedLocation,

                    // velocities
                    routeName: velocity?.routeName ?? "unknown",
                    isAtStop: velocity?.isAtStop ?? false,
                    currentStop: velocity?.currentStop ?? nil,

                    // etas
                    stopEtaTimes: eta?.stopEtaTimes ?? [:]
                )
                mergedVehicles.append(vehicle)
            }

            self.vehicles = mergedVehicles
        } catch {
            logger.error("Failed to refresh vehicles: \(error.localizedDescription)")
        }
    }
}
