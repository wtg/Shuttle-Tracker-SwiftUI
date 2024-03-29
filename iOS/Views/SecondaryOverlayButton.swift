//
//  SecondaryOverlayButton.swift
//  Shuttle Tracker (iOS)
//
//  Created by Gabriel Jacoby-Cooper on 10/23/21.
//

import SwiftUI

struct SecondaryOverlayButton: View {
	
	let icon: SFSymbol
	
	let sheetType: ShuttleTrackerSheetPresentationProvider.SheetType?
	
	let action: (() -> Void)?
	
	let badgeNumber: Int
	
	@EnvironmentObject
	private var viewState: ViewState
	
	@EnvironmentObject
	private var sheetStack: ShuttleTrackerSheetStack
	
	var body: some View {
		Button {
			if let sheetType = self.sheetType {
				self.sheetStack.push(sheetType)
			} else {
				self.action?()
			}
		} label: {
			Group {
				Image(systemName: self.icon.systemName)
					.resizable()
					.aspectRatio(1, contentMode: .fit)
					.opacity(0.5)
					.frame(width: 20)
					.symbolVariant(.fill)
			}
				.frame(width: 45, height: 45)
				.overlay {
					if self.badgeNumber > 0 {
						ZStack {
							Circle()
								.foregroundColor(.red)
							Text("\(self.badgeNumber)")
								.foregroundColor(.white)
								.font(.caption)
								.dynamicTypeSize(...DynamicTypeSize.accessibility1)
						}
							.frame(width: 20, height: 20)
							.offset(x: 20, y: -20)
					}
				}
		}
			.tint(.primary)
	}
	
	init(icon: SFSymbol, sheetType: ShuttleTrackerSheetPresentationProvider.SheetType, badgeNumber: Int = 0) {
		self.icon = icon
		self.sheetType = sheetType
		self.action = nil
		self.badgeNumber = badgeNumber
	}
	
	init(icon: SFSymbol, badgeNumber: Int = 0, _ action: @escaping () -> Void) {
		self.icon = icon
		self.sheetType = nil
		self.action = action
		self.badgeNumber = badgeNumber
	}
	
}
