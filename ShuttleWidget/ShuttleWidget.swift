import WidgetKit
import SwiftUI

struct ShuttleEntry: TimelineEntry {
    let date: Date
    let vehicles: [VehicleLocationData]
    let state: WidgetState
}

enum WidgetState {
    case active
    case empty
    case error(String)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ShuttleEntry {
        ShuttleEntry(date: Date(), vehicles: [], state: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShuttleEntry) -> ()) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShuttleEntry>) -> ()) {
        Task {
            let date = Date()
            var entry: ShuttleEntry

            do {
                let vehicleMap = try await API.shared.fetch(VehicleInformationMap.self, endpoint: "locations")
                let vehicles = Array(vehicleMap.values).sorted { $0.name < $1.name }
                if vehicles.isEmpty {
                    entry = ShuttleEntry(date: date, vehicles: [], state: .empty)
                } else {
                    entry = ShuttleEntry(date: date, vehicles: vehicles, state: .active)
                }
            } catch {
                entry = ShuttleEntry(date: date, vehicles: [], state: .error("Connection Failed"))
            }

            // ios may be controlling the refresh rate automatically
            let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: date)!
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))

            completion(timeline)
        }
    }
}

struct ShuttleWidgetEntryView : View {
    var entry: Provider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Campus Shuttles")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            switch entry.state {
            case .error(let message):
                ContentUnavailableView(message, systemImage: "exclamationmark.triangle").font(.caption)
            case .empty:
                ContentUnavailableView("No Shuttles Active", systemImage: "moon.zzz").font(.caption)
            case .active: // list of buses
                VStack(spacing: 8) {
                    ForEach(entry.vehicles.prefix(3), id: \.name) { vehicle in
                        HStack {
                            Circle()
                                .fill(vehicle.speedMph > 0 ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading) {
                                Text(vehicle.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .lineLimit(1)
                                Text(vehicle.formattedLocation ?? "unknown_route")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(vehicle.speedMph > 0 ? "\(Int(vehicle.speedMph)) mph" : "Stopped")
                                .font(.system(size: 10, design: .monospaced))
                                .padding(4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(for: .widget) {
            Color(UIColor.systemBackground)
        }
    }
}

struct ShuttleWidget: Widget {
    let kind: String = "ShuttleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ShuttleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Live Shuttles")
        .description("Track active shuttles.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

let previewVehicles = [
    VehicleLocationData(
        addressId: nil, addressName: nil, assetType: "Bus", formattedLocation: "Troy, NY",
        gatewayModel: "", gatewaySerial: "", headingDegrees: 0, isEcuSpeed: false,
        latitude: 42.7, licensePlate: nil, longitude: -73.6, name: "Shuttle 1", polylineIndex: 0,
        routeName: "WEST", speedMph: 12, timestamp: "", vin: ""
    ),
    VehicleLocationData(
        addressId: nil, addressName: nil, assetType: "Bus", formattedLocation: "Troy, NY",
        gatewayModel: "", gatewaySerial: "", headingDegrees: 0, isEcuSpeed: false,
        latitude: 42.7, licensePlate: nil, longitude: -73.6, name: "Shuttle 2", polylineIndex: 0,
        routeName: "West", speedMph: 1, timestamp: "", vin: ""
    ),
    VehicleLocationData(
        addressId: nil, addressName: nil, assetType: "Bus", formattedLocation: "Troy, NY",
        gatewayModel: "", gatewaySerial: "", headingDegrees: 0, isEcuSpeed: false,
        latitude: 42.7, licensePlate: nil, longitude: -73.6, name: "Shuttle 3", polylineIndex: 0,
        routeName: "NORTH", speedMph: 0, timestamp: "", vin: ""
    )
]

/*
#Preview(as: .systemSmall) {
    ShuttleWidget()
} timeline: {
    ShuttleEntry(date: .now, vehicles: [], state: .active)
}
 */

#Preview(as: .systemMedium) {
    ShuttleWidget()
} timeline: {
    //ShuttleEntry(date: .now, vehicles: [], state: .active)
    ShuttleEntry(date: .now, vehicles: previewVehicles, state: .active)
}

/*
#Preview(as: .systemLarge) {
    ShuttleWidget()
} timeline: {
    ShuttleEntry(date: .now, vehicles: [], state: .active)
}
 */
