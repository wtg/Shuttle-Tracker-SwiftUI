import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var container: DependencyContainer
    @StateObject private var navigationState = NavigationState()
    @State private var scheduleVM: ScheduleViewModel?
    @State private var etaVM: ScheduleViewModel?

    var body: some View {
        TabView(selection: $navigationState.selectedTab) {
            MapView(locationManager: container.locationManager)
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(0)

            Group {
                if let vm = scheduleVM {
                    ScheduleView(viewModel: vm)
                }
            }
            .tabItem { Label("Schedule", systemImage: "clock") }
            .tag(1)

            Group {
                if let vm = etaVM {
                    ETAListView(viewModel: vm)
                }
            }
            .tabItem { Label("ETAs", systemImage: "bus") }
            .tag(2)
        }
        .environmentObject(navigationState)
        .onAppear {
            if scheduleVM == nil {
                scheduleVM = ScheduleViewModel(
                    scheduleService: container.scheduleService,
                    routeService: container.routeService,
                    vehicleService: container.vehicleService
                )
            }
            if etaVM == nil {
                etaVM = ScheduleViewModel(
                    scheduleService: container.scheduleService,
                    routeService: container.routeService,
                    vehicleService: container.vehicleService
                )
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(DependencyContainer.preview)
}
