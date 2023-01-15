//
//  LoggingAnalyticsSettingsView.swift
//  Shuttle Tracker (iOS)
//
//  Created by Gabriel Jacoby-Cooper on 11/18/22.
//

import SwiftUI

struct LoggingAnalyticsSettingsView: View {
	
	enum LogUploadState {
		
		case waiting, uploading, uploaded
		
	}
	
	@State
	private var doShowConfirmationDialog = false
	
	@State
	private var logUploadState: LogUploadState = .waiting
	
	@State
	private var didClearUploadedLogs = false
	
	@State
	private var logUploadError: WrappedError?
	
	#if os(macOS)
	@State
	private var selectedLog: Logging.Log?
	#endif // os(macOS)
	
	@EnvironmentObject
	private var appStorageManager: AppStorageManager
	
	private let dateFormatter: DateFormatter = {
		let dateFormatter = DateFormatter()
		dateFormatter.dateStyle = .long
		dateFormatter.timeStyle = .short
		dateFormatter.doesRelativeDateFormatting = true
		return dateFormatter
	}()
	
	var body: some View {
		Form {
			Section {
				#if os(macOS)
				HStack {
					Toggle("Automatically upload logs", isOn: self.appStorageManager.$doUploadLogs)
					Spacer()
					if case .uploading = self.logUploadState {
						ProgressView()
							.scaleEffect(0.5)
					}
					Button(action: self.uploadLog) {
						HStack {
							Text("Upload Log Now")
							switch self.logUploadState {
							case .waiting, .uploading:
								EmptyView()
							case .uploaded:
								Text("✓")
							}
						}
					}
						.disabled(.uploading ~= self.logUploadState || .uploaded ~= self.logUploadState)
				}
				#else // os(macOS)
				Toggle("Automatically Upload Logs", isOn: self.appStorageManager.$doUploadLogs)
				Button(action: self.uploadLog) {
					HStack {
						Text("Upload Log Now")
						Spacer()
						switch self.logUploadState {
						case .waiting:
							EmptyView()
						case .uploading:
							ProgressView()
						case .uploaded:
							Text("✓")
						}
					}
				}
					.disabled(.uploading ~= self.logUploadState || .uploaded ~= self.logUploadState)
				#endif
			}
			#if os(macOS)
			Divider()
			#endif // os(macOS)
			Section {
				#if os(macOS)
				HStack {
					List(
						self.appStorageManager.uploadedLogs
							.sorted { (first, second) in
								return first.date < second.date
							}
							.reversed(),
						selection: self.$selectedLog
					) { (log) in
						VStack(alignment: .leading) {
							Text(self.dateFormatter.string(from: log.date))
								.font(.headline)
							Text(log.id.uuidString)
								.font(.caption)
						}
							.tag(log)
					}
						.listStyle(.plain)
						.frame(width: 300)
						.animation(.default, value: self.appStorageManager.uploadedLogs)
					Divider()
					if let log = self.selectedLog {
						LogDetailView(log: log)
					} else {
						Spacer()
						Text("No Log Selected")
							.font(.title2)
							.multilineTextAlignment(.center)
							.foregroundColor(.secondary)
							.padding()
						Spacer()
					}
				}
				#else // os(macOS)
				List(
					self.appStorageManager.uploadedLogs
						.sorted { (first, second) in
							return first.date < second.date
						}
						.reversed()
				) { (log) in
					NavigationLink {
						LogDetailView(log: log)
					} label: {
						VStack(alignment: .leading) {
							Text(self.dateFormatter.string(from: log.date))
								.font(.headline)
							Text(log.id.uuidString)
								.font(.caption)
						}
					}
				}
				Button(role: .destructive) {
					self.doShowConfirmationDialog = true
				} label: {
					HStack {
						Text("Clear Uploaded Logs")
						Spacer()
						if self.didClearUploadedLogs {
							Text("✓")
						}
					}
				}
				.disabled(self.appStorageManager.uploadedLogs.isEmpty)
				#endif
			} header: {
				#if os(macOS)
				HStack {
					Text("Uploaded Logs")
						.bold()
					Spacer()
					Button(role: .destructive) {
						self.doShowConfirmationDialog = true
					} label: {
						HStack {
							Text("Clear")
							if self.didClearUploadedLogs {
								Text("✓")
							}
						}
					}
						.disabled(self.appStorageManager.uploadedLogs.isEmpty)
				}
				#else // os(macOS)
				Text("Uploaded Logs")
				#endif
			}
		}
			#if os(iOS)
			.navigationTitle("Logging & Analytics")
			.toolbar {
				CloseButton()
			}
			#endif // os(iOS)
			.alert(isPresented: self.$logUploadError.isNotNil, error: self.logUploadError) {
				Button("Retry", action: self.uploadLog)
				Button("Cancel", role: .cancel) {
					#if os(iOS)
					withAnimation {
						self.logUploadState = .waiting
					}
					#elseif os(macOS) // os(iOS)
					self.logUploadState = .waiting
					#endif // os(macOS)
				}
			}
			.confirmationDialog("Clear Uploaded Logs", isPresented: self.$doShowConfirmationDialog) {
				Button("Clear Uploaded Logs", role: .destructive) {
					#if os(iOS)
					withAnimation {
						self.appStorageManager.uploadedLogs.removeAll()
						self.didClearUploadedLogs = true
					}
					#elseif os(macOS) // os(iOS)
					self.appStorageManager.uploadedLogs.removeAll()
					self.didClearUploadedLogs = true
					#endif // os(macOS)
				}
				Button("Cancel", role: .cancel) { }
			} message: {
				Text("Are you sure that you want to clear the record of logs that have been uploaded from this device? This will only clear the logs locally; since uploaded logs are not tied to your device or your identity to protect your privacy, they can’t be deleted from the server.")
			}
			.onAppear {
				self.logUploadState = .waiting
			}
			.onChange(of: self.appStorageManager.uploadedLogs) { (newValue) in
				if !newValue.isEmpty {
					#if os(iOS)
					withAnimation {
						self.didClearUploadedLogs = false
					}
					#elseif os(macOS) // os(iOS)
					self.didClearUploadedLogs = false
					#endif // os(macOS)
				}
			}
	}
	
	private func uploadLog() {
		#if os(iOS)
		withAnimation {
			self.logUploadState = .uploading
		}
		#elseif os(macOS) // os(iOS)
		self.logUploadState = .uploading
		#endif // os(macOS)
		Task {
			do {
				try await Logging.uploadLog()
				#if os(iOS)
				withAnimation {
					self.logUploadState = .uploaded
				}
				#elseif os(macOS) // os(iOS)
				self.logUploadState = .uploaded
				#endif // os(macOS)
			} catch let error {
				self.logUploadError = WrappedError(error)
				Logging.withLogger { (logger) in
					logger.log(level: .error, "[\(#fileID):\(#line) \(#function, privacy: .public)] Failed to upload logs: \(error, privacy: .public)")
				}
				throw error
			}
		}
	}
	
}

struct LoggingAnalyticsSettingsViewPreviews: PreviewProvider {
	
	static var previews: some View {
		LoggingAnalyticsSettingsView()
			.environmentObject(AppStorageManager.shared)
			.onAppear {
				AppStorageManager.shared.uploadedLogs = [
					Logging.Log(content: "Hello, world!")
				]
			}
	}
	
}
