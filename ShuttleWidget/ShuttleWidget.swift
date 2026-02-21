import WidgetKit
import SwiftUI
import AppIntents

let defaultTargetKey = "STUDENT_UNION"
let defaultTargetDisplay = "Student Union"

struct TargetStopIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Target Stop"
    static var description = IntentDescription("Select which stop to track.")
    @Parameter(title: "Stop", default: ShuttleStop(id: defaultTargetKey, displayString: defaultTargetDisplay))
    var stop: ShuttleStop?
}

struct ShuttleWidgetEntry: TimelineEntry {
    let date: Date
    let activeShuttles: [VehicleLocationData]
    let nextScheduledArrival: Date?
    let targetStopKey: String
    let targetStopName: String
}

struct ShuttleWidgetProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> ShuttleWidgetEntry {
        ShuttleWidgetEntry(
            date: Date(),
            activeShuttles: [],
            nextScheduledArrival: Date(),
            targetStopKey: defaultTargetKey,
            targetStopName: defaultTargetDisplay
        )
    }

    func snapshot(for configuration: TargetStopIntent, in context: Context) async -> ShuttleWidgetEntry {
        let stopKey = configuration.stop?.id ?? defaultTargetKey
        let stopName = configuration.stop?.displayString ?? defaultTargetDisplay
        return ShuttleWidgetEntry(
            date: Date(),
            activeShuttles: [],
            nextScheduledArrival: nil,
            targetStopKey: stopKey,
            targetStopName: stopName
        )
    }

    func timeline(for configuration: TargetStopIntent, in context: Context) async -> Timeline<ShuttleWidgetEntry> {
        let targetStopKey = configuration.stop?.id ?? defaultTargetKey
        let targetStopName = configuration.stop?.displayString ?? defaultTargetDisplay

        do {
            let client = APIClient.shared

            async let locationsMap = client.fetch([String: VehicleLocationDTO].self, endpoint: .vehicleLocations)
            async let velocitiesMap = try? client.fetch([String: VehicleVelocityDTO].self, endpoint: .vehicleVelocities)
            async let etasMap = try? client.fetch([String: VehicleETADTO].self, endpoint: .vehicleEtas)
            async let routesData = try? client.fetch(ShuttleRouteData.self, endpoint: .routes)
            async let scheduleData = try? client.fetch(ScheduleData.self, endpoint: .schedule)

            let (locations, velocities, etas, routes, schedule) = try await (locationsMap, velocitiesMap, etasMap, routesData, scheduleData)
            let vehicles = VehicleDTOMerger.merge(locations: locations, velocities: velocities, etas: etas)
            // let relevantShuttles = vehicles.filter { $0.stopEtaTimes.keys.contains(targetStopKey) }
            let relevantShuttles = vehicles /* ETA endpoint isn't active, so simply use this for now */

            var nextArrival: Date? = nil
            if let schedule = schedule, let routes = routes {
                nextArrival = calculateNextScheduledArrival(for: targetStopKey, schedule: schedule, routes: routes)
            }

            let entry = ShuttleWidgetEntry(
                date: Date(),
                activeShuttles: relevantShuttles,
                nextScheduledArrival: nextArrival,
                targetStopKey: targetStopKey,
                targetStopName: targetStopName
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } catch {
            print("FAILED WIDGET FETCH: \(error)")
            let entry = ShuttleWidgetEntry(date: Date(), activeShuttles: [], nextScheduledArrival: nil, targetStopKey: targetStopKey, targetStopName: targetStopName)
            let retryDate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
            return Timeline(entries: [entry], policy: .after(retryDate))
        }
    }
}

private func calculateNextScheduledArrival(for targetStopKey: String, schedule: ScheduleData, routes: ShuttleRouteData) -> Date? {
    let calendar = Calendar.current
    let now = Date()
    let weekday = calendar.component(.weekday, from: now)

    let scheduleMap: [String: [[String]]]
    if weekday == 1 { scheduleMap = schedule.sundaySchedule }
    else if weekday == 7 { scheduleMap = schedule.saturdaySchedule }
    else { scheduleMap = schedule.weekday }

    var nextDate: Date? = nil
    for (_, times) in scheduleMap {
        for timePair in times {
            guard timePair.count >= 2 else { continue }
            let timeStr = timePair[0]
            let routeName = timePair[1]

            guard let baseDate = timeStr.simpleTimeToDate else { continue }
            let baseComponents = calendar.dateComponents([.hour, .minute], from: baseDate)
            guard let todayBaseDate = calendar.date(bySettingHour: baseComponents.hour ?? 0, minute: baseComponents.minute ?? 0, second: 0, of: now) else { continue }

            guard let routeData = routes[routeName], let stopDetails = routeData.stopDetails[targetStopKey] else { continue }
            let arrivalDate = calendar.date(byAdding: .minute, value: stopDetails.offset, to: todayBaseDate)!

            // hour wrapping
            var validArrivalDate = arrivalDate
            if calendar.component(.hour, from: arrivalDate) < 4 && calendar.component(.hour, from: now) >= 18 {
                validArrivalDate = calendar.date(byAdding: .day, value: 1, to: arrivalDate)!
            }

            // closest future time
            if validArrivalDate > now {
                if nextDate == nil || validArrivalDate < nextDate! {
                    nextDate = validArrivalDate
                }
            }
        }
    }
    return nextDate
}

struct ShuttleWidgetEntryView: View {
    var entry: ShuttleWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom) {
                Text("target stop: \(entry.targetStopName)")
                    .font(.system(size: 9, weight: .bold))
                    .bold()
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 4) {
                    Text("Last updated:")
                    Text(entry.date, style: .time)
                }
                .font(.system(size:10, weight: .bold))
                .foregroundStyle(.secondary)
            }
            Divider()
            /* NOTE: the isAtStop, ETA, routeName, etc are not active endpoints so
               some displayed data is wrong, but should work once the endpoints are restored */
            ForEach(entry.activeShuttles.prefix(6)) { vehicle in
                HStack(spacing: 6) {
                    Capsule()
                        .fill(Color.forRoute(vehicle.routeName))
                        .frame(width: 4, height: 16)
                    Text(vehicle.name)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 45, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(vehicle.speedMph, specifier: "%.1f") mph")
                        if vehicle.isAtStop {
                            Text("AT: \(vehicle.currentStop?.prefix(6) ?? "?")..")
                                .foregroundStyle(.red)
                        } else {
                            Text("MOVING")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.system(size: 9))
                    .frame(width: 60, alignment: .leading)
                    Text(vehicle.formattedLocation).font(.system(size: 8))
                    Spacer(minLength: 0)
                    if let etaStr = vehicle.stopEtaTimes[entry.targetStopKey] {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("ETA")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text(etaStr.formattedTime)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                    } else {
                        Text("NO ETA")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                Divider().opacity(0.5)
            }
            Spacer(minLength: 0)
            HStack {
                Text("Next Scheduled:")
                    .font(.caption2)
                Spacer()
                if let next = entry.nextScheduledArrival {
                    Text(next, style: .time)
                        .font(.caption.bold())
                } else {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding(6)
        .containerBackground(Color(uiColor: .systemBackground), for: .widget)
    }
}

@main
struct ShuttleWidget: Widget {
    let kind: String = "ShuttleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TargetStopIntent.self, provider: ShuttleWidgetProvider()) { entry in
            ShuttleWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Shuttle Tracker")
        .description("shuttle tracker widget")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
