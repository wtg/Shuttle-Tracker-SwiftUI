import SwiftUI

struct SettingsView: View {
  @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          Toggle("Developer Mode", isOn: $isDeveloperMode)
        } header: {
          Text("General")
        }

        Section {
          NavigationLink("About") {
            AboutView()
          }
        } header: {
          Text("Info")
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview {
  SettingsView()
}
