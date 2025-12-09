//
//  ScheduleView.swift
//  Shuttle Tracker
//
//  Created by RS on 12/5/25.
//

import SwiftUI

struct ScheduleView: View {
    @Environment(\.scenePhase) var scenePhase
    @State private var allSchedules: AggregatedSchedule?
    @State private var schedule: [String: [String]]?
    @State private var routes: ShuttleRouteData?
    @State private var isLoading = true
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading Schedule...")
                } else if let error = error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else if let schedule = schedule, let routes = routes {
                    List {
                        ForEach(schedule.keys.sorted(), id: \.self) { routeName in
                            Section(header: Text(routeName)) {
                                if let routeData = routes[routeName] {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack {
                                            ForEach(routeData.stops, id: \.self) { stopKey in
                                                if let stopName = routeData.stopDetails[stopKey]?.name {
                                                    Text(stopName)
                                                        .padding(8)
                                                        .background(Color.gray.opacity(0.2))
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                if let times = schedule[routeName] {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))]) {
                                        ForEach(times, id: \.self) { time in
                                            Text(time)
                                                .font(.caption)
                                                .padding(4)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Text("No schedule data available.")
                }
            }
            .navigationTitle("Shuttle Schedule")
            .task {
                await loadData()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    updateScheduleForCurrentDay()
                }
            }
        }
    }
    
    private func loadData() async {
        do {
            async let fetchedSchedule = API.shared.fetch(AggregatedSchedule.self, endpoint: "/aggregated-schedule")
            async let fetchedRoutes = API.shared.fetch(ShuttleRouteData.self, endpoint: "/routes")
            
            self.allSchedules = try await fetchedSchedule
            self.routes = try await fetchedRoutes
            
            updateScheduleForCurrentDay()
            
            self.isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
    
    private func updateScheduleForCurrentDay() {
        guard let allSchedules = allSchedules else { return }
        
        // Determine current day index (0 = Sunday, 1 = Monday, ..., 6 = Saturday)
        let weekday = Calendar.current.component(.weekday, from: Date())
        let index = weekday - 1
        
        if index < allSchedules.count {
            self.schedule = allSchedules[index]
        } else {
            self.schedule = allSchedules.first // Fallback
        }
    }
}

#Preview {
    ScheduleView()
}
