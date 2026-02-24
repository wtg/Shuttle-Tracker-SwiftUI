import Foundation
import Combine
import SwiftUI

@MainActor
class ScheduleViewModel: ObservableObject {
    @Published var selectedDay: DayOfWeek = .monday
    @Published var selectedDirection: String?
    @Published var displayedTimes: [TimeInfo] = []

    // dependencies
    private let scheduleService: ScheduleService
    private let routeService: RouteService
    private let vehicleService: VehicleService

    private var cancellables = Set<AnyCancellable>()

    init(scheduleService: ScheduleService, routeService: RouteService, vehicleService: VehicleService) {
        self.scheduleService = scheduleService
        self.routeService = routeService
        self.vehicleService = vehicleService

        self.selectedDay = DayOfWeek.from(date: Date())

        // refresh the selection view every time the schedule updates
        scheduleService.$scheduleData
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshSelection() }
            .store(in: &cancellables)

        vehicleService.$vehicles
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func loadData() {
        Task { await scheduleService.fetchSchedule() }
    }

    private func refreshSelection() {
        // if no direction is selected, or the selected one isn't valid for this day, pick the first one
        let options = availableDirections
        if selectedDirection == nil || !options.contains(selectedDirection!) {
            selectedDirection = options.first
        }
        updateDisplayedTimes()
    }

    // computed property for the UI to loop over
    var availableDirections: [String] {
        guard let data = scheduleService.scheduleData else { return [] }
        return getAvailableDirections(for: selectedDay, data: data)
    }

    // called when the user taps a Day or Direction, or when data loads
    func updateDisplayedTimes() {
        guard let data = scheduleService.scheduleData, let direction = selectedDirection else {
            displayedTimes = []
            return
        }
        displayedTimes = getConsolidatedTimes(for: direction, day: selectedDay, data: data)
    }

    // calculation helpers
    private func getAvailableDirections(for day: DayOfWeek, data: ScheduleData) -> [String] {
        let type = getScheduleType(for: day, data: data)
        let scheduleMap: [String: [[String]]]

        switch type {
        case "weekday": scheduleMap = data.weekday
        case "saturday": scheduleMap = data.saturdaySchedule
        case "sunday": scheduleMap = data.sundaySchedule
        default: return []
        }

        var directions = Set<String>()
        for (_, times) in scheduleMap {
            for timePair in times {
                if timePair.count > 1 {
                    directions.insert(timePair[1])
                }
            }
        }
        return directions.sorted()
    }

    private func getConsolidatedTimes(for direction: String, day: DayOfWeek, data: ScheduleData) -> [TimeInfo] {
        let type = getScheduleType(for: day, data: data)
        let scheduleMap: [String: [[String]]]

        switch type {
        case "weekday": scheduleMap = data.weekday
        case "saturday": scheduleMap = data.saturdaySchedule
        case "sunday": scheduleMap = data.sundaySchedule
        default: return []
        }

        var results: [TimeInfo] = []
        let now = Date()
        let isToday = day == DayOfWeek.from(date: now)
        let calendar = Calendar.current

        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)
        let rawCurrentMinutes = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)

        let currentMinutesAdjusted = rawCurrentMinutes < 180 ? rawCurrentMinutes + 1440 : rawCurrentMinutes

        for (busName, times) in scheduleMap {
            for timePair in times {
                if timePair.count > 1 {
                    let timeStr = timePair[0]
                    let dirStr = timePair[1]

                    if dirStr == direction, let date = timeStr.simpleTimeToDate {
                        let itemComponents = calendar.dateComponents([.hour, .minute], from: date)
                        let rawItemMinutes = (itemComponents.hour ?? 0) * 60 + (itemComponents.minute ?? 0)
                        let itemMinutesAdjusted = rawItemMinutes < 180 ? rawItemMinutes + 1440 : rawItemMinutes
                        var shouldInclude = true
                        if isToday {
                            if itemMinutesAdjusted < currentMinutesAdjusted {
                                shouldInclude = false
                            }
                        }

                        if shouldInclude {
                            results.append(TimeInfo(time: timeStr, direction: dirStr, busName: busName, date: date, sortValue: itemMinutesAdjusted))
                        }
                    }
                }
            }
        }
        return results.sorted { $0.sortValue < $1.sortValue }
    }

    private func getScheduleType(for day: DayOfWeek, data: ScheduleData) -> String {
        switch day {
        case .monday: return data.monday
        case .tuesday: return data.tuesday
        case .wednesday: return data.wednesday
        case .thursday: return data.thursday
        case .friday: return data.friday
        case .saturday: return data.saturday
        case .sunday: return data.sunday
        }
    }

    // Calculates the specific time for every stop based on the route's offsets
    func getStops(for run: TimeInfo) -> [StopScheduleItem] {
        guard let route = routeService.getRoute(named: run.direction) else { return [] }
        var stops: [StopScheduleItem] = []
        let calendar = Calendar.current
        for stopKey in route.stops {
            if let stopDetails = route.stopDetails[stopKey] {
                // add the offset to the start time
                if let stopDate = calendar.date(byAdding: .minute, value: stopDetails.offset, to: run.date) {
                    stops.append(StopScheduleItem(
                        name: stopDetails.name,
                        time: stopDate.formattedTime
                    ))
                }
            }
        }
        return stops
    }

    /* get the shortest etas for each route using the shared processor */
    func getGroupedETAs() -> [EtasForRoute] {
        return ETAProcessor.getGroupedETAs(vehicles: vehicleService.vehicles, routes: routeService.allRoutes)
    }
}

// helper types
struct StopScheduleItem: Identifiable {
    var id: String { name }
    let name: String
    let time: String
}

struct TimeInfo: Hashable, Identifiable {
    var id: Int { hashValue }
    let time: String
    let direction: String
    let busName: String
    let date: Date
    let sortValue: Int
}

enum DayOfWeek: String, CaseIterable, Identifiable {
    case monday = "MONDAY"
    case tuesday = "TUESDAY"
    case wednesday = "WEDNESDAY"
    case thursday = "THURSDAY"
    case friday = "FRIDAY"
    case saturday = "SATURDAY"
    case sunday = "SUNDAY"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    static func from(date: Date) -> DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        case 1: return .sunday
        default: return .monday
        }
    }
}
