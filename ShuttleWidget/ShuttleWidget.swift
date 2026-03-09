import WidgetKit
import SwiftUI
import AppIntents

struct TargetStopIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Target Stop"
    static var description = IntentDescription("Select which stop to track.")
    @Parameter(title: "Stop", default: ShuttleStop.defaultStop)
    var stop: ShuttleStop?
}

struct ShuttleWidgetEntry: TimelineEntry {
    let date: Date
    let activeShuttles: [VehicleLocationData]
    let nextScheduledArrival: Date? /* for single stop data */
    let groupedETAs: [EtasForRoute] /* for All Stops data   */
    let targetStop: ShuttleStop
}

struct ShuttleWidgetProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> ShuttleWidgetEntry {
        ShuttleWidgetEntry(
            date: Date(),
            activeShuttles: [],
            nextScheduledArrival: Date(),
            groupedETAs: [],
            targetStop: ShuttleStop.defaultStop
        )
    }

    func snapshot(for configuration: TargetStopIntent, in context: Context) async -> ShuttleWidgetEntry {
        let stop = configuration.stop ?? ShuttleStop.defaultStop
        return ShuttleWidgetEntry(
            date: Date(),
            activeShuttles: [],
            nextScheduledArrival: nil,
            groupedETAs: [],
            targetStop: stop
        )
    }

    func timeline(for configuration: TargetStopIntent, in context: Context) async -> Timeline<ShuttleWidgetEntry> {
        let targetStop = configuration.stop ?? ShuttleStop.defaultStop
        do {
            let client = APIClient.shared

            async let locationsMap = client.fetch([String: VehicleLocationDTO].self, endpoint: .vehicleLocations)
            async let velocitiesMap = try? client.fetch([String: VehicleVelocityDTO].self, endpoint: .vehicleVelocities)
            async let etasMap = try? client.fetch([String: VehicleETADTO].self, endpoint: .vehicleEtas)
            async let routesData = try? client.fetch(ShuttleRouteData.self, endpoint: .routes)
            async let scheduleData = try? client.fetch(ScheduleData.self, endpoint: .schedule)

            let (locations, velocities, etas, routes, schedule) = try await (locationsMap, velocitiesMap, etasMap, routesData, scheduleData)
            let vehicles = VehicleDTOMerger.merge(locations: locations, velocities: velocities, etas: etas)

            var relevantShuttles: [VehicleLocationData] = []
            var groupedETAs: [EtasForRoute] = []
            var nextArrival: Date? = nil

            if targetStop.id == ShuttleStop.allStops.id {
                groupedETAs = ETAProcessor.getGroupedETAs(vehicles: vehicles, routes: routes ?? [:])
            } else {
                // relevantShuttles = vehicles /* when ETA endpoint isn't active */
                /* either heading towards the selected stop, or is currently there */
                relevantShuttles = vehicles.filter { vehicle in
                    let hasFutureEta = vehicle.soonestFutureEta(for: targetStop.lookupKeys) != nil
                    var isCurrentlyHere = false
                    if vehicle.isAtStop, let current = vehicle.currentStop {
                        isCurrentlyHere = targetStop.lookupKeys.contains(current)
                    }
                    return hasFutureEta || isCurrentlyHere
                }
                if let schedule = schedule, let routes = routes {
                    nextArrival = calculateNextScheduledArrival(for: targetStop.id, schedule: schedule, routes: routes)
                }
            }

            let entry = ShuttleWidgetEntry(
                date: Date(),
                activeShuttles: relevantShuttles,
                nextScheduledArrival: nextArrival,
                groupedETAs: groupedETAs,
                targetStop: targetStop
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } catch {
            print("FAILED WIDGET FETCH: \(error)")
            let entry = ShuttleWidgetEntry(date: Date(), activeShuttles: [], nextScheduledArrival: nil, groupedETAs: [], targetStop: targetStop)
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
                Text(entry.targetStop.id == ShuttleStop.allStops.id ? "All Routes" : "Target Stop: \(entry.targetStop.displayString)")
                    .font(.system(size: 9, weight: .bold))
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
            if entry.targetStop.id == ShuttleStop.allStops.id {
                allStopsView
            } else {
                singleStopView
            }
        }
        .padding(6)
        .containerBackground(Color(uiColor: .systemBackground), for: .widget)
    }

    private var allStopsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.groupedETAs.isEmpty {
                Text("No active shuttles.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(entry.groupedETAs) { section in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.id.capitalized + " Route")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color.forRoute(section.id))
                        ForEach(section.etas) { eta in
                            HStack {
                                Text(eta.stopName)
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(eta.etaDate.formattedTime)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                        }
                    }
                    Divider().opacity(0.5)
                }
            }
        }
    }

    private var singleStopView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(entry.activeShuttles.prefix(6)) { vehicle in
                HStack(spacing: 6) {
                    Capsule()
                        .fill(Color.forRoute(vehicle.routeName))
                        .frame(width: 4, height: 16)
                    Text(vehicle.name)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 30, alignment: .leading)
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
                    if vehicle.isAtStop && entry.targetStop.lookupKeys.contains(vehicle.currentStop ?? "") {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("Now")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                    } else if let etaStr = vehicle.soonestFutureEta(for: entry.targetStop.lookupKeys) {
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
                    Text("Next Scheduled:").font(.caption2)
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
