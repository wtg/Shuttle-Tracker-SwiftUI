import SwiftUI
import MapKit
import WidgetKit

struct MapView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var navigationState: NavigationState
    @StateObject private var viewModel: MapViewModel

    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false

    init(locationManager: LocationManager) {
        _viewModel = StateObject(wrappedValue: MapViewModel(locationManager: locationManager))
    }

    var body: some View {
        ZStack {
            MapDataLayer(
                region: $viewModel.region,
                routeService: container.routeService,
                vehicleService: container.vehicleService,
                showDeveloperPanel: $viewModel.showDeveloperPanel,
                onVehicleTapped: { vehicle in
                    navigationState.focusVehicleName = vehicle.name
                    navigationState.selectedTab = 2
                }
            )

            // UI overlay
            VStack {
                HStack(alignment: .top) {
                    // Settings & Developer Buttons
                    VStack(alignment: .leading) {
                        Button(action: { viewModel.showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        if isDeveloperMode {
                            Button(action: { viewModel.toggleDeveloperPanel() }) {
                                Image(systemName: "ladybug.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(Color.purple)
                                    .clipShape(Circle())
                                    .shadow(radius: 4)
                            }
                            if viewModel.showDeveloperPanel {
                                DeveloperModeView(vehicles: container.vehicleService.vehicles)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
                            }
                        }
                    }
                    .padding(.top, 60)
                    .padding(.leading, 16)
                    Spacer()
                }
                Spacer()
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
        }
        .onChange(of: navigationState.focusCoordinate?.latitude) { _, _ in
            if let coord = navigationState.focusCoordinate {
                withAnimation {
                    viewModel.region = MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                    )
                }
                navigationState.focusCoordinate = nil
            }
        }
    }
}

// Internal map layer that explicitly observes the services to force redraws
struct MapDataLayer: View {
    @Binding var region: MKCoordinateRegion
    @ObservedObject var routeService: RouteService
    @ObservedObject var vehicleService: VehicleService
    @Binding var showDeveloperPanel: Bool
    var onVehicleTapped: ((VehicleLocationData) -> Void)?
    var body: some View {
        Map(position: .constant(.region(region))) {
            // route polylines (drawn first, below everything)
            ForEach(Array(routeService.activeRoutes), id: \.key) { routeName, routeData in
                if routeData.color != "#00000000" {
                    ForEach(0..<routeData.routes.count, id: \.self) { index in
                        let coordinatePairs = routeData.routes[index]
                        let coordinates = convertCoordinates(coordinatePairs)
                        if coordinates.count >= 2 {
                            MapPolyline(coordinates: coordinates)
                                .stroke(Color(hex: routeData.color).opacity(0.6), lineWidth: 4)
                        }
                    }
                    // stops (above polylines)
                    ForEach(routeData.stops, id: \.self) { stopKey in
                        if let stop = routeData.stopDetails[stopKey], stop.coordinates.count == 2 {
                            Annotation(
                                    stop.name,
                                    coordinate: CLLocationCoordinate2D(latitude: stop.coordinates[0], longitude: stop.coordinates[1])
                                    ) {
                                StopAnnotationView(colorHex: routeData.color)
                            }
                        }
                    }
                }
            }

            // vehicle markers (drawn last, always on top)
            ForEach(vehicleService.vehicles) { vehicle in
                Annotation(vehicle.name, coordinate: vehicle.coordinate) {
                    VehicleMarkerView(
                        color: Color.forRoute(vehicle.routeName),
                        hasETAs: !vehicle.stopEtaTimes.isEmpty
                    )
                    .onTapGesture {
                        if !vehicle.stopEtaTimes.isEmpty {
                            onVehicleTapped?(vehicle)
                        }
                    }
                }
            }

            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .including([.school, .university])))
        .onTapGesture {
            if showDeveloperPanel {
                withAnimation { showDeveloperPanel = false }
            }
        }
    }
    // helper to process raw arrays into Coordinates
    func convertCoordinates(_ pairs: [[Double]]) -> [CLLocationCoordinate2D] {
        pairs.compactMap { coord -> CLLocationCoordinate2D? in
            guard coord.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1])
        }
    }
}

// subviews
struct VehicleMarkerView: View {
    let color: Color
    let hasETAs: Bool
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
                .shadow(radius: 3)
            Image(systemName: "bus.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white)
        }
    }
}

struct StopAnnotationView: View {
    let colorHex: String
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle().stroke(Color(hex: colorHex), lineWidth: 2)
                )
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 8, height: 8)
        }
    }
}

#Preview {
    MapView(locationManager: DependencyContainer.preview.locationManager)
        .environmentObject(DependencyContainer.preview)
}
