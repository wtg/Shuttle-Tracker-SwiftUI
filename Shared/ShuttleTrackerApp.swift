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
    // lasts as long as the app is running, and is injected into the different views
    @StateObject private var container = DependencyContainer()
    @Environment(\.scenePhase) var scenePhase
    var body: some Scene {
        WindowGroup {
            MapView(locationManager: container.locationManager)
                .environmentObject(container)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // handles update on initial launch and returning from background
                container.routeService.checkForRefresh()
            }
        }
    }
}
