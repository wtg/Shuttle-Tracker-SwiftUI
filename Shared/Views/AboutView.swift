import SwiftUI

struct AboutView: View {
  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Header
        VStack(spacing: 8) {
          Text("© 2025 SHUBBLE")
            .font(.headline)
            .fontWeight(.bold)

          Text("an RCOS Project")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text("supported by the Student Senate Web Technologies Group (WTG)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }

        Divider()

        // Taglines
        VStack(spacing: 12) {
          Text("Making Shuttles Accountable, Predictable, Reliable")
            .font(.title3)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)

          Text("Track RPI shuttles in real time and view schedules seamlessly with Shubble")
            .font(.body)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)

        Divider()

        // Description and Links
        VStack(spacing: 16) {
          Text(
            "Shubble is an open source project under the Rensselaer Center for Open Source (RCOS)."
          )
          .font(.callout)
          .multilineTextAlignment(.center)

          Text("Have an idea to improve it? Contributions are welcome!")
            .font(.callout)
            .multilineTextAlignment(.center)

          if let url = URL(string: "https://github.com/wtg/shubble") {
            Link("Visit our Github Repository to learn more.", destination: url)
              .font(.headline)
              .foregroundStyle(.blue)
          }
        }
        .padding(.horizontal)

        Spacer()
      }
      .padding()
    }
    .navigationTitle("About")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    AboutView()
  }
}
