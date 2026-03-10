import SwiftUI

struct ScheduleView: View {
    @ObservedObject var viewModel: ScheduleViewModel

    init(viewModel: ScheduleViewModel) {
        _viewModel = ObservedObject(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Schedule")
                .font(.system(size: 32, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 16)

            Text("Times are based off of Union departure.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)

            dayPicker
            routePicker
            Divider()
            timesList
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            viewModel.loadData()
        }
    }

    private var dayPicker: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(DayOfWeek.allCases) { day in
                        Button(action: {
                            withAnimation {
                                viewModel.selectedDay = day
                                viewModel.updateDisplayedTimes() // trigger refresh
                            }
                        }) {
                            Text(day.displayName)
                                .fontWeight(viewModel.selectedDay == day ? .bold : .regular)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(viewModel.selectedDay == day ? Color.accentColor : Color.secondary.opacity(0.1))
                                .foregroundStyle(viewModel.selectedDay == day ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding()
            }
            .background(.ultraThinMaterial)
        }
        
        private var routePicker: some View {
            Group {
                let directions = viewModel.availableDirections
                if !directions.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(directions, id: \.self) { direction in
                            Button(action: {
                                viewModel.selectedDirection = direction
                                viewModel.updateDisplayedTimes()
                            }) {
                                Text(direction.capitalized + " Route")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        viewModel.selectedDirection == direction ? Color.blue.opacity(0.2) : Color.clear
                                    )
                                    .foregroundStyle(viewModel.selectedDirection == direction ? Color.blue : Color.primary)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(viewModel.selectedDirection == direction ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                } else {
                    // if data hasn't loaded yet
                    if viewModel.availableDirections.isEmpty {
                        EmptyView()
                    }
                }
            }
        }
        
        private var timesList: some View {
            Group {
                if viewModel.displayedTimes.isEmpty {
                    ContentUnavailableView("No upcoming shuttles", systemImage: "clock.badge.exclamationmark")
                } else {
                    List {
                        ForEach(viewModel.displayedTimes) { timeInfo in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(viewModel.getStops(for: timeInfo)) { stop in
                                        HStack {
                                            Rectangle()
                                                .fill(Color.forRoute(timeInfo.direction))
                                                .frame(width: 2)
                                                .padding(.vertical, 4)
                                            
                                            VStack(alignment: .leading) {
                                                Text(stop.name)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Text(stop.time)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.leading, 8)
                                            
                                            Spacer()
                                        }
                                        .padding(.leading, 4)
                                    }
                                }
                                .padding(.top, 8)
                                
                            } label: {
                                HStack {
                                    Text(timeInfo.time)
                                        .font(.body.monospacedDigit())
                                        .bold()
                                    Spacer()
                                    
                                    Text(timeInfo.busName)
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.forRoute(timeInfo.busName).opacity(0.15))
                                        .foregroundStyle(Color.forRoute(timeInfo.busName))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
    }
    
    
