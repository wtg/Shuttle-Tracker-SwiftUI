//
//  ShuttleTrackerApp.swift
//  Shuttle Tracker (iOS)
//
//  Created by Gabriel Jacoby-Cooper on 9/11/20.
//

import CoreLocation
import OnboardingKit
import STLogging
import SwiftUI

@main
struct ShuttleTrackerApp: App {
	
	@State
	private var mapCameraPosition: MapCameraPositionWrapper = .default
	
	@ObservedObject
	private var mapState = MapState.shared
	
	@ObservedObject
	private var viewState = ViewState.shared
	
	@ObservedObject
	private var boardBusManager = BoardBusManager.shared
	
	@ObservedObject
	private var appStorageManager = AppStorageManager.shared
	
	static let sheetStack = ShuttleTrackerSheetStack()
	
	@UIApplicationDelegateAdaptor(AppDelegate.self)
	private var appDelegate
	
	private let onboardingManager = OnboardingManager(flags: ViewState.shared) { (flags) in
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
			OnboardingConditions.ManualCounter(defaultsKey: "TripCount", threshold: 0, settingHandleAt: \.tripCount, in: flags.handles)
			OnboardingConditions.Disjunction {
				OnboardingConditions.ColdLaunch(threshold: 5, comparator: >)
				OnboardingConditions.TimeSinceFirstLaunch(threshold: 172800)
			}
		}
		OnboardingEvent(flags: flags, value: ShuttleTrackerSheetPresentationProvider.SheetType.whatsNew(onboarding: true), handler: Self.pushSheet(_:)) {
			OnboardingConditions.ManualCounter(defaultsKey: "WhatsNew2.0", threshold: 0, settingHandleAt: \.whatsNew, in: flags.handles)
		}
		OnboardingEvent(flags: flags) { (_) in
			CLLocationManager.registerHandler { (locationManager) in
				switch (locationManager.authorizationStatus, locationManager.accuracyAuthorization) {
				case (.authorizedAlways, .fullAccuracy):
					break
				default:
					ViewState.shared.toastType = .network
				}
			}
		} conditions: {
			OnboardingConditions.ColdLaunch(threshold: 1, comparator: >)
		}
		OnboardingEvent(flags: flags) { (_) in
			if AppStorageManager.shared.maximumStopDistance == 20 {
				AppStorageManager.shared.maximumStopDistance = 50
			}
		} conditions: {
			OnboardingConditions.Once(defaultsKey: "UpdatedMaximumStopDistance")
		}
		OnboardingEvent(flags: flags) { (_) in
			if #available(iOS 16, *) {
				if AppStorageManager.shared.baseURL.host() == "shuttletracker.app" {
					guard var components = URLComponents(url: AppStorageManager.shared.baseURL, resolvingAgainstBaseURL: false) else {
						#log(system: Logging.system, category: .api, level: .error, doUpload: true, "Can’t get components of current server base URL (“\(AppStorageManager.shared.baseURL, privacy: .public)”)")
						return
					}
					components.host = "shuttles.rpi.edu"
					do {
						AppStorageManager.shared.baseURL = try components.asURL()
					} catch {
						#log(system: Logging.system, category: .api, level: .error, doUpload: true, "Failed to construct new server base URL: \(error, privacy: .public)")
					}
				}
			}
		} conditions: {
			OnboardingConditions.Once(defaultsKey: "UpdatedServerBaseURL")
		}
		OnboardingEvent(flags: flags) { (_) in
			if AppStorageManager.shared.baseURL == URL(string: "https://staging.shuttletracker.app")! {
				AppStorageManager.shared.baseURL = URL(string: "https://shuttletracker.app")!
			}
		} conditions: {
			OnboardingConditions.Once(defaultsKey: "2.0")
		}
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView(mapCameraPosition: self.$mapCameraPosition)
				.environmentObject(self.mapState)
				.environmentObject(self.viewState)
				.environmentObject(self.boardBusManager)
				.environmentObject(self.appStorageManager)
				.environmentObject(Self.sheetStack)
		}
	}
	
	init() {
		let formattedVersion = if let version = Bundle.main.version { " \(version)" } else { "" }
		let formattedBuild = if let build = Bundle.main.build { " (\(build))" } else { "" }
		#log(system: Logging.system, "Shuttle Tracker for iOS\(formattedVersion, privacy: .public)\(formattedBuild, privacy: .public)")
		CLLocationManager.default = CLLocationManager()
		CLLocationManager.default.activityType = .automotiveNavigation
		CLLocationManager.default.showsBackgroundLocationIndicator = true
		CLLocationManager.default.allowsBackgroundLocationUpdates = true
		CLLocationManager.default.pausesLocationUpdatesAutomatically = false
		if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
			let beaconRegion = CLBeaconRegion(uuid: BoardBusManager.networkUUID, identifier: BoardBusManager.beaconID)
			beaconRegion.notifyEntryStateOnDisplay = true
			CLLocationManager.default.startMonitoring(for: beaconRegion)
			if CLLocationManager.significantLocationChangeMonitoringAvailable() {
				// It’s unclear why, but activating the significant-change location service on app launch and never deactivating is necessary to be able to activate the standard location service upon beacon detection in the background. Otherwise, the user would need to open the app in the foreground to start sending location data to the server, which defeats the purpose of Automatic Board Bus.
				// https://stackoverflow.com/questions/20187700/startupdatelocations-in-background-didupdatingtolocation-only-called-10-20-time
				CLLocationManager.default.startMonitoringSignificantLocationChanges()
			}
		}
		Task {
			do {
				try await UNUserNotificationCenter.requestDefaultAuthorization()
			} catch {
				#log(system: Logging.system, category: .permissions, level: .error, doUpload: true, "Failed to request notification authorization: \(error, privacy: .public)")
			}
		}
	}
	
	private static func pushSheet(_ sheetType: ShuttleTrackerSheetPresentationProvider.SheetType) {
		Task {
			do {
				if #available(iOS 16, *) {
					try await Task.sleep(for: .seconds(1))
				} else {
					try await Task.sleep(nanoseconds: 1_000_000_000)
				}
			} catch {
				#log(system: Logging.system, level: .error, doUpload: true, "Task sleep error: \(error, privacy: .public)")
				throw error
			}
			self.sheetStack.push(sheetType)
		}
	}
	
}
