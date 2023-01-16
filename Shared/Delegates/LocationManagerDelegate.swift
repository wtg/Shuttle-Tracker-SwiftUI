//
//  LocationManagerDelegate.swift
//  Shuttle Tracker
//
//  Created by Gabriel Jacoby-Cooper on 9/11/20.
//

import CoreLocation
import SwiftUI

final class LocationManagerDelegate: NSObject, CLLocationManagerDelegate {
	
	fileprivate static let privateDefault = LocationManagerDelegate()
	
	#if os(iOS)
	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		Task {
			guard case .onBus = await BoardBusManager.shared.travelState else {
				return
			}
			await LocationUtilities.sendToServer(coordinate: locations.last!.coordinate)
		}
	}
	
	func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
		Task { @MainActor in
			switch (manager.authorizationStatus, manager.accuracyAuthorization) {
			case (.authorizedAlways, .fullAccuracy):
				if case .network = ViewState.shared.toastType {
					withAnimation {
						ViewState.shared.toastType = nil
					}
				}
			case (.authorizedWhenInUse, _):
				manager.requestAlwaysAuthorization()
				fallthrough
			default:
				switch ViewState.shared.toastType {
				case .network:
					break
				default:
					withAnimation {
						ViewState.shared.toastType = .network
					}
				}
			}
		}
	}
	#endif // os(iOS)
	
}

extension CLLocationManagerDelegate where Self == LocationManagerDelegate {
	
	/// The default location manager delegate, which is automatically set as the delegate for the default location manager.
	static var `default`: Self {
		get {
			return .privateDefault
		}
	}
	
}
