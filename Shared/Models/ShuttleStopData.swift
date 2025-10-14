//
//  ShuttleStopData.swift
//  iOS
//
//  Created by RS on 10/10/25.
//


struct ShuttleStopData: Codable {
    let coordinates: [Double]
    let offset: Int
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case coordinates = "COORDINATES"
        case offset = "OFFSET"
        case name = "NAME"
    }
}

struct RouteDirectionData: Decodable {
    let color: String
    let stops: [String]
    let polylineStops: [String]
    let routes: [[[Double]]]
    let stopDetails: [String: ShuttleStopData] // dynamic stop objects by name

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

        // Decode dynamic stop keys, but only those listed in STOPS
        let fixed = Set([FixedKeys.color.rawValue, FixedKeys.stops.rawValue, FixedKeys.polylineStops.rawValue, FixedKeys.routes.rawValue])
        let validStopNames = Set(stops)
        var details: [String: ShuttleStopData] = [:]

        for key in container.allKeys {
            let name = key.stringValue
            guard !fixed.contains(name), validStopNames.contains(name) else { continue }
            if let stop = try? container.decode(ShuttleStopData.self, forKey: key) {
                details[name] = stop
            }
        }
        stopDetails = details
    }
}

typealias ShuttleRouteData = [String: RouteDirectionData]
