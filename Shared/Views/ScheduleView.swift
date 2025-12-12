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
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 10) {
                ForEach(directions, id: \.self) { direction in
                  Button(action: {
                    selectedDirection = direction
                  }) {
                    Text(direction.capitalized + " Route")
                      .font(.subheadline)
                      .padding(.vertical, 6)
                      .padding(.horizontal, 12)
                      .background(
                        selectedDirection == direction ? Color.blue.opacity(0.2) : Color.clear
                      )
                      .foregroundStyle(selectedDirection == direction ? Color.blue : Color.primary)
                      .overlay(
                        Capsule()
                          .stroke(
                            selectedDirection == direction
                              ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
                      )
                      .clipShape(Capsule())
                  }
                }
              }
              .padding(.horizontal)
              .padding(.vertical, 8)
            }

            Divider()

            // Times List
            if let currentDirection = selectedDirection {
              let times = getConsolidatedTimes(
                for: currentDirection, day: selectedDay, data: scheduleData)

              if times.isEmpty {
                ContentUnavailableView(
                  "No times available", systemImage: "clock.badge.exclamationmark")
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
                        .background(Color.secondary.opacity(0.15))
                        .foregroundStyle(.secondary)
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

    for (busName, times) in scheduleMap {
      for timePair in times {
        if timePair.count > 1 {
          let timeStr = timePair[0]
          let dirStr = timePair[1]

          if dirStr == direction {
            // Create a date for sorting. We only care about time.
            if let date = dateFormatter.date(from: timeStr) {
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

    // Sort chronologically
    return consolidatedTimes.sorted { $0.date < $1.date }
  }
}

#Preview {
  ScheduleView()
}
