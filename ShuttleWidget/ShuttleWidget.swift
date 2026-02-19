import WidgetKit
import SwiftUI

struct ShuttleWidgetEntry: TimelineEntry {
    let date: Date
    let activeShuttles: [VehicleLocationData]
}

struct ShuttleWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShuttleWidgetEntry {
        ShuttleWidgetEntry(date: Date(), activeShuttles: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (ShuttleWidgetEntry) -> ()) {
        let entry = ShuttleWidgetEntry(date: Date(), activeShuttles: [])
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShuttleWidgetEntry>) -> ()) {
        Task {
            do {
                let client = APIClient.shared
                async let locationsMap = client.fetch([String: VehicleLocationDTO].self, endpoint: .vehicleLocations)
                async let velocitiesMap = try? client.fetch([String: VehicleVelocityDTO].self, endpoint: .vehicleVelocities)

                let (locations, velocities) = try await (locationsMap, velocitiesMap)
                let vehicles = VehicleDTOMerger.merge(locations: locations, velocities: velocities)

                let entry = ShuttleWidgetEntry(date: Date(), activeShuttles: vehicles)
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            } catch {
                let entry = ShuttleWidgetEntry(date: Date(), activeShuttles: [])
                let retryDate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(retryDate))
                completion(timeline)
            }
        }
    }
}

struct ShuttleWidgetEntryView: View {
    var entry: ShuttleWidgetProvider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Image(systemName: "bus.fill")
                Text("Active Shuttles: \(entry.activeShuttles.count)")
                    .font(.headline)
            }
            Divider()
            if entry.activeShuttles.isEmpty {
                Text("No shuttles running right now.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.activeShuttles.prefix(2)) { vehicle in
                    HStack {
                        Circle()
                            .fill(Color.forRoute(vehicle.routeName))
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading) {
                            Text(vehicle.name)
                                .font(.subheadline)
                                .bold()
                            Text(vehicle.formattedLocation)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(vehicle.speedMph) mph")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding()
        .containerBackground(Color(uiColor: .systemBackground), for: .widget)
    }
}

@main
struct ShuttleWidget: Widget {
    let kind: String = "ShuttleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShuttleWidgetProvider()) { entry in
            ShuttleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Shuttle Tracker")
        .description("shuttle tracker widget")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
