//
//  NotificationManager.swift
//  Shuttle Tracker
//
//  Created by Claude on 12/13/25.
//

import Foundation
import UserNotifications
import Combine

/// Manages local notifications for shuttle stop proximity alerts
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    /// Category identifier for stop proximity notifications
    static let stopProximityCategoryIdentifier = "STOP_PROXIMITY"
    
    /// Action identifier for opening the app
    static let openAppActionIdentifier = "OPEN_APP"
    
    override init() {
        super.init()
        checkAuthorizationStatus()
        configureNotificationCategories()
    }
    
    /// Request notification authorization from the user
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
            
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Check current authorization status
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// Configure notification categories and actions
    private func configureNotificationCategories() {
        let openAction = UNNotificationAction(
            identifier: Self.openAppActionIdentifier,
            title: "View Stop",
            options: .foreground
        )
        
        let category = UNNotificationCategory(
            identifier: Self.stopProximityCategoryIdentifier,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    /// Show a notification for entering a shuttle stop region
    /// - Parameters:
    ///   - stopName: The name of the shuttle stop
    ///   - regionIdentifier: Unique identifier for the region (used to dismiss later)
    func showStopProximityNotification(stopName: String, regionIdentifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "Shuttle Stop Nearby"
        content.body = "You're near \(stopName). Open Shuttle Tracker?"
        content.sound = .default
        content.categoryIdentifier = Self.stopProximityCategoryIdentifier
        
        // Use the region identifier as the notification identifier for easy dismissal
        let request = UNNotificationRequest(
            identifier: regionIdentifier,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error.localizedDescription)")
            }
        }
    }
    
    /// Dismiss a notification for leaving a shuttle stop region
    /// - Parameter regionIdentifier: The same identifier used when showing the notification
    func dismissStopProximityNotification(regionIdentifier: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [regionIdentifier])
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [regionIdentifier])
    }
    
    /// Dismiss all stop proximity notifications
    func dismissAllStopNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let stopNotificationIds = notifications
                .filter { $0.request.content.categoryIdentifier == Self.stopProximityCategoryIdentifier }
                .map { $0.request.identifier }
            
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: stopNotificationIds)
        }
    }
}
