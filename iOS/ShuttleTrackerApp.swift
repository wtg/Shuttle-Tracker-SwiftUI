//
//  ShuttleTrackerApp.swift
//  Shuttle Tracker (iOS)
//
//  Created by Gabriel Jacoby-Cooper on 9/11/20.
//

import SwiftUI
import CoreLocation
import OnboardingKit

@main struct ShuttleTrackerApp: App {
	
	@ObservedObject private var mapState = MapState.shared
	
	@ObservedObject private var viewState = ViewState.shared
	
	private let onboardingManager = OnboardingManager(flags: ViewState.shared) { (flags) in
		OnboardingEvent(flags: flags, settingFlagAt: \.sheetType, to: .privacy) {
			OnboardingConditions.ColdLaunch(threshold: 1)
		}
		OnboardingEvent(flags: flags, settingFlagAt: \.toastType, to: .legend) {
			OnboardingConditions.ColdLaunch(threshold: 3)
			OnboardingConditions.ColdLaunch(threshold: 5)
		}
		OnboardingEvent(flags: flags, settingFlagAt: \.legendToastHeadlineText, to: .tip) {
			OnboardingConditions.ColdLaunch(threshold: 3)
		}
		OnboardingEvent(flags: flags, settingFlagAt: \.legendToastHeadlineText, to: .reminder) {
			OnboardingConditions.ColdLaunch(threshold: 5)
		}
		OnboardingEvent(flags: flags, settingFlagAt: \.toastType, to: .boardBus) {
			OnboardingConditions.ManualCounter(defaultsKey: "TripCount", threshold: 0, settingHandleAt: \.tripCount, in: flags.handles, comparator: ==)
			OnboardingConditions.Disjunction {
				OnboardingConditions.ColdLaunch(threshold: 3, comparator: >)
				if #available(iOS 15, *) {
					OnboardingConditions.TimeSinceFirstLaunch(threshold: 172800)
				}
			}
		}
		OnboardingEvent(flags: flags, settingFlagAt: \.sheetType, to: .whatsNew) {
			OnboardingConditions.ManualCounter(defaultsKey: "WhatsNew1.2", threshold: 0, settingHandleAt: \.whatsNew, in: flags.handles, comparator: ==)
			OnboardingConditions.ColdLaunch(threshold: 1, comparator: >)
		}
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.environmentObject(self.mapState)
				.environmentObject(self.viewState)
		}
	}
	
	init() {
		LocationUtilities.locationManager = CLLocationManager()
		LocationUtilities.locationManager.requestWhenInUseAuthorization()
		LocationUtilities.locationManager.activityType = .automotiveNavigation
		LocationUtilities.locationManager.showsBackgroundLocationIndicator = true
		LocationUtilities.locationManager.allowsBackgroundLocationUpdates = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound,.badge,.alert]) {
                success, error in
                if success {
                }
                else if let error = error { // we fail in silence.
                    print(error.localizedDescription)
                }
            }
	}
	
}
