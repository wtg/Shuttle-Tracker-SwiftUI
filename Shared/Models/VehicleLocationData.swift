//
//  VehicleLocationData.swift
//  iOS
//
//  Created by RS on 10/7/25.
//


struct VehicleLocationData: Codable {
    let addressId: String
    let addressName: String
    let assetType: String
    let formattedLocation: String
    let gatewayModel: String
    let gatewaySerial: String
    let headingDegrees: Double
    let isEcuSpeed: Bool
    let latitude: Double
    let licensePlate: String
    let longitude: Double
    let name: String
    let polylineIndex: Int?
    let routeName: String
    let speedMph: Double
    let timestamp: String
    let vin: String
    
    enum CodingKeys: String, CodingKey {
        case addressId = "address_id"
        case addressName = "address_name"
        case assetType = "asset_type"
        case formattedLocation = "formatted_location"
        case gatewayModel = "gateway_model"
        case gatewaySerial = "gateway_serial"
        case headingDegrees = "heading_degrees"
        case isEcuSpeed = "is_ecu_speed"
        case latitude
        case licensePlate = "license_plate"
        case longitude
        case name
        case polylineIndex = "polyline_index"
        case routeName = "route_name"
        case speedMph = "speed_mph"
        case timestamp
        case vin
    }
}

typealias VehicleInformationMap = [String: VehicleLocationData]
