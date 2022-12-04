//
//  SheetPresentationWrapper.swift
//  Shuttle Tracker
//
//  Created by Gabriel Jacoby-Cooper on 3/3/22.
//

import SwiftUI

struct SheetPresentationWrapper<Content>: View where Content: View {
	
	private let content: Content
	
	@State
	private var sheetType: SheetStack.SheetType?
	
	@State
	private var handle: SheetStack.Handle!
	
	@EnvironmentObject
	private var sheetStack: SheetStack
	
	var body: some View {
		self.content
			.onAppear {
				self.handle = self.sheetStack.register()
			}
			.onReceive(self.sheetStack.publisher) { (sheets) in
				if sheets.count > self.handle.observedIndex {
					self.sheetType = sheets[self.handle.observedIndex]
				} else {
					self.sheetType = nil
				}
			}
			.onChange(of: self.sheetType) { (sheetType) in
				if self.sheetStack.count == self.handle.observedIndex {
					if let sheetType = sheetType {
						self.sheetStack.push(sheetType)
					}
				} else if self.sheetStack.count > self.handle.observedIndex {
					guard sheetType == nil else {
						return
					}
					while self.sheetStack.count - self.handle.observedIndex > 1 {
						self.sheetStack.pop()
					}
				}
			}
			.sheet(item: self.$sheetType) {
				if self.sheetStack.count > self.handle.observedIndex {
					self.sheetStack.pop()
				}
			} content: { (sheetType) in
				switch sheetType {
				case .announcements:
					AnnouncementsSheet()
						.frame(idealWidth: 500, idealHeight: 500)
				case .busSelection:
					#if os(iOS)
					BusSelectionSheet()
						.interactiveDismissDisabled()
					#endif // os(iOS)
				case .info:
					#if os(iOS) && !APPCLIP
					InfoSheet()
					#endif // os(iOS) && !APPCLIP
				#if os(iOS)
				case .mailCompose(
					let subject,
					let toRecipients,
					let ccRecipients,
					let bccRecipients,
					let messageBody,
					let isHTMLMessageBody,
					let attachments
				):
					MailComposeView(
						subject: subject,
						toRecipients: toRecipients,
						ccRecipients: ccRecipients,
						bccRecipients: bccRecipients,
						messageBody: messageBody,
						isHTMLMessageBody: isHTMLMessageBody,
						attachments: attachments
					) { (_) in 
						self.sheetStack.pop()
					}
				#endif // os(iOS)
				case .permissions:
					#if os(iOS) && !APPCLIP
					PermissionsSheet()
						.interactiveDismissDisabled()
					#endif // os(iOS) && !APPCLIP
				case .plus(let featureText):
					#if os(iOS)
					PlusSheet(featureText: featureText)
						.interactiveDismissDisabled()
					#endif // os(iOS)
				case .privacy:
					#if os(macOS)
					// Don’t use a navigation view on macOS
					PrivacyView()
						.frame(idealWidth: 500, idealHeight: 500)
					#else // os(macOS)
					PrivacySheet()
					#endif
				case .settings:
					#if os(iOS) && !APPCLIP
					SettingsSheet()
					#endif // os(iOS) && !APPCLIP
				case .welcome:
					#if os(iOS) && !APPCLIP
					WelcomeSheet()
						.interactiveDismissDisabled()
					#endif // os(iOS) && !APPCLIP
				case .whatsNew:
					#if !APPCLIP
					WhatsNewSheet()
						.frame(idealWidth: 500, idealHeight: 500)
					#endif // !APPCLIP
				}
			}
	}
	
	init(@ViewBuilder _ content: () -> Content) {
		self.content = content()
	}
	
}
