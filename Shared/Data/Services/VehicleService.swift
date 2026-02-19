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
            async let velocitiesMap = try? client.fetch([String: VehicleVelocityDTO].self, endpoint: .vehicleVelocities)
            async let etasMap = try? client.fetch([String: VehicleETADTO].self, endpoint: .vehicleEtas)

            let (locations, velocities, etas) = try await (locationsMap, velocitiesMap, etasMap)
            self.vehicles = VehicleDTOMerger.merge(locations: locations, velocities: velocities, etas: etas)
        } catch {
            logger.error("Failed to refresh vehicles: \(error.localizedDescription)")
        }
    }
}
