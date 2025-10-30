//
//  ScheduleData.swift
//  iOS
//
//  Created by RS on 10/10/25.
//


struct ScheduleData: Codable {
    let monday: String
    let tuesday: String
    let wednesday: String
    let thursday: String
    let friday: String
    let saturday: String
    let sunday: String
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
