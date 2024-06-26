//
//  Analytics.swift
//  Shuttle Tracker
//
//  Created by Aidan Flaherty on 2/14/23.
//

import Foundation
import STLogging
import SwiftUI

public enum Analytics {
	
	enum EventType: Codable, Hashable {
		
		case coldLaunch
		
		case boardBusTapped
		
		case leaveBusTapped
		
		case boardBusActivated(manual: Bool)
		
		case boardBusDeactivated(manual: Bool)
		
		case busSelectionCanceled
		
		case announcementsListOpened
		
		case announcementViewed(id: UUID)
		
		case permissionsSheetOpened
		
		case networkToastPermissionsTapped
		
		case colorBlindModeToggled(enabled: Bool)
		
		case debugModeToggled(enabled: Bool)
		
		case serverBaseURLChanged(url: URL)
		
		case locationAuthorizationStatusDidChange(authorizationStatus: Int)
		
		case locationAccuracyAuthorizationDidChange(accuracyAuthorization: Int)
		
	}
	
	struct UserSettings: Codable, Hashable, Equatable {
		
		let colorScheme: String?
		
		let colorBlindMode: Bool
		
		let debugMode: Bool?
		
		let logging: Bool?
		
		let maximumStopDistance: Int?
		
		let serverBaseURL: URL?
		
	}
	
	struct Entry: Hashable, Identifiable, RawRepresentableInJSONArray {
		
		enum ClientPlatform: String, Codable, Hashable, Equatable {
			
			case ios, macos, watchOS
			
		}
		
		let id: UUID
		
		let userID: UUID
		
		let date: Date
		
		let clientPlatform: ClientPlatform
		
		let clientPlatformVersion: String
		
		let appVersion: String
		
		let boardBusCount: Int?
		
		let userSettings: UserSettings
		
		let eventType: EventType
		
		var jsonString: String {
			get throws {
				let encoder = JSONEncoder(dateEncodingStrategy: .iso8601)
				let json = try encoder.encode(self)
				let jsonObject = try JSONSerialization.jsonObject(with: json)
				let data = try JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
				return String(data: data, encoding: .utf8) ?? ""
			}
		}
		
		init(_ eventType: EventType) async {
			self.id = UUID()
            #if !os(watchOS)
			self.userID = await AppStorageManager.shared.userID
            #else
            self.userID = UUID()
            #endif
			self.eventType = eventType
			#if os(iOS)
			self.clientPlatform = .ios
			#elseif os(macOS) // os(iOS)
			self.clientPlatform = .macos
            #elseif os(watchOS)
            self.clientPlatform = .watchOS
			#endif // os(macOS)
			self.date = .now
			self.clientPlatformVersion = ProcessInfo.processInfo.operatingSystemVersionString
            #if !os(watchOS)
			if let version = Bundle.main.version {
				if let build = Bundle.main.build {
					self.appVersion = "\(version) (\(build))"
				} else {
					self.appVersion = version
				}
			} else {
				self.appVersion = ""
			}
            #else
            self.appVersion = Bundle.version().description
            #endif
			#if os(iOS)
			self.boardBusCount = await AppStorageManager.shared.boardBusCount
			#else // os(iOS)
			self.boardBusCount = 0
			#endif
			let colorScheme: String?
            #if !os(watchOS)
			switch await ViewState.shared.colorScheme {
			case .light:
				colorScheme = "light"
			case .dark:
				colorScheme = "dark"
			case .none:
				colorScheme = nil
			@unknown default:
				fatalError()
			}
            #endif
            #if os(watchOS)
            colorScheme = "light"
            #endif
			var debugMode: Bool?
			var maximumStopDistance: Int?
			#if os(iOS)
			debugMode = false // TODO: Set properly once the Debug Mode implementation is merged
			maximumStopDistance = await AppStorageManager.shared.maximumStopDistance
			#endif // os(iOS)
			self.userSettings = UserSettings(
				colorScheme: colorScheme,
				colorBlindMode: await AppStorageManager.shared.colorBlindMode,
				debugMode: debugMode,
				logging: await AppStorageManager.shared.doUploadLogs,
				maximumStopDistance: maximumStopDistance,
				serverBaseURL: await AppStorageManager.shared.baseURL
			)
		}
		
		@available(iOS 16, macOS 13, *)
		func writeToDisk() throws -> URL {
			let url = FileManager.default.temporaryDirectory.appending(component: "\(self.id.uuidString).json")
			do {
				try self.jsonString.write(to: url, atomically: false, encoding: .utf8)
			} catch {
				#log(system: Logging.system, level: .error, doUpload: true, "Failed to save analytics entry file to temporary directory: \(error, privacy: .public)")
			}
			return url
		}
		
	}
	
	static func upload(eventType: EventType) async throws {
		guard await AppStorageManager.shared.doShareAnalytics else {
			return
		}
		do {
			let analyticsEntry = await Entry(eventType)
			try await API.uploadAnalyticsEntry(analyticsEntry: analyticsEntry).perform()
			await MainActor.run {
				#if os(iOS)
				withAnimation {
					AppStorageManager.shared.uploadedAnalyticsEntries.append(analyticsEntry)
				}
				#elseif os(macOS) // os(iOS)
				AppStorageManager.shared.uploadedAnalyticsEntries.append(analyticsEntry)
				#endif // os(macOS)
			}
		} catch {
			#log(system: Logging.system, category: .api, level: .error, doUpload: true, "Failed to upload analytics: \(error, privacy: .public)")
		}
	}
	
}
