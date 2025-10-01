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
        VStack( spacing: 8 ) {
            Spacer()
            
            
            // Shuttle ETA Summary
            VStack(spacing: 4) {
                Text("Blitman Shuttle")
                    .font(.headline)
                    .foregroundStyle(Color.red)
                Text("5 minutes")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.primary)
                Text("View full schedule").font(.system(size: 12, weight: .bold)).foregroundStyle(.tertiary)
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
            Text("The schedule of the shuttle can be showed here!")
                // swipe up halfway, and lets the user swipe up even MORE. if u want it to expand fully just delete line below
                .presentationDetents([.medium, .large])
            
        }
    }
}

#Preview {
    ScheduleAndETA()
}
