import Testing
import Foundation
@testable import ShuttleTrackerApp

struct TimeTests {

    @Test("ISO8601 String parses to correct Date")
    func validIsoStringToDate() {
        let dateString = "2026-04-07T17:20:00Z"
        let date = dateString.isoTimeToDate
        #expect(date != nil)
    }

    @Test("Invalid ISO string returns nil")
    func invalidIsoStringReturnsNil() {
        let dateString = "not-a-real-date-string"
        let date = dateString.isoTimeToDate
        #expect(date == nil)
    }

    @Test("Simple time string parses to Date")
    func simpleTimeParses() {
        let timeString = "12:30 PM"
        let date = timeString.simpleTimeToDate
        #expect(date != nil)
    }

    @Test("Next scheduled arrival wraps correctly past midnight")
    func testHourWrapping() throws {
        let mockStop = ShuttleStopData(coordinates: [0,0], offset: 15, name: "Student Union")
        let routeData = RouteDirectionData(color: "red", stops: ["STUDENT_UNION"], polylineStops: [], routes: [], stopDetails: ["STUDENT_UNION": mockStop])
        let routes: ShuttleRouteData = ["WEST": routeData]

        // 11:55 PM departure
        let schedule = ScheduleData(
            monday: "weekday", tuesday: "weekday", wednesday: "weekday", thursday: "weekday", friday: "weekday", saturday: "saturday", sunday: "sunday",
            weekday: ["Bus 1": [["11:55 PM", "WEST"]]],
            saturdaySchedule: [:],
            sundaySchedule: [:]
        )

        // current time 11:50 PM
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 50
        let simulatedNow = calendar.date(from: components)!

        let nextArrival = ScheduleCalculator.nextScheduledArrival(
            for: "STUDENT_UNION",
            routeKey: "WEST",
            schedule: schedule,
            routes: routes,
            now: simulatedNow
        )

        // verify (11:55 PM + 15 minute offset = 12:10 AM the next day)
        #expect(nextArrival != nil)

        let arrivalComponents = calendar.dateComponents([.hour, .minute, .day], from: nextArrival!)
        #expect(arrivalComponents.hour == 0) // wrapped to midnight
        #expect(arrivalComponents.minute == 10)
        #expect(arrivalComponents.day == components.day! + 1) // wrapped to next day
    }
}
