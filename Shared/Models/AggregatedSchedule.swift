//
//  AggregatedSchedule.swift
//  iOS
//
//  Created by RS on 12/13/25.
//

import Foundation

/// Represents the schedule for a single day, mapping route names (e.g., "NORTH", "WEST") to their departure times
typealias DaySchedule = [String: [String]]

/// Represents the full weekly aggregated schedule.
/// - Index 0 = Sunday
/// - Index 1 = Monday
/// - Index 2 = Tuesday
/// - Index 3 = Wednesday
/// - Index 4 = Thursday
/// - Index 5 = Friday
/// - Index 6 = Saturday
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
