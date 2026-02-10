import SwiftUI

struct ETAListView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.getGroupedETAs()) { section in
                    Section {
                        ForEach(section.etas) { eta in
                            EtaRow(eta: eta, dateFormatter: viewModel.dateFormatter)
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
            .navigationTitle("Live ETAs")
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
    }
}

struct EtaRow: View {
    let eta: StopETA
    let dateFormatter: DateFormatter
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
                Text(dateFormatter.string(from: eta.etaDate))
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
