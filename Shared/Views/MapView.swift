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
                
                // Add vehicle markers
                ForEach(Array(vehicleLocations), id: \.key) { vehicleId, vehicle in
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
                
                // Add route polylines
                ForEach(Array(routes), id: \.key) { routeName, routeData in
                    ForEach(0..<routeData.routes.count, id: \.self) { index in
                        let coordinatePairs = routeData.routes[index]
                        
                        if coordinatePairs.count >= 2 {
                            let coordinates = coordinatePairs.compactMap { coord -> CLLocationCoordinate2D? in
                                guard coord.count == 2 else { return nil }
                                return CLLocationCoordinate2D(
                                    latitude: coord[0],
                                    longitude: coord[1]
                                )
                            }
                            
                            if coordinates.count >= 2 {
                                MapPolyline(coordinates: coordinates)
                                    .stroke(Color(hex: routeData.color), lineWidth: 2)
                            }
                        }
                    }
                    
                    // Add stop markers for this route
                    ForEach(Array(routeData.stopDetails), id: \.key) { stopName, stop in
                        if stop.coordinates.count == 2 {
                            Annotation(
                                stop.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: stop.coordinates[0],
                                    longitude: stop.coordinates[1]
                                )
                            ) {
                                ZStack {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(Color(hex: routeData.color), lineWidth: 2)
                                        )
                                    Circle()
                                        .fill(Color(hex: routeData.color))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                }
            }
            ScheduleAndETA()
        }
        .onAppear {
            fetchLocations()
            fetchRoutes()
            
            timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                fetchLocations()
            }
        }
        .onDisappear {
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
