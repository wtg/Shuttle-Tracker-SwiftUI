import SwiftUI

struct ScheduleView: View {
  @Environment(\.dismiss) var dismiss
  @State private var scheduleData: ScheduleData?
  @State private var selectedDay: DayOfWeek = .monday
  @State private var selectedDirection: String?

  enum DayOfWeek: String, CaseIterable, Identifiable {
    case monday = "MONDAY"
    case tuesday = "TUESDAY"
    case wednesday = "WEDNESDAY"
    case thursday = "THURSDAY"
    case friday = "FRIDAY"
    case saturday = "SATURDAY"
    case sunday = "SUNDAY"

    var id: String { rawValue }

    var displayName: String {
      switch self {
      case .monday: return "Mon"
      case .tuesday: return "Tue"
      case .wednesday: return "Wed"
      case .thursday: return "Thu"
      case .friday: return "Fri"
      case .saturday: return "Sat"
      case .sunday: return "Sun"
      }
    }

    static func from(date: Date) -> DayOfWeek {
      let weekday = Calendar.current.component(.weekday, from: date)
      switch weekday {
      case 2: return .monday
      case 3: return .tuesday
      case 4: return .wednesday
      case 5: return .thursday
      case 6: return .friday
      case 7: return .saturday
      case 1: return .sunday
      default: return .monday
      }
    }
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Day Picker
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(DayOfWeek.allCases) { day in
              Button(action: {
                selectedDay = day
                // Reset direction if the new day doesn't have the current selection
                if let data = scheduleData {
                  let available = availableDirections(for: day, data: data)
                  if let current = selectedDirection, !available.contains(current) {
                    selectedDirection = available.first
                  } else if selectedDirection == nil {
                    selectedDirection = available.first
                  }
                }
              }) {
                Text(day.displayName)
                  .fontWeight(selectedDay == day ? .bold : .regular)
                  .padding(.vertical, 8)
                  .padding(.horizontal, 16)
                  .background(selectedDay == day ? Color.accentColor : Color.secondary.opacity(0.1))
                  .foregroundStyle(selectedDay == day ? .white : .primary)
                  .clipShape(Capsule())
              }
            }
          }
          .padding()
        }
        .background(.ultraThinMaterial)

        if let scheduleData = scheduleData {
          // Route (Direction) Picker
          let directions = availableDirections(for: selectedDay, data: scheduleData)

          if !directions.isEmpty {
            HStack(spacing: 10) {
              ForEach(directions, id: \.self) { direction in
                Button(action: {
                  selectedDirection = direction
                }) {
                  Text(direction.capitalized + " Route")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                      selectedDirection == direction ? Color.blue.opacity(0.2) : Color.clear
                    )
                    .foregroundStyle(selectedDirection == direction ? Color.blue : Color.primary)
                    .overlay(
                      RoundedRectangle(cornerRadius: 10)
                        .stroke(
                          selectedDirection == direction
                            ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
              }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Times List
            if let currentDirection = selectedDirection {
              let times = getConsolidatedTimes(
                for: currentDirection, day: selectedDay, data: scheduleData)

              if times.isEmpty {
                ContentUnavailableView(
                  "No upcoming shuttles today", systemImage: "clock.badge.exclamationmark")
              } else {
                List {
                  ForEach(times, id: \.self) { timeInfo in
                    HStack {
                      Text(timeInfo.time)
                        .font(.body.monospacedDigit())
                      Spacer()

                      // Tag showing the bus name
                      Text(timeInfo.busName)
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(busColor(for: timeInfo.busName).opacity(0.15))
                        .foregroundStyle(busColor(for: timeInfo.busName))
                        .cornerRadius(4)
                    }
                  }
                }
                .listStyle(.plain)
              }
            } else {
              ContentUnavailableView("Select a Route", systemImage: "bus")
            }
          } else {
            ContentUnavailableView("No shuttles running", systemImage: "moon.zzz.fill")
          }
        } else {
          ProgressView()
            .frame(maxHeight: .infinity)
        }
      }
      .navigationTitle("Schedule")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .onAppear {
      // Auto-select today
      selectedDay = DayOfWeek.from(date: Date())
      fetchSchedule()
    }
  }

  private func fetchSchedule() {
    Task {
      do {
        let data = try await API.shared.fetch(ScheduleData.self, endpoint: "schedule")
        await MainActor.run {
          self.scheduleData = data
          // Auto-select first available direction
          if let firstDirection = availableDirections(for: selectedDay, data: data).first {
            self.selectedDirection = firstDirection
          }
        }
      } catch {
        print("Error fetching schedule: \(error)")
      }
    }
  }

  // MARK: - Data Helpers

  private func getScheduleType(for day: DayOfWeek, data: ScheduleData) -> String {
    switch day {
    case .monday: return data.monday
    case .tuesday: return data.tuesday
    case .wednesday: return data.wednesday
    case .thursday: return data.thursday
    case .friday: return data.friday
    case .saturday: return data.saturday
    case .sunday: return data.sunday
    }
  }

  private func availableDirections(for day: DayOfWeek, data: ScheduleData) -> [String] {
    let type = getScheduleType(for: day, data: data)
    let scheduleMap: [String: [[String]]]

    switch type {
    case "weekday": scheduleMap = data.weekday
    case "saturday": scheduleMap = data.saturdaySchedule
    case "sunday": scheduleMap = data.sundaySchedule
    default: return []
    }

    // Collect all directions found in the data
    var directions = Set<String>()

    for (_, times) in scheduleMap {
      for timePair in times {
        if timePair.count > 1 {
          directions.insert(timePair[1])
        }
      }
    }

    return directions.sorted()  // "NORTH", "WEST"
  }

  struct TimeInfo: Hashable {
    let time: String
    let direction: String
    let busName: String
    let date: Date
  }

  private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  private func getConsolidatedTimes(for direction: String, day: DayOfWeek, data: ScheduleData)
    -> [TimeInfo]
  {
    let type = getScheduleType(for: day, data: data)
    let scheduleMap: [String: [[String]]]

    switch type {
    case "weekday": scheduleMap = data.weekday
    case "saturday": scheduleMap = data.saturdaySchedule
    case "sunday": scheduleMap = data.sundaySchedule
    default: return []
    }

    var consolidatedTimes: [TimeInfo] = []
    let now = Date()
    let isToday = day == DayOfWeek.from(date: now)
    let calendar = Calendar.current

    // Setup comparison dates for "Upcoming" logic
    let currentComponents = calendar.dateComponents([.hour, .minute], from: now)
    let currentMinutes = (currentComponents.hour ?? 0) * 60 + (currentComponents.minute ?? 0)

    for (busName, times) in scheduleMap {
      for timePair in times {
        if timePair.count > 1 {
          let timeStr = timePair[0]
          let dirStr = timePair[1]

          if dirStr == direction {
            if let date = dateFormatter.date(from: timeStr) {
              // Use date components for comparison to ignore the 2000 year of DateFormatter
              let itemComponents = calendar.dateComponents([.hour, .minute], from: date)
              let itemMinutes = (itemComponents.hour ?? 0) * 60 + (itemComponents.minute ?? 0)

              // Check for "upcoming" if it is today
              // We treat 12:00 AM - 4:00 AM as "late night" (next day technically)
              // Ideally, we'd have better logic, but for now:
              // If `isToday` and time is passed, skip it.
              // BUT wait, if it's 11 PM and next bus is 12 AM (0 minutes), 0 < 1380. It looks like past.
              // However, 12 AM is usually stored as next day.
              // Let's assume strict daily chronological filtering.
              // If I am at 2 PM (14:00), I see 2:15 PM and later.

              var shouldInclude = true
              if isToday {
                // Simple comparison: if itemMinutes < currentMinutes, it's past.
                // CAVEAT: 12:xx AM (0 minutes) vs 11:xx PM (1380 minutes).
                // If bus is 12:00 AM and now is 11:00 PM.
                // 0 < 1380. It is hidden. This is technically correct (00:00 happened 23 hours ago).
                // The "Next day" 12:00 AM is technically tomorrow's schedule.
                // So strictly filtering for "upcoming today" works fine.

                if itemMinutes < currentMinutes {
                  shouldInclude = false
                }
              }

              if shouldInclude {
                let info = TimeInfo(
                  time: timeStr,
                  direction: dirStr,
                  busName: busName,
                  date: date
                )
                consolidatedTimes.append(info)
              }
            }
          }
        }
      }
    }

    // Sort chronologically
    return consolidatedTimes.sorted { $0.date < $1.date }
  }

  private func busColor(for name: String) -> Color {
    let normalized = name.lowercased()
    if normalized.contains("west") { return .blue }
    if normalized.contains("north") { return .red }
    if normalized.contains("1") { return .orange }
    if normalized.contains("2") { return .green }
    return .gray
  }
}

#Preview {
  ScheduleView()
}
