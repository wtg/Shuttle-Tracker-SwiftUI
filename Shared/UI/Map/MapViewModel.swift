import SwiftUI
import MapKit
import Combine

@MainActor
class MapViewModel: ObservableObject {
    @Published var region: MKCoordinateRegion
    @Published var showSettings: Bool = false
    @Published var showDeveloperPanel: Bool = false
    @Published var selectedVehicle: VehicleLocationData? = nil

    private let locationManager: LocationManager
    init(locationManager: LocationManager) {
        self.locationManager = locationManager

        // RPI Union location
        self.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 42.7302, longitude: -73.6766),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    }

    func requestLocation() {
        locationManager.requestAuthorization()
    }

    func toggleDeveloperPanel() {
        withAnimation {
            showDeveloperPanel.toggle()
        }
    }

    func focusOnUser() {
        if let location = locationManager.location {
            withAnimation {
                region.center = location.coordinate
                region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            }
        } else {
            requestLocation()
        }
    }
}
