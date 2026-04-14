import Testing
import Foundation
@testable import ShuttleTrackerApp

struct ScheduleDataTests {
    @Test("todaySchedule returns correct schedule based on weekday")
    func testTodayScheduleResolution() {
        // Index 0 = Sunday ... Index 6 = Saturday
        var mockSchedule: AggregatedSchedule = Array(repeating: [:], count: 7)
        mockSchedule[0] = ["NORTH": ["10:00 AM"]] // Sunday
        mockSchedule[3] = ["WEST": ["08:00 AM"]]  // Wednesday
        let calendar = Calendar.current

        // Sunday (April 19, 2026)
        var sundayComps = DateComponents()
        sundayComps.year = 2026; sundayComps.month = 4; sundayComps.day = 19
        let sunday = calendar.date(from: sundayComps)!

        #expect(mockSchedule.todaySchedule(for: sunday).keys.contains("NORTH"))
        #expect(mockSchedule.activeRouteNames(for: sunday).contains("NORTH"))

        // Wednesday (April 15, 2026)
        var wedComps = DateComponents()
        wedComps.year = 2026; wedComps.month = 4; wedComps.day = 15
        let wednesday = calendar.date(from: wedComps)!

        #expect(mockSchedule.todaySchedule(for: wednesday).keys.contains("WEST"))
        #expect(mockSchedule.activeRouteNames(for: wednesday).contains("WEST"))
    }

    @Test("todaySchedule handles out of bounds safely")
    func testTodayScheduleOutOfBounds() {
        let emptySchedule: AggregatedSchedule = []
        let result = emptySchedule.todaySchedule()
        #expect(result.isEmpty)
    }
}
