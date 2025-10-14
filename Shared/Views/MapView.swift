import SwiftUI
import MapKit

struct MapView: View {
    @State private var showSheet = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D.RensselaerUnion,
        span: MKCoordinateSpan(
            latitudeDelta: 0.02,
            longitudeDelta: 0.02
        )
    )
    @StateObject private var locationManager = LocationManager()
    @State private var vehicleLocations: VehicleInformationMap = [:]
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            Map(position: .constant(.region(region))) {
                UserAnnotation()
                // Add vehicle annotations
                ForEach(Array(vehicleLocations.keys), id: \.self) { vehicleId in
                    if let vehicle = vehicleLocations[vehicleId] {
                        Annotation(
                            vehicle.name,
                            coordinate: CLLocationCoordinate2D(
                                latitude: vehicle.latitude,
                                longitude: vehicle.longitude
                            )
                        ) {
                            ZStack {
                                Circle()
                                    .fill(routeColor(for: vehicle.routeName))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "bus.fill")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

            }
            ScheduleAndETA()
        }
        .onAppear {
            // Fetch immediately on startup
            fetchLocations()
            
            // Start timer for periodic updates every 5 seconds
            timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                fetchLocations()
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func fetchLocations() {
        Task {
            do {
                let locations = try await ShuttleTrackerAPI.shared.fetchVehicleLocations()
                await MainActor.run {
                    vehicleLocations = locations
                }
            } catch {
                print("Error fetching vehicle locations: \(error)")
            }
        }
    }
    
    private func routeColor(for routeName: String?) -> Color {
        switch routeName {
        case "WEST": return .blue
        case "NORTH": return .red
        default: return .gray
        }
    }
}
