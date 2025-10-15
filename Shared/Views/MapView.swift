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
    @State private var routes: ShuttleRouteData = [:]
    @State private var timer: Timer?
    
    
    var body: some View {
        ZStack {
            Map(position: .constant(.region(region))) {
                UserAnnotation()
                // Add vehicle annotations
                ForEach(Array(vehicleLocations.keys), id: \.self) { vehicleId in
                    if let vehicle = vehicleLocations[vehicleId] {
                        Marker(
                            vehicle.name,
                            systemImage: "bus.fill",
                            coordinate: CLLocationCoordinate2D(
                                latitude: vehicle.latitude,
                                longitude: vehicle.longitude
                            )
                        )
                        .tint(routeColor(for: vehicle.routeName))
                    }
                }
                
                // Add route polylines
                ForEach(Array(routes.keys), id: \.self) { routeName in
                    if let routeData = routes[routeName] {
                        ForEach(0..<routeData.routes.count, id: \.self) { index in
                            let coordinatePairs = routeData.routes[index]
                            
                            // Only draw if we have at least 2 coordinate pairs
                            if coordinatePairs.count >= 2 {
                                let coordinates = coordinatePairs.compactMap { coord -> CLLocationCoordinate2D? in
                                    // Validate each coordinate has exactly 2 values
                                    guard coord.count == 2 else { return nil }
                                    return CLLocationCoordinate2D(
                                        latitude: coord[0],
                                        longitude: coord[1]
                                    )
                                }
                                
                                // Only create polyline if we have valid coordinates
                                if coordinates.count >= 2 {
                                    MapPolyline(coordinates: coordinates)
                                        .stroke(Color(hex: routeData.color), lineWidth: 2)
                                }
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
            fetchRoutes()
            
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
    
    private func fetchRoutes() {
        Task {
            do {
                let routeData = try await ShuttleTrackerAPI.shared.fetchRoutes()
                await MainActor.run {
                    routes = routeData
                }
            } catch {
                print("Error fetching routes: \(error)")
            }
        }
    }
}
