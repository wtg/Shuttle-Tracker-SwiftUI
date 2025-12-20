//
//  ScheduleAndETA.swift
//  iOS
//
//  Created by Jordan Krishnayah on 9/30/25.
//

import SwiftUI

struct ScheduleAndETA: View {
  @State var showSheet: Bool = false
  var body: some View {
    VStack(spacing: 8) {
      Spacer()

      // Shuttle ETA Summary
      VStack(spacing: 4) {
        Text("Arrival Times")
          .font(.headline)
          .foregroundStyle(Color.red)
        Text("View Schedule")
          .font(.system(size: 36, weight: .bold))
          .foregroundStyle(.primary)
      }
      .frame(maxWidth: .infinity)
      .padding(.bottom, 12)
      .padding(.vertical, 16)
      .background(.ultraThinMaterial)
      .cornerRadius(20)
      .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(Color.white.opacity(0.3), lineWidth: 1)
      )
      .padding(.horizontal, 24)
      .padding(.bottom, 16)

    }.onTapGesture {
      showSheet = true
    }
    .sheet(isPresented: $showSheet) {
      ScheduleView()
        .presentationDetents([.medium, .large])
    }
  }
}

#Preview {
  ScheduleAndETA()
}
