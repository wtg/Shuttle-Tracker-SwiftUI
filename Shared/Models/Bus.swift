//
//  Bus.swift
//  iOS
//
//  Created by Williams Chen on 9/30/25.
//

import Foundation

struct Bus: Decodable, Identifiable, Hashable {
    var id: String
    
    let name: String
    let latitude: Double
    let longitude: Double
    
    // Other fields that we may need in the future that are given by the API
    // let addressID: String
    // let addressName: String
    // let assetType: String
    // let formattedLocation: String
    // let gatewayModel: String
    // let gatewaySerial: String
    // let headingDegrees: Double
    // let isEcuSpeed: Bool
    // let licensePlate: String
    // let routeName: String
    // let speedMph: Double
    // let timestamp: Date
    // let vin: String
}
