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
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    MainTabView()
                } else {
                    OnboardingView(
                        hasSeenOnboarding: $hasSeenOnboarding,
                        locationManager: container.locationManager
                    )
                }
            }
            .environmentObject(container)
            .preferredColorScheme(colorScheme)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                // handles update on initial launch and returning from background
                container.routeService.checkForRefresh()
            }
        }
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
