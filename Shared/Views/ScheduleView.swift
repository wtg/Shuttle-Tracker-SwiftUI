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
    
    // Day and route selection
    @State private var selectedDay: Int = Calendar.current.component(.weekday, from: Date()) - 1
    @State private var selectedRoute: String?
    
    // Timer to refresh display as time passes
    @State private var refreshTrigger = false
    @State private var refreshTimer: Timer?
    
    private let daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading Schedule...")
                } else if let error = error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else if let schedule = schedule, let routes = routes {
                    VStack(spacing: 0) {
                        // Day and Route Pickers
                        HStack {
                            Picker("Day", selection: $selectedDay) {
                                ForEach(0..<7, id: \.self) { index in
                                    Text(daysOfWeek[index]).tag(index)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.primary)
                            
                            if let routeNames = availableRoutes {
                                Picker("Route", selection: $selectedRoute) {
                                    ForEach(routeNames, id: \.self) { route in
                                        Text(route).tag(route as String?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.primary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Schedule content
                        if let currentRoute = selectedRoute,
                           let routeData = routes[currentRoute],
                           let times = schedule[currentRoute] {
                            scheduleList(routeData: routeData, times: times)
                        } else {
                            ContentUnavailableView("No Schedule", systemImage: "calendar.badge.exclamationmark", description: Text("No schedule available for this selection."))
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
            .onAppear {
                // Start timer to refresh display every 30 seconds
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
                    refreshTrigger.toggle()
                }
            }
            .onDisappear {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    updateScheduleForSelectedDay()
                    refreshTrigger.toggle()
                }
            }
            .onChange(of: selectedDay) { _, _ in
                updateScheduleForSelectedDay()
            }
            // This triggers a re-render when refreshTrigger changes
            .id(refreshTrigger)
        }
    }
    
    private var availableRoutes: [String]? {
        schedule?.keys.sorted()
    }
    
    @ViewBuilder
    private func scheduleList(routeData: RouteDirectionData, times: [String]) -> some View {
        let sortedTimes = sortTimesByRelevance(times)
        
        List {
            // Stop names header
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(routeData.stops, id: \.self) { stopKey in
                            if let stopName = routeData.stopDetails[stopKey]?.name {
                                Text(stopName)
                                    .font(.caption)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            } header: {
                Text("Stops")
            }
            
            // Upcoming times
            if sortedTimes.justDeparted != nil || !sortedTimes.upcoming.isEmpty {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        // Show just departed time first with different styling
                        if let justDeparted = sortedTimes.justDeparted {
                            Text(justDeparted)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.25))
                                .foregroundStyle(.secondary)
                                .cornerRadius(6)
                        }
                        
                        // Then show upcoming times
                        ForEach(sortedTimes.upcoming, id: \.self) { time in
                            Text(time)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.15))
                                .cornerRadius(6)
                        }
                    }
                } header: {
                    Text("Upcoming")
                }
            }
            
            // Expired times (only show on today's schedule)
            if isToday && !sortedTimes.expired.isEmpty {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(sortedTimes.expired, id: \.self) { time in
                            Text(time)
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.15))
                                .foregroundStyle(.secondary)
                                .cornerRadius(6)
                        }
                    }
                } header: {
                    Text("Earlier Today")
                }
            }
        }
    }
    
    private var isToday: Bool {
        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1
        return selectedDay == todayIndex
    }
    
    private func sortTimesByRelevance(_ times: [String]) -> (upcoming: [String], expired: [String], justDeparted: String?) {
        // If not viewing today, all times are "upcoming" in their original order
        guard isToday else {
            return (upcoming: times, expired: [], justDeparted: nil)
        }
        
        let now = Date()
        
        // Since times are pre-sorted chronologically by the API (with 12 AM at end = midnight),
        // find the first time that hasn't passed yet and use it as the pivot
        var pivotIndex = times.count // Default: all expired
        
        for (index, time) in times.enumerated() {
            if let date = parseTime(time), date > now {
                pivotIndex = index
                break
            }
        }
        
        // Everything before pivot is expired, everything from pivot onwards is upcoming
        // The last expired time is "just departed"
        let justDeparted = pivotIndex > 0 ? times[pivotIndex - 1] : nil
        let expired = pivotIndex > 1 ? Array(times[0..<(pivotIndex - 1)]) : []
        let upcoming = Array(times[pivotIndex...])
        
        return (upcoming: upcoming, expired: expired, justDeparted: justDeparted)
    }
    
    private func parseTime(_ timeString: String) -> Date? {
        // Parse time like "7:00 AM" or "10:30 PM"
        let trimmed = timeString.trimmingCharacters(in: .whitespaces)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if let time = formatter.date(from: trimmed) {
            let calendar = Calendar.current
            let now = Date()
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: now)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            dateComponents.second = 0
            return calendar.date(from: dateComponents)
        }
        
        return nil
    }
    
    private func loadData() async {
        do {
            async let fetchedSchedule = API.shared.fetch(AggregatedSchedule.self, endpoint: "/aggregated-schedule")
            async let fetchedRoutes = API.shared.fetch(ShuttleRouteData.self, endpoint: "/routes")
            
            self.allSchedules = try await fetchedSchedule
            self.routes = try await fetchedRoutes
            
            updateScheduleForSelectedDay()
            
            self.isLoading = false
        } catch {
            self.error = error.localizedDescription
            self.isLoading = false
        }
    }
    
    private func updateScheduleForSelectedDay() {
        guard let allSchedules = allSchedules else { return }
        
        if selectedDay < allSchedules.count {
            self.schedule = allSchedules[selectedDay]
        } else {
            self.schedule = allSchedules.first
        }
        
        // Set default route if none selected or current not available
        if selectedRoute == nil || !(schedule?.keys.contains(selectedRoute!) ?? false) {
            selectedRoute = schedule?.keys.sorted().first
        }
    }
}

#Preview {
    ScheduleView()
}
