//
//  SettingsManager.swift
//  Shuttle Tracker
//
//  Created by Claude on 12/13/25.
//

import Foundation
import Combine

/// Manages user preferences using UserDefaults with @AppStorage-compatible keys
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let defaults = UserDefaults.standard
    
    /// Key constants for UserDefaults
    private enum Keys {
        static let stopNotificationsEnabled = "stopNotificationsEnabled"
    }
    
    /// Whether geofence notifications for shuttle stops are enabled
    @Published var stopNotificationsEnabled: Bool {
        didSet {
            defaults.set(stopNotificationsEnabled, forKey: Keys.stopNotificationsEnabled)
        }
    }
    
    private init() {
        // Default to true for new users, load from UserDefaults for returning users
        self.stopNotificationsEnabled = defaults.object(forKey: Keys.stopNotificationsEnabled) as? Bool ?? true
    }
}
