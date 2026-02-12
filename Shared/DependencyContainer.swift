import Foundation
import SwiftUI
import Combine

// container to hold the app's core services.
// allows us to avoid redundant definitions/operations throughout the codebase
@MainActor
class DependencyContainer: ObservableObject {
    let vehicleService: VehicleService
    let routeService: RouteService
    let scheduleService: ScheduleService
    let locationManager: LocationManager

    init() {
        self.locationManager = LocationManager()
        self.vehicleService = VehicleService()
        self.routeService = RouteService()
        self.scheduleService = ScheduleService()
    }
}

extension DependencyContainer {
    static var preview: DependencyContainer {
        return DependencyContainer()
    }
}
