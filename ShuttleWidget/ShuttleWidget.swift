import WidgetKit
import SwiftUI
import AppIntents

struct TargetStopIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Widget Settings"
    static var description = IntentDescription("Select which stop to track and customize the theme.")

    @Parameter(title: "Stop", default: ShuttleStop.defaultStop)
    var stop: ShuttleStop?

    @Parameter(title: "Theme", default: .system)
    var theme: WidgetTheme
}

struct ShuttleWidgetEntry: TimelineEntry {
    let date: Date
    let activeShuttles: [VehicleLocationData]
    let nextScheduledArrival: Date? /* for single stop data */
    let groupedETAs: [EtasForRoute] /* for All Stops data   */
    let targetStop: ShuttleStop
    let stopNames: [String: String]
    let theme: WidgetTheme /* from app intents */
}

struct ShuttleWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ShuttleWidgetEntry {
        ShuttleWidgetEntry(
            date: Date(),
            activeShuttles: [],
            nextScheduledArrival: Date(),
            groupedETAs: [],
            targetStop: ShuttleStop.defaultStop,
            stopNames: [:],
            theme: .system
        )
    }

    func snapshot(for configuration: TargetStopIntent, in context: Context) async -> ShuttleWidgetEntry {
        let stop = configuration.stop ?? ShuttleStop.defaultStop
        return ShuttleWidgetEntry(
            date: Date(),
            activeShuttles: [],
            nextScheduledArrival: nil,
            groupedETAs: [],
            targetStop: stop,
            stopNames: [:],
            theme: .system
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

            var validStopNames: [String: String] = [:]
            if let routesData = routes {
                for route in routesData.values {
                    for (key, details) in route.stopDetails {
                        validStopNames[key] = details.name
                    }
                }
            }

            var relevantShuttles: [VehicleLocationData] = []
            var groupedETAs: [EtasForRoute] = []
            var nextArrival: Date? = nil

            if targetStop.id == ShuttleStop.allStops.id {
                groupedETAs = ETAProcessor.getGroupedETAs(vehicles: vehicles, routes: routes ?? [:])
                relevantShuttles = vehicles
            } else {
                // relevantShuttles = vehicles /* when ETA endpoint isn't active */

                /* either heading towards the selected stop, or is currently there */
                relevantShuttles = vehicles.filter { vehicle in
                    /* filter to only the specific route if this stop is non-disjoint between routes (student union) */
                    if let requiredRoute = targetStop.routeKey, vehicle.routeName != requiredRoute {
                        return false
                    }
                    let hasFutureEta = vehicle.soonestFutureEta(for: targetStop.lookupKeys) != nil
                    var isCurrentlyHere = false
                    if vehicle.isAtStop, let current = vehicle.currentStop {
                        isCurrentlyHere = targetStop.lookupKeys.contains(current)
                    }
                    return hasFutureEta || isCurrentlyHere
                }
                if let schedule = schedule, let routes = routes {
                    nextArrival = calculateNextScheduledArrival(for: targetStop.stopKey, routeKey: targetStop.routeKey, schedule: schedule, routes: routes)
                }
            }

            let entry = ShuttleWidgetEntry(
                date: Date(),
                activeShuttles: relevantShuttles,
                nextScheduledArrival: nextArrival,
                groupedETAs: groupedETAs,
                targetStop: targetStop,
                stopNames: validStopNames,
                theme: configuration.theme
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } catch {
            print("FAILED WIDGET FETCH: \(error)")
            let entry = ShuttleWidgetEntry(date: Date(), activeShuttles: [], nextScheduledArrival: nil, groupedETAs: [], targetStop: targetStop, stopNames: [:], theme: configuration.theme)
            let retryDate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
            return Timeline(entries: [entry], policy: .after(retryDate))
        }
    }
}

private func calculateNextScheduledArrival(for targetStopKey: String, routeKey: String?, schedule: ScheduleData, routes: ShuttleRouteData) -> Date? {
    let calendar = Calendar.current
    let now = Date()
    let weekday = calendar.component(.weekday, from: now)

    print("Finding next scheduled for \(targetStopKey) (route=\(routeKey ?? "X")))");

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

            if routeKey != nil && routeName != routeKey { continue; }

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

/* setup color theme/palette for environment injection to simplify constructors */
private struct PaletteKey: EnvironmentKey {
    static let defaultValue: ColorPalette = WidgetTheme.system.palette
}
extension EnvironmentValues {
    var palette: ColorPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

struct ShuttleWidgetEntryView: View {
    var entry: ShuttleWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallShuttleWidgetView(entry: entry)
            default:
                MediumLargeShuttleWidgetView(entry: entry)
            }
        }
        .environment(\.palette, entry.theme.palette)
        .foregroundStyle(entry.theme.palette.primaryText)
        .containerBackground(entry.theme.palette.background, for: .widget)
        .environment(\.colorScheme, entry.theme.colorScheme ?? .light)
    }
}

struct SmallShuttleWidgetView: View {
    var entry: ShuttleWidgetProvider.Entry
    @Environment(\.palette) var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.targetStop.id == ShuttleStop.allStops.id ? "All Routes" : entry.targetStop.displayString)
                .font(.system(size: 13, weight: .heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Rectangle().fill(palette.divider).frame(height: 1)
            if entry.targetStop.id == ShuttleStop.allStops.id {
                smallAllStopsView
            } else {
                smallSingleStopView
            }
        }
        .padding(2)
    }

    @ViewBuilder
    private var smallAllStopsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            /* same vehicle filtering as in medium/large widget */
            let stoppedVehicles = entry.activeShuttles.filter { vehicle in
                guard vehicle.isAtStop, let currentStop = vehicle.currentStop else { return false }
                return entry.stopNames.keys.contains(currentStop)
            }
            if let firstStopped = stoppedVehicles.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(firstStopped.name) at \(entry.stopNames[firstStopped.currentStop ?? ""] ?? "Stop")")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.forRoute(firstStopped.routeName))
                        .lineLimit(2)
                    Text("Now")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundStyle(palette.highlight)
                }
            } else if let firstGroup = entry.groupedETAs.first, let firstEta = firstGroup.etas.first {
                VStack(alignment: .leading, spacing: 2) {
                    Text(firstGroup.id.capitalized)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.forRoute(firstGroup.id))
                    Text(firstEta.stopName)
                        .font(.system(size: 10))
                        .lineLimit(1)
                    Text(firstEta.etaDate.formattedTime)
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                }
            } else {
                Text("No ETA predictions available.")
                    .font(.caption2)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var smallSingleStopView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let nextVehicle = entry.activeShuttles.first {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Capsule()
                            .fill(Color.forRoute(nextVehicle.routeName))
                            .frame(width: 3, height: 12)
                        Text(nextVehicle.name)
                            .font(.system(size: 11, weight: .bold))
                    }
                    if nextVehicle.isAtStop && entry.targetStop.lookupKeys.contains(nextVehicle.currentStop ?? "") {
                        Text("Now")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundStyle(palette.highlight)
                    } else if let etaStr = nextVehicle.soonestFutureEta(for: entry.targetStop.lookupKeys) {
                        Text(etaStr.formattedTime)
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                    } else {
                        Text("Moving")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(palette.highlight)
                    }
                }
            } else {
                Text("No ETA")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text("Next Sched:")
                    .font(.system(size: 9))
                    .foregroundStyle(palette.secondaryText)
                if let next = entry.nextScheduledArrival {
                    Text(next, style: .time)
                        .font(.system(size: 11, weight: .bold))
                } else {
                    Text("None")
                        .font(.system(size: 11, weight: .bold))
                }
            }
        }
    }
}

struct MediumLargeShuttleWidgetView: View {
    var entry: ShuttleWidgetProvider.Entry
    @Environment(\.palette) var palette

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
                .foregroundStyle(palette.secondaryText)
            }

            Rectangle().fill(palette.divider).frame(height: 1)

            if entry.targetStop.id == ShuttleStop.allStops.id {
                allStopsView
            } else {
                singleStopView
            }
        }
        .padding(6)
    }

    private var allStopsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            /* including a list of stops that shuttles are at is particularly helpful
                because the velocities api seems to be more reliable than the ETAs
                api which often sends outdated ETA times. */
            let stoppedVehicles = entry.activeShuttles.filter { vehicle in
                guard vehicle.isAtStop, let currentStop = vehicle.currentStop else { return false }
                return entry.stopNames.keys.contains(currentStop)
            }
            if !stoppedVehicles.isEmpty {
                ForEach(stoppedVehicles) { vehicle in
                    HStack {
                        Text(vehicle.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.forRoute(vehicle.routeName))

                        Text("at")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.secondaryText)

                        Text(vehicle.currentStop?.capitalized ?? "Unknown")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)

                        Spacer()

                        Text("Now")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.highlight)
                    }
                }
                Rectangle().fill(palette.divider).frame(height: 1)
            }

            if entry.groupedETAs.isEmpty {
                Text("No ETA predictions available.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
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
                    Rectangle().fill(palette.divider).frame(height: 1)
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
                                .foregroundStyle(palette.alert)
                        } else {
                            Text("MOVING")
                                .foregroundStyle(palette.highlight)
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
                                .foregroundStyle(palette.highlight)
                        }
                    } else if let etaStr = vehicle.soonestFutureEta(for: entry.targetStop.lookupKeys) {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("ETA")
                                .font(.system(size: 8))
                                .foregroundStyle(palette.secondaryText)
                            Text(etaStr.formattedTime)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                    } else {
                        Text("No ETA")
                            .font(.system(size: 9))
                            .foregroundStyle(palette.secondaryText)
                    }
                }
                .padding(.vertical, 2)
                Rectangle().fill(palette.divider).frame(height: 1)
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
                            .foregroundStyle(palette.secondaryText)
                    }
                }
            .foregroundStyle(palette.secondaryText)
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
        .description("Shuttle Tracker Widget")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
