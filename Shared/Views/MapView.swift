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
                
                // Add vehicle markers, coloring them appropriatel.y
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
                
                // For all the varying routes, we draw individually its polylines AND stops.
                ForEach(Array(routes), id: \.key) { routeName, routeData in
                    if routeData.color != "#00000000" {
                        // LOOP DESCRIPTION: 
                        // We draw each segment of route as a polyline
                        // We take in a coordinate pair from the route data, split it up
                        // and then convert to a CLLocationCoordinate2D object.
                        // We then use the Swift Polyline features to draw colored lines between these.
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
            }
            ScheduleAndETA()
        }
        .onAppear {
            fetchLocations()
            fetchRoutes()
            
            // every 5 seconds, we refresh and fetch the new bus locations to redraw.
            timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                fetchLocations()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // Update loactions
    private func fetchLocations() {
        Task {
            do {
                let locations = try await API.shared.fetch(VehicleInformationMap.self, endpoint: "locations")
                await MainActor.run {
                    vehicleLocations = locations
                }
            } catch {
                print("Error fetching vehicle locations: \(error)")
            }
        }
    }
    
    //  General route colors, if future routes are added (or if styling needs to be changed) it will happen here
    private func routeColor(for routeName: String?) -> Color {
        switch routeName {
        case "WEST": return .blue
        case "NORTH": return .red
        default: return .gray
        }
    }

    // self explanatory, fetches all routes from the API endpoints. Has a generic catch statement for any errors that may arise
    // TODO: Better error handling (mismatched format, server error, timeout, etc)
    private func fetchRoutes() {
        Task {
            do {
                let routeData = try await API.shared.fetch(ShuttleRouteData.self, endpoint: "routes")
                await MainActor.run {
                    routes = routeData
                }
            } catch {
                print("Error fetching routes: \(error)")
            }
        }
    }
}

#Preview {
    MapView()
}
