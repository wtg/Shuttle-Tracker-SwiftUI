import Foundation

struct ScheduleCalculator {
    static func nextScheduledArrival(for targetStopKey: String, routeKey: String?, schedule: ScheduleData, routes: ShuttleRouteData, now: Date = Date()) -> Date? {
        let calendar = Calendar.current
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
                if calendar.component(.hour, from: todayBaseDate) < 4 && calendar.component(.hour, from: now) >= 18 {
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
}
