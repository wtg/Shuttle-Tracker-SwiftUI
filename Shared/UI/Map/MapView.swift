import SwiftUI

struct MapView: View {
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        VStack(spacing: 20) {
            Text("data test")
                .font(.largeTitle)
            RouteDebugView(service: container.routeService)
            VehicleDebugView(service: container.vehicleService)
        }
        .onAppear {
            print("MapView appeared.")
        }
    }
}

struct RouteDebugView: View {
    @ObservedObject var service: RouteService
    var body: some View {
        VStack {
            if service.isLoaded {
                Text("Routes Loaded: \(service.activeRoutes.count)")
                    .foregroundColor(.green)
                    .bold()
            } else {
                Text("Loading Routes...")
                    .foregroundColor(.orange)
            }
        }
    }
}

struct VehicleDebugView: View {
    @ObservedObject var service: VehicleService
    var body: some View {
        VStack {
            Text("Vehicles Found: \(service.vehicles.count)")
                .font(.title2)
                .bold()
            ForEach(service.vehicles) { vehicle in
                Text("Bus \(vehicle.name) @ \(String(format: "%.4f", vehicle.latitude))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
}
