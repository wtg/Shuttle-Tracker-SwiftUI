import SwiftUI
import MapKit

struct MapView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showOnboarding = false
    
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
    @StateObject private var routeManager = RouteDataManager()
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            Map(position: .constant(.region(region))) {
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
                
                // Add route polylines (filtered by RouteDataManager based on today's schedule)
                ForEach(Array(routeManager.routes), id: \.key) { routeName, routeData in
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
                
                UserAnnotation()
            }
            ScheduleAndETA()
        }
        .onAppear {
            fetchLocations()
            // Routes are now managed by RouteDataManager
            
            if !hasSeenOnboarding {
                showOnboarding = true
            }
            
            timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                fetchLocations()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }.sheet(isPresented: $showOnboarding) {
            VStack(spacing: 16) {
                Image(systemName: "location.circle.fill").font(.system(size: 56)).foregroundStyle(.tint)
                Text("We use your location to show nearby shuttles")
                    .font(.title2).bold()
                    .multilineTextAlignment(.center)
                Text("We are going to ask for your location to show on the map. Your location helps us center the map and calculate accurate ETAs for stops near you.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
                Button(action: {
                    locationManager.requestAuthorization()
                    hasSeenOnboarding = true
                    showOnboarding = false
                }) {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .cornerRadius(16)
                Button("Not Now") {
                    hasSeenOnboarding = true
                    showOnboarding = false
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .presentationDetents([.medium, .large])
        }
    }
    
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
    
    private func routeColor(for routeName: String?) -> Color {
        switch routeName {
        case "WEST": return .blue
        case "NORTH": return .red
        default: return .gray
        }
    }
}

#Preview {
    MapView()
}
