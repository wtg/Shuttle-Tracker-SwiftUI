//
//  SecondaryOverlay.swift
//  Shuttle Tracker (iOS)
//
//  Created by Gabriel Jacoby-Cooper on 10/7/21.
//

import SwiftUI

struct SecondaryOverlay: View {
	
	@State
	private var announcements: [Announcement] = []
	
	@EnvironmentObject
	private var mapState: MapState
	
	@EnvironmentObject
	private var appStorageManager: AppStorageManager
	
	private var unviewedAnnouncementsCount: Int {
		get {
			return self.announcements
				.filter { (announcement) in
					return !self.appStorageManager.viewedAnnouncementIDs.contains(announcement.id)
				}
				.count
		}
	}
	
	var body: some View {
		VStack {
			VStack(spacing: 0) {
				if CalendarUtilities.isAprilFools {
					SecondaryOverlayButton(
						iconSystemName: "gearshape.fill",
						sheetType: .plus(featureText: "Changing settings"),
						badgeNumber: 1
					)
				} else {
					SecondaryOverlayButton(
						iconSystemName: "gearshape.fill",
						sheetType: .settings
					)
				}
				Divider()
					.frame(width: 45, height: 0)
				if CalendarUtilities.isAprilFools {
					SecondaryOverlayButton(
						iconSystemName: "info.circle.fill",
						sheetType: .plus(featureText: "Viewing app information"),
						badgeNumber: 1
					)
				} else {
					SecondaryOverlayButton(
						iconSystemName: "info.circle.fill",
						sheetType: .info
					)
				}
				Divider()
					.frame(width: 45, height: 0)
				SecondaryOverlayButton(
					iconSystemName: "exclamationmark.bubble.fill",
					sheetType: .announcements,
					badgeNumber: self.unviewedAnnouncementsCount
				)
					.task {
						self.announcements = await [Announcement].download()
					}
			}
				.background(
					VisualEffectView(.systemThickMaterial)
						.cornerRadius(10)
						.shadow(radius: 5)
				)
			VStack(spacing: 0) {
				SecondaryOverlayButton(iconSystemName: "location.fill.viewfinder") {
					Task {
						await self.mapState.resetVisibleMapRect()
					}
				}
			}
				.background(
					VisualEffectView(.systemThickMaterial)
						.cornerRadius(10)
						.shadow(radius: 5)
				)
		}
	}
	
}

struct SecondaryOverlayPreviews: PreviewProvider {
	
	static var previews: some View {
		SecondaryOverlay()
			.environmentObject(MapState.shared)
	}
	
}
