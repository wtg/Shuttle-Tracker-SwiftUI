//
//  WhatsNewView.swift
//  Shuttle Tracker
//
//  Created by Gabriel Jacoby-Cooper on 11/21/21.
//

import StoreKit
import SwiftUI

struct WhatsNewView: View {
	
	let onboarding: Bool
	
	@EnvironmentObject
	private var viewState: ViewState
	
	@EnvironmentObject
	private var sheetStack: ShuttleTrackerSheetStack
	
	var body: some View {
		VStack {
			ScrollView {
				VStack(alignment: .leading) {
					HStack {
						Spacer()
						VStack {
							Text("What’s New")
								.font(.largeTitle)
								.bold()
								.multilineTextAlignment(.center)
							Text("Version 2.0")
								.font(
									.system(
										.callout,
										design: .monospaced
									)
								)
								.bold()
								.padding(5)
								.background(
									.tertiary,
									in: RoundedRectangle(
										cornerRadius: 10,
										style: .continuous
									)
								)
						}
						Spacer()
					}
						.padding(.vertical)
					VStack(alignment: .leading, spacing: 20) {
						#if os(iOS)
						WhatsNewItem(
							title: "Automatic Board Bus",
							description: "Use Board Bus without taking your phone out.",
							icon: .whatsNewAutomaticBoardBus
						)
						WhatsNewItem(
							title: "Shuttle Tracker Network",
							description: "Connect to our custom tracking devices on the buses.",
							icon: .whatsNewNetwork
						)
						#endif // os(iOS)
						WhatsNewItem(
							title: "Notifications",
							description: "Receive push notification for new announcements.",
							icon: .whatsNewNotifications
						)
						WhatsNewItem(
							title: "Design",
							description: "See a new logo, app icon, and color scheme.",
							icon: .whatsNewDesign
						)
						WhatsNewItem(
							title: "Analytics",
							description: "Opt in to analytics sharing to help improve the app.",
							icon: .whatsNewAnalytics
						)
					}
				}
					.padding(.horizontal)
					.padding(.bottom)
					#if os(iOS)
					.padding(.top)
					#endif // os(iOS)
			}
			#if os(iOS)
			Group {
				if self.onboarding {
					NavigationLink {
						NetworkOnboardingView()
					} label: {
						Text("Continue")
							.bold()
							.padding(5)
							.frame(maxWidth: .infinity)
					}
				} else {
					Button {
						self.sheetStack.pop()
					} label: {
						Text("Continue")
							.bold()
							.padding(5)
							.frame(maxWidth: .infinity)
					}
				}
			}
				.buttonStyle(.borderedProminent)
				.padding(.horizontal)
				.padding(.bottom)
			#endif // os(iOS)
		}
			.toolbar {
				#if os(macOS)
				ToolbarItem(placement: .confirmationAction) {
					Button(self.onboarding ? "Continue" : "Close") {
						self.sheetStack.pop()
						if self.onboarding {
							self.sheetStack.push(.analyticsOnboarding)
						} else {
							// TODO: Switch to SwiftUI’s requestReview environment value when we drop support for macOS 12
							// Request a review on the App Store
							// This logic uses the legacy SKStoreReviewController class because the newer SwiftUI requestReview environment value requires macOS 13 or newer, and stored properties can’t be gated on OS version.
							SKStoreReviewController.requestReview()
						}
					}
				}
				#endif // os(macOS)
			}
			.onAppear {
				if self.onboarding {
					self.viewState.handles.whatsNew?.increment()
				}
			}
	}
	
}

#Preview {
	WhatsNewView(onboarding: false)
		.environmentObject(ViewState.shared)
		.environmentObject(ShuttleTrackerSheetStack())
}
