import SwiftUI

struct DeveloperModeView: View {
  let vehicles: VehicleInformationMap

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Developer Mode")
        .font(.headline)
        .padding(.bottom, 4)

      HStack {
        Text("Active Shuttles:")
        Spacer()
        Text("\(vehicles.count)")
          .bold()
      }
      .font(.subheadline)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          if vehicles.isEmpty {
            Text("No active shuttles")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            ForEach(Array(vehicles.values.sorted(by: { $0.id < $1.id })), id: \.id) { vehicle in
              VStack(alignment: .leading, spacing: 2) {
                HStack {
                  Text(vehicle.name)
                    .bold()
                  Spacer()
                  Text(vehicle.routeName ?? "N/A")
                    .foregroundStyle(.secondary)
                }
                HStack {
                  Text("Speed: \(String(format: "%.1f", vehicle.speedMph)) mph")
                  Spacer()
                  Text("Heading: \(Int(vehicle.headingDegrees))°")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
              }
              .padding(.vertical, 4)
              .padding(.horizontal, 8)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(8)
            }
          }
        }
      }
      .frame(maxHeight: 200)
    }
    .padding()
    .background(.ultraThinMaterial)
    .cornerRadius(16)
    .shadow(radius: 10)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    )
    .frame(width: 250)
  }
}

extension VehicleLocationData {

  // Changing approach slightly in the view code above to use what's available.
  var id: String { name }  // Using name as ID for now since key is usually name or id.
}

#Preview {
  DeveloperModeView(vehicles: [:])
}
