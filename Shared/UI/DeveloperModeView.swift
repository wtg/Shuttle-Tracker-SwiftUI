import SwiftUI
import CoreLocation

struct DeveloperModeView: View {
    let vehicles: [VehicleLocationData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Developer Mode")
                .font(.headline)

            HStack {
                Text("Active Shuttles:")
                Spacer()
                Text("\(vehicles.count)")
                    .bold()
            }
            .font(.subheadline)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if vehicles.isEmpty {
                        Text("No active shuttles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(vehicles.sorted(by: { $0.name < $1.name })) { vehicle in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(vehicle.name)
                                        .font(.subheadline)
                                        .bold()
                                    Spacer()
                                    Text(vehicle.routeName)
                                        .foregroundStyle(.secondary)
                                }

                                Divider()

                                Group {
                                    Text("Lat: \(vehicle.latitude)")
                                    Text("Lon: \(vehicle.longitude)")
                                    Text("Formatted: \(vehicle.formattedLocation)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Group {
                                    Text("Speed: \(String(format: "%.1f", vehicle.speedMph)) mph")
                                    Text("Heading: \(Int(vehicle.headingDegrees))°")
                                    Text("At Stop: \(vehicle.isAtStop ? "Yes" : "No")")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Group {

                                    Text("Current Stop: \(vehicle.currentStop ?? "None")")

                                    HStack(spacing: 4) {
                                        Image(systemName: "chevron.down").font(.system(size: 8)).fontWeight(.bold)
                                        Image(systemName: "chevron.down").font(.system(size: 8)).fontWeight(.bold)
                                        Image(systemName: "chevron.down").font(.system(size: 8)).fontWeight(.bold)
                                        Text("ETA Times").font(.caption).bold()
                                        Image(systemName: "chevron.down").font(.system(size: 8)).fontWeight(.bold)
                                        Image(systemName: "chevron.down").font(.system(size: 8)).fontWeight(.bold)
                                        Image(systemName: "chevron.down").font(.system(size: 8)).fontWeight(.bold)
                                    }

                                    if vehicle.stopEtaTimes.isEmpty {
                                        Text("No ETA data")
                                            .italic()
                                    } else {
                                        ForEach(vehicle.stopEtaTimes.sorted(by: { $0.key < $1.key }), id: \.key) { stop, dateStr in
                                            Text("\(stop): \(dateStr.formattedTime)")
                                        }
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                Text("Timestamp: \(vehicle.timestamp.formattedTime)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .frame(width: 300)
    }
}
