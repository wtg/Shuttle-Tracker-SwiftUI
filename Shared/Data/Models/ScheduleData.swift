//
//  ScheduleData.swift
//  iOS
//
//  Created by RS on 10/10/25.
//

import Foundation

struct ScheduleData: Codable {
    let monday: String
    let tuesday: String
    let wednesday: String
    let thursday: String
    let friday: String
    let saturday: String
    let sunday: String

    // maps "Bus Name" -> Array of [Time, Route]
    let weekday: [String: [[String]]]
    let saturdaySchedule: [String: [[String]]]
    let sundaySchedule: [String: [[String]]]
    enum CodingKeys: String, CodingKey {
        case monday = "MONDAY"
        case tuesday = "TUESDAY"
        case wednesday = "WEDNESDAY"
        case thursday = "THURSDAY"
        case friday = "FRIDAY"
        case saturday = "SATURDAY"
        case sunday = "SUNDAY"
        case weekday
        case saturdaySchedule = "saturday"
        case sundaySchedule = "sunday"
    }
}

// Represents the schedule for a single day, mapping route names (e.g., "NORTH", "WEST") to their departure times
typealias DaySchedule = [String: [String]]

// Represents the full weekly aggregated schedule. Index 0 = Sunday ... Index 6 = Saturday
typealias AggregatedSchedule = [DaySchedule]

extension AggregatedSchedule {
    /// Returns the schedule for today based on the current weekday
    func todaySchedule() -> DaySchedule {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Calendar weekday: 1 = Sunday, 2 = Monday, etc.
        // Array index: 0 = Sunday, 1 = Monday, etc.
        let index = weekday - 1
        guard index >= 0 && index < count else { return [:] }
        return self[index]
    }

    /// Returns the set of route names that are active today
    func activeRouteNames() -> Set<String> {
        Set(todaySchedule().keys)
    }
}
