import SwiftUI
import MapKit

struct ETAListView: View {
    @ObservedObject var viewModel: ScheduleViewModel
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var navigationState: NavigationState

    init(viewModel: ScheduleViewModel) {
        _viewModel = ObservedObject(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("ETAs")
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 16)

            Text("ETAs are subject to change and not guaranteed. For detailed information, please check the map.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List {
                ForEach(viewModel.getGroupedETAs()) { section in
                    Section {
                        ForEach(section.etas) { eta in
                            EtaRow(eta: eta)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    navigateToStop(eta: eta)
                                }
                        }
                    } header: {
                        HStack {
                            Text(section.id.capitalized + " Route")
                                .font(.headline)
                                .foregroundStyle(Color.forRoute(section.id))
                            Spacer()
                            Text("\(section.etas.count) stops")
                                .font(.caption)
                                .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                viewModel.loadData()
            }
            .overlay {
                if viewModel.getGroupedETAs().isEmpty {
                    ContentUnavailableView(
                        "No Active Shuttles",
                        systemImage: "bus.doubledecker.fill",
                        description: Text("Shuttles are either offline or have no upcoming stops.")
                    )
                }
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    private func navigateToStop(eta: StopETA) {
        if let route = container.routeService.getRoute(named: eta.routeName),
           let stop = route.stopDetails[eta.stopKey],
           stop.coordinates.count == 2 {
            navigationState.focusCoordinate = CLLocationCoordinate2D(
                latitude: stop.coordinates[0],
                longitude: stop.coordinates[1]
            )
            navigationState.selectedTab = 0
        }
    }
}

struct EtaRow: View {
    let eta: StopETA
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(eta.stopName)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Image(systemName: "bus.fill")
                        .font(.caption2)
                    Text(eta.vehicleName)
                        .font(.caption)
                        .bold()
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(eta.etaDate.formattedTime)
                    .font(.body.monospacedDigit())
                    .fontWeight(.bold)
                    .foregroundStyle(Color.forRoute(eta.routeName))
                Text(calculateTimeRemaining(to: eta.etaDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
    private func calculateTimeRemaining(to date: Date) -> String {
        let diff = Int(date.timeIntervalSinceNow / 60)
        if diff <= 0 { return "Now" }
        return "\(diff) min"
    }
}
