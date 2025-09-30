//
//  ShuttleTrackerApp.swift
//  Shuttle Tracker
//
//  Created by Williams Chen on 9/24/25.
//

import SwiftUI
import MapKit

@main
struct ShuttleTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            MapView()
        }
    }
}

#Preview {
    MapView()
}
