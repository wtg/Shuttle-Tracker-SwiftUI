import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        TabView {
            MapView(locationManager: container.locationManager)
                .tabItem { Label("Map", systemImage: "map.fill") }

            ScheduleView(
                viewModel: ScheduleViewModel(
                    scheduleService: container.scheduleService,
                    routeService: container.routeService,
                    vehicleService: container.vehicleService
                )
            )
            .tabItem { Label("Schedule", systemImage: "clock") }

            ETAListView(
                viewModel: ScheduleViewModel(
                    scheduleService: container.scheduleService,
                    routeService: container.routeService,
                    vehicleService: container.vehicleService
                )
            )
            .tabItem { Label("ETAs", systemImage: "bus") }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(DependencyContainer.preview)
}
