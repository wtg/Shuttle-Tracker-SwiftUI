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
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var geofenceManager = GeofenceManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            MapView()
                .environmentObject(settingsManager)
                .environmentObject(geofenceManager)
                .environmentObject(notificationManager)
                .onContinueUserActivity(ShuttleTrackerShortcuts.openAppActivityType) { activity in
                    _ = ShuttleTrackerShortcuts.handleIncomingActivity(activity)
                }
        }
    }
}

#Preview {
    MapView()
}
