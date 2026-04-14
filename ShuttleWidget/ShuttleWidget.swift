import WidgetKit
import SwiftUI
import AppIntents

struct ToggleStopModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Stop Mode"
    static var description = IntentDescription("Switches the widget between All Stops and your favorite stop.")

    @Parameter(title: "Configured Stop ID")
    var stopId: String
    init() { self.stopId = "" }
    init(stopId: String) { self.stopId = stopId }

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        let key = "isShowingAllStops_\(stopId)"
        let isShowingAllStops = defaults.bool(forKey: key)
        defaults.set(!isShowingAllStops, forKey: key)
        return .result() /* this triggers a widget timeline reload */
    }
}

struct RefreshShuttleDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Shuttle Data"
    init() {}
    func perform() async throws -> some IntentResult {
        return .result() /* triggers widget reload */
    }
}

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
    let configuredStop: ShuttleStop
    let stopNames: [String: String]
    let theme: WidgetTheme /* from app intents */
    let isMockDataEnabled: Bool
}

struct ToggleWidgetMockDataIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Widget Mock Data"

    @Parameter(title: "Enable Mock Data")
    var enable: Bool
    init() { self.enable = false }
    init(enable: Bool) { self.enable = enable }

    func perform() async throws -> some IntentResult {
        // Explicitly set the value rather than reading and toggling
        UserDefaults.standard.set(enable, forKey: "widget_useMockData")
        return .result() /* triggers widget reload */
    }
}

struct ShuttleWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ShuttleWidgetEntry {
        ShuttleWidgetEntry(
            date: Date(),
            activeShuttles: [],
            nextScheduledArrival: Date(),
            groupedETAs: [],
            targetStop: ShuttleStop.defaultStop,
            configuredStop: ShuttleStop.defaultStop,
            stopNames: [:],
            theme: .system,
            isMockDataEnabled: true
        )
    }

    // we can use the mock generator to show sample data
    func snapshot(for configuration: TargetStopIntent, in context: Context) async -> ShuttleWidgetEntry {
        let stop = configuration.stop ?? ShuttleStop.defaultStop
        let mockVehicles = MockEndpointDataGenerator.generateMergedSimulation(count: 3)
        let mockNextArrival = Calendar.current.date(byAdding: .minute, value: 15, to: Date())
        return ShuttleWidgetEntry(
            date: Date(),
            activeShuttles: mockVehicles,
            nextScheduledArrival: mockNextArrival,
            groupedETAs: [],
            targetStop: stop,
            configuredStop: stop,
            stopNames: [
                "STUDENT_UNION": "Student Union",
                "ECAV": "ECAV",
                "CITY_STATION": "City Station",
                "BLITMAN": "Blitman",
                "BARH": "BARH"
            ],
            theme: configuration.theme,
            isMockDataEnabled: true
        )
    }

    func timeline(for configuration: TargetStopIntent, in context: Context) async -> Timeline<ShuttleWidgetEntry> {
        let configuredStop = configuration.stop ?? ShuttleStop.defaultStop
        let defKey = "isShowingAllStops_\(configuredStop.id)"
        let isShowingAllStops = UserDefaults.standard.bool(forKey: defKey)

        var targetStop = configuredStop
        if isShowingAllStops {
            targetStop = ShuttleStop.allStops
        }

        do {
            let client = APIClient.shared

            // load the static endpoints
            async let routesData = try? client.fetch(ShuttleRouteData.self, endpoint: .routes)
            async let scheduleData = try? client.fetch(ScheduleData.self, endpoint: .schedule)
            let (routes, schedule) = await (routesData, scheduleData)

            #if DEBUG
            let useMockData = UserDefaults.standard.bool(forKey: "widget_useMockData")
            #else
            let useMockData = false
            #endif

            let vehicles: [VehicleLocationData]

            if useMockData {
                vehicles = MockEndpointDataGenerator.generateMergedSimulation(count: 4)
            } else {
                async let locationsMap = client.fetch([String: VehicleLocationDTO].self, endpoint: .vehicleLocations)
                async let velocitiesMap = try? client.fetch([String: VehicleVelocityDTO].self, endpoint: .vehicleVelocities)
                async let etasMap = try? client.fetch([String: VehicleETADTO].self, endpoint: .vehicleEtas)

                let (locations, velocities, etas) = try await (locationsMap, velocitiesMap, etasMap)
                vehicles = VehicleDTOMerger.merge(locations: locations, velocities: velocities, etas: etas)
            }

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
                    nextArrival = ScheduleCalculator.nextScheduledArrival(for: targetStop.stopKey, routeKey: targetStop.routeKey, schedule: schedule, routes: routes)
                }
            }

            let entry = ShuttleWidgetEntry(
                date: Date(),
                activeShuttles: relevantShuttles,
                nextScheduledArrival: nextArrival,
                groupedETAs: groupedETAs,
                targetStop: targetStop,
                configuredStop: configuredStop,
                stopNames: validStopNames,
                theme: configuration.theme,
                isMockDataEnabled: useMockData
            )
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            return Timeline(entries: [entry], policy: .after(nextUpdate))
        } catch {
            print("FAILED WIDGET FETCH: \(error)")
            let entry = ShuttleWidgetEntry(date: Date(), activeShuttles: [], nextScheduledArrival: nil, groupedETAs: [], targetStop: targetStop, configuredStop: configuredStop, stopNames: [:], theme: configuration.theme, isMockDataEnabled: false)
            let retryDate = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
            return Timeline(entries: [entry], policy: .after(retryDate))
        }
    }
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
            case .accessoryRectangular:
                RectangularShuttleWidgetView(entry: entry)
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

struct RectangularShuttleWidgetView: View {
    var entry: ShuttleWidgetProvider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.targetStop.displayString) /* line 1: stop */
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if entry.targetStop.id == ShuttleStop.allStops.id {
                Text("Select a specific stop").font(.system(size: 10, weight: .heavy))
            } else {
                /* line 2: eta, now, or blank */
                if let firstVehicle = entry.activeShuttles.first {
                    if firstVehicle.isAtStop && entry.targetStop.lookupKeys.contains(firstVehicle.currentStop ?? "") {
                        Text("Now").font(.subheadline)
                    } else if let etaStr = firstVehicle.soonestFutureEta(for: entry.targetStop.lookupKeys), let etaDate = etaStr.isoTimeToDate {
                        Text(etaDate.formattedTimeWithSeconds).font(.system(size: 10, weight: .heavy))
                    } else {
                        Text(" ").font(.system(size: 10, weight: .heavy))
                    }
                } else {
                    Text(" ").font(.system(size: 10, weight: .heavy))
                }

                /* line 3: schedule */
                if let next = entry.nextScheduledArrival {
                    Text("Schedule: \(next, style: .time)").font(.caption)
                } else {
                    Text("Schedule: None").font(.caption)
                }
            }
        }
    }
}

struct SmallShuttleWidgetView: View {
    var entry: ShuttleWidgetProvider.Entry
    @Environment(\.palette) var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(entry.targetStop.displayString)
                    .font(.system(size: 11, weight: .heavy))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer()

                /* buttons */
                HStack(spacing: 8) {

                    #if DEBUG
                    Button(intent: ToggleWidgetMockDataIntent(enable: !entry.isMockDataEnabled)) {
                        Image(systemName: entry.isMockDataEnabled ? "hammer.fill" : "hammer")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(entry.isMockDataEnabled ? .purple : palette.secondaryText)
                    #endif

                    Button(intent: RefreshShuttleDataIntent()) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    Button(intent: ToggleStopModeIntent(stopId: entry.configuredStop.id)) {
                        Image(systemName: entry.targetStop.id == ShuttleStop.allStops.id ? "star.fill" : "list.bullet")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(palette.secondaryText)
                .font(.system(size: 14))
            }

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
        VStack(alignment: .leading, spacing: 4) {
            /* same vehicle filtering as in medium/large widget */
            let stoppedVehicles = entry.activeShuttles.filter { vehicle in
                guard vehicle.isAtStop, let currentStop = vehicle.currentStop else { return false }
                return entry.stopNames.keys.contains(currentStop)
            }
            if !stoppedVehicles.isEmpty {
                ForEach(stoppedVehicles.prefix(2)) { vehicle in
                    HStack {
                        Text("\(entry.stopNames[vehicle.currentStop ?? ""] ?? "Stop")")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.forRoute(vehicle.routeName))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text("Now")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundStyle(palette.highlight)
                    }
                }
            }
            if entry.groupedETAs.isEmpty {
                Text("No ETA predictions available.")
                    .font(.system(size: 8))
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(entry.groupedETAs) { section in
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(section.etas.prefix(2)) { eta in
                            HStack {
                                Text(eta.stopName)
                                    .font(.system(size: 9, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(eta.etaDate.formattedTime)
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var smallSingleStopView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !entry.activeShuttles.isEmpty {
                ForEach(entry.activeShuttles.prefix(4)) { vehicle in
                    HStack(spacing: 4) {
                        Capsule()
                            .fill(Color.forRoute(vehicle.routeName))
                            .frame(width: 3, height: 12)
                        Text(vehicle.name)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        if vehicle.isAtStop && entry.targetStop.lookupKeys.contains(vehicle.currentStop ?? "") {
                            Text("Now")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(palette.highlight)
                        } else if let etaStr = vehicle.soonestFutureEta(for: entry.targetStop.lookupKeys) {
                            Text(etaStr.formattedTime)
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        } else {
                            Text("Moving")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(palette.highlight)
                        }
                    }
                }
            } else {
                Text("No ETA")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
            HStack {
                Text("Schedule:")
                    .font(.system(size: 13))
                if let next = entry.nextScheduledArrival {
                    Text(next, style: .time).font(.system(size: 12, weight: .bold))
                } else {
                    Text("None").font(.system(size: 12, weight: .bold))
                }
            }
        }
    }
}

struct MediumLargeShuttleWidgetView: View {
    var entry: ShuttleWidgetProvider.Entry
    @Environment(\.palette) var palette
    @Environment(\.widgetFamily) var family

    private var maxStoppedVehicles: Int { family == .systemLarge ? 4 : 2 }
    private var maxETAsPerRoute: Int { family == .systemLarge ? 5 : 2 }
    private var maxSingleStopVehicles: Int { family == .systemLarge ? 6 : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom) {
                Text(entry.targetStop.displayString)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 7) {
                    Text(entry.date, style: .time)

                    /* buttons */
                    #if DEBUG
                    Button(intent: ToggleWidgetMockDataIntent(enable: !entry.isMockDataEnabled)) {
                        Image(systemName: entry.isMockDataEnabled ? "hammer.fill" : "hammer")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(entry.isMockDataEnabled ? .purple : palette.secondaryText)
                    #endif

                    Button(intent: RefreshShuttleDataIntent()) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    Button(intent: ToggleStopModeIntent(stopId: entry.configuredStop.id)) {
                        Image(systemName: entry.targetStop.id == ShuttleStop.allStops.id ? "star.fill" : "list.bullet")
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 12, weight: .bold))
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
                ForEach(stoppedVehicles.prefix(maxStoppedVehicles)) { vehicle in
                    HStack {
                        Text(vehicle.name)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.forRoute(vehicle.routeName))

                        Text("at")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.secondaryText)

                        Text((vehicle.currentStop == "STUDENT_UNION_RETURN" ? "STUDENT_UNION" : (vehicle.currentStop ?? "Unknown"))
                                .replacingOccurrences(of: "_", with: " ")
                                .capitalized)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)

                        Spacer()

                        Text("Now")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(palette.highlight)
                    }
                }
            }

            if entry.groupedETAs.isEmpty {
                Text("No ETA predictions available.")
                    .font(.system(size: 9))
                    .foregroundStyle(palette.secondaryText)
            } else {
                ForEach(entry.groupedETAs) { section in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.id.capitalized + " Route")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color.forRoute(section.id))
                        // only show first 2 next etas, for each route
                        ForEach(section.etas.prefix(maxETAsPerRoute)) { eta in
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
                }
            }
        }
    }

    private var singleStopView: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(entry.activeShuttles.prefix(maxSingleStopVehicles)) { vehicle in
                let rawStop = vehicle.currentStop ?? "Unknown"
                let curStop = rawStop == "STUDENT_UNION_RETURN" ? "STUDENT_UNION" : rawStop
                let displayName = curStop.replacingOccurrences(of: "_", with: " ").capitalized
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
                            Text("AT: \(displayName)")
                                .foregroundStyle(palette.alert)
                                .lineLimit(1)
                        } else {
                            Text("MOVING")
                                .foregroundStyle(palette.highlight)
                        }
                    }
                    .font(.system(size: 9))
                    .frame(width: 80, alignment: .leading)

                    Text(vehicle.formattedLocation)
                        .font(.system(size: 8))
                        .lineLimit(2)

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
                Text("Schedule:")
                    .font(.system(size: 13))
                if let next = entry.nextScheduledArrival {
                    Text(next, style: .time).font(.system(size: 12, weight: .bold))
                } else {
                    Text("None").font(.system(size: 12, weight: .bold))
                }
            }
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}
