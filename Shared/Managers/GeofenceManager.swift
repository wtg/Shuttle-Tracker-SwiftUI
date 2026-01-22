//
//  GeofenceManager.swift
//  Shuttle Tracker
//
//  Created by Claude on 12/13/25.
//

import Foundation
import CoreLocation
import Combine

/// Manages geofencing for shuttle stop proximity detection
class GeofenceManager: NSObject, ObservableObject {
    static let shared = GeofenceManager()
    
    private let locationManager = CLLocationManager()
    private let settingsManager = SettingsManager.shared
    private let notificationManager = NotificationManager.shared
    
    /// Geofence radius in meters around each stop
    private let geofenceRadius: CLLocationDistance = 50.0
    
    /// Currently registered stop regions
    @Published private(set) var registeredStops: [String: CLCircularRegion] = [:]
    
    /// Currently inside these regions
    @Published private(set) var currentlyInsideStops: Set<String> = []
    
    /// Whether the user has granted Always authorization
    @Published private(set) var hasAlwaysAuthorization = false
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        locationManager.delegate = self
        // Note: Region monitoring uses iOS's low-power coprocessor and doesn't
        // require continuous GPS updates, making it battery-efficient
        
        checkAuthorizationStatus()
        
        // Observe settings changes to start/stop geofencing
        settingsManager.$stopNotificationsEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.startMonitoringIfAuthorized()
                } else {
                    self?.stopMonitoringAllStops()
                    self?.notificationManager.dismissAllStopNotifications()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Request "Always" location authorization for background geofencing
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    /// Fetch stops from API and register geofences
    func setupGeofencesFromAPI() {
        Task {
            do {
                let routes = try await API.shared.fetch(ShuttleRouteData.self, endpoint: "routes")
                await MainActor.run {
                    registerGeofences(from: routes)
                }
            } catch {
                print("Error fetching routes for geofencing: \(error)")
            }
        }
    }
    
    /// Register geofences for all unique stops from route data
    private func registerGeofences(from routes: ShuttleRouteData) {
        guard settingsManager.stopNotificationsEnabled else { return }
        guard hasAlwaysAuthorization else {
            print("Cannot register geofences: Always authorization not granted")
            return
        }
        
        // Clear existing regions first
        stopMonitoringAllStops()
        
        // Collect unique stops from all routes
        var uniqueStops: [String: (latitude: Double, longitude: Double)] = [:]
        
        for (_, routeData) in routes {
            for (stopName, stopData) in routeData.stopDetails {
                guard stopData.coordinates.count == 2 else { continue }
                uniqueStops[stopName] = (latitude: stopData.coordinates[0], longitude: stopData.coordinates[1])
            }
        }
        
        // Register a geofence for each stop
        for (stopName, coords) in uniqueStops {
            let center = CLLocationCoordinate2D(latitude: coords.latitude, longitude: coords.longitude)
            let identifier = "stop_\(stopName)"
            
            let region = CLCircularRegion(
                center: center,
                radius: geofenceRadius,
                identifier: identifier
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            
            locationManager.startMonitoring(for: region)
            registeredStops[identifier] = region
        }
        
        print("Registered \(registeredStops.count) stop geofences")
    }
    
    /// Stop monitoring all registered stop regions
    func stopMonitoringAllStops() {
        for (_, region) in registeredStops {
            locationManager.stopMonitoring(for: region)
        }
        registeredStops.removeAll()
        currentlyInsideStops.removeAll()
    }
    
    /// Check current authorization and update state
    private func checkAuthorizationStatus() {
        let status = locationManager.authorizationStatus
        hasAlwaysAuthorization = (status == .authorizedAlways)
    }
    
    /// Start monitoring if we have authorization
    private func startMonitoringIfAuthorized() {
        if hasAlwaysAuthorization && registeredStops.isEmpty {
            setupGeofencesFromAPI()
        }
    }
    
    /// Extract stop name from region identifier
    private func stopName(from identifier: String) -> String {
        if identifier.hasPrefix("stop_") {
            return String(identifier.dropFirst(5))
        }
        return identifier
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceManager: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkAuthorizationStatus()
        
        if hasAlwaysAuthorization {
            startMonitoringIfAuthorized()
            
            // Also request notification permission now that we have location
            notificationManager.requestAuthorization()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        guard settingsManager.stopNotificationsEnabled else { return }
        
        let identifier = circularRegion.identifier
        currentlyInsideStops.insert(identifier)
        
        let name = stopName(from: identifier)
        notificationManager.showStopProximityNotification(stopName: name, regionIdentifier: identifier)
        
        // Donate to Siri for suggestions
        ShuttleTrackerShortcuts.donateOpenAppActivity(nearStop: name)
        
        print("Entered stop region: \(name)")
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        
        let identifier = circularRegion.identifier
        currentlyInsideStops.remove(identifier)
        
        // Dismiss the notification when leaving the stop
        notificationManager.dismissStopProximityNotification(regionIdentifier: identifier)
        
        print("Exited stop region: \(stopName(from: identifier))")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Geofence monitoring failed for \(region?.identifier ?? "unknown"): \(error.localizedDescription)")
    }
}
