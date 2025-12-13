//
//  ShuttleTrackerShortcuts.swift
//  Shuttle Tracker
//
//  Created by Claude on 12/13/25.
//

import Foundation
import Intents

/// Handles Siri Shortcuts integration for the Shuttle Tracker app
struct ShuttleTrackerShortcuts {
    
    /// Activity type for opening the app
    static let openAppActivityType = "edu.rpi.shuttletracker.openApp"
    
    /// Donate an activity to Siri when the user opens the app near a stop
    /// This teaches Siri the user's pattern and enables proactive suggestions
    static func donateOpenAppActivity(nearStop stopName: String? = nil) {
        let activity = NSUserActivity(activityType: openAppActivityType)
        activity.title = "Open Shuttle Tracker"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        
        // Set suggested invocation phrase
        if let stopName = stopName {
            activity.suggestedInvocationPhrase = "Check shuttles near \(stopName)"
            activity.userInfo = ["stopName": stopName]
        } else {
            activity.suggestedInvocationPhrase = "Check shuttle times"
        }
        
        // Keywords for Spotlight search
        activity.keywords = Set(["shuttle", "bus", "RPI", "Rensselaer", "tracker", "transit"])
        
        // Make it current to donate to Siri
        activity.becomeCurrent()
    }
    
    /// Handle an incoming user activity (from Siri invocation)
    static func handleIncomingActivity(_ activity: NSUserActivity) -> Bool {
        guard activity.activityType == openAppActivityType else { return false }
        
        // The app is opening - we could navigate to a specific view if needed
        if let stopName = activity.userInfo?["stopName"] as? String {
            print("Opened via Siri shortcut near stop: \(stopName)")
        }
        
        return true
    }
}
