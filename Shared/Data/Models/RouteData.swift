//
//  RouteData.swift
//  iOS
//
//  Created by RS on 10/10/25.
//

import Foundation

// shuttle stop model from /routes response
struct ShuttleStopData: Codable {
    let coordinates: [Double]
    let offset: Int
    let name: String // formatted stop names "Student Union"
    enum CodingKeys: String, CodingKey {
        case coordinates = "COORDINATES"
        case offset = "OFFSET"
        case name = "NAME"
    }
}

struct RouteDirectionData: Codable {
    let color: String
    let stops: [String] // non-formatted stop names (STUDENT_UNION)
    let polylineStops: [String]
    let routes: [[[Double]]]
    let stopDetails: [String: ShuttleStopData] // dynamic stop objects by name ("STUDENT_UNION" -> {coords,offset,name})
    private enum FixedKeys: String, CodingKey {
        case color = "COLOR"
        case stops = "STOPS"
        case polylineStops = "POLYLINE_STOPS"
        case routes = "ROUTES"
    }

    struct AnyKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)

        // Decode fixed keys
        color = try container.decode(String.self, forKey: AnyKey(stringValue: FixedKeys.color.rawValue)!)
        stops = try container.decode([String].self, forKey: AnyKey(stringValue: FixedKeys.stops.rawValue)!)
        polylineStops = try container.decode([String].self, forKey: AnyKey(stringValue: FixedKeys.polylineStops.rawValue)!)
        routes = try container.decode([[[Double]]].self, forKey: AnyKey(stringValue: FixedKeys.routes.rawValue)!)

        // Decode dynamic stop keys, but only those listed in STOPS or POLYLINE_STOPS
        let fixed = Set([FixedKeys.color.rawValue, FixedKeys.stops.rawValue, FixedKeys.polylineStops.rawValue, FixedKeys.routes.rawValue])
        let validStopNames = Set(stops).union(Set(polylineStops))

        var details: [String: ShuttleStopData] = [:]

        for key in container.allKeys {
            let name = key.stringValue
            // Only decode if it's NOT a fixed key and IS a known stop name
            if !fixed.contains(name) && validStopNames.contains(name) {
                if let stop = try? container.decode(ShuttleStopData.self, forKey: key) {
                    details[name] = stop
                }
            }
        }
        stopDetails = details
    }

    // Encoding logic preserved for caching
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyKey.self)

        try container.encode(color, forKey: AnyKey(stringValue: FixedKeys.color.rawValue)!)
        try container.encode(stops, forKey: AnyKey(stringValue: FixedKeys.stops.rawValue)!)
        try container.encode(polylineStops, forKey: AnyKey(stringValue: FixedKeys.polylineStops.rawValue)!)
        try container.encode(routes, forKey: AnyKey(stringValue: FixedKeys.routes.rawValue)!)

        for (name, stop) in stopDetails {
            try container.encode(stop, forKey: AnyKey(stringValue: name)!)
        }
    }
}

// Top level alias
typealias ShuttleRouteData = [String: RouteDirectionData]
