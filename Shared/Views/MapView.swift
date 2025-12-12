import MapKit
import SwiftUI

struct MapView: View {
  @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
  @State private var showOnboarding = false

  @State private var showSheet = false
  @State private var showSettings = false
  @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
  @State private var showDeveloperPanel = false

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
          if routeData.color != "#00000000" {
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
                      .frame(width: 16, height: 16)
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

        UserAnnotation()
      }

      // UI Overlay
      VStack {
        HStack(alignment: .top) {
          if isDeveloperMode {
            VStack(alignment: .leading) {
              Button(action: {
                withAnimation {
                  showDeveloperPanel.toggle()
                }
              }) {
                Image(systemName: "ladybug.fill")
                  .font(.system(size: 16))
                  .foregroundStyle(.white)
                  .padding(12)
                  .background(Color.purple)
                  .clipShape(Circle())
                  .shadow(radius: 4)
              }

              if showDeveloperPanel {
                DeveloperModeView(vehicles: vehicleLocations)
                  .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .topLeading)))
              }
            }
            .padding(.top, 20)
            .padding(.leading, 16)
          }

          Spacer()
          Button(action: {
            showSettings = true
          }) {
            Image(systemName: "gearshape.fill")
              .font(.system(size: 16))
              .foregroundStyle(.primary)
              .padding()
              .background(.ultraThinMaterial)
              .clipShape(Circle())
              .shadow(radius: 4)
          }
          .padding(.top, 20)
          .padding(.trailing, 16)
        }
        Spacer()
      }

      ScheduleAndETA()
    }
    .sheet(isPresented: $showSettings) {
      SettingsView()
    }
    .onAppear {
      fetchLocations()
      fetchRoutes()

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
        Text(
          "We are going to ask for your location to show on the map. Your location helps us center the map and calculate accurate ETAs for stops near you."
        )
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
        let locations = try await API.shared.fetch(
          VehicleInformationMap.self, endpoint: "locations")
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
