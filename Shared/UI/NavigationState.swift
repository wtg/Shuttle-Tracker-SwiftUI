import SwiftUI
import MapKit
import Combine

@MainActor
class NavigationState: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var focusCoordinate: CLLocationCoordinate2D?
    @Published var focusVehicleName: String?
}
