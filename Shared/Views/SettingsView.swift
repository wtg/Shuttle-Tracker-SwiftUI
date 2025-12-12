import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) var dismiss
  @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false

  var body: some View {
    NavigationStack {
      List {
        Section {
          Toggle("Developer Mode", isOn: $isDeveloperMode)
        } header: {
          Text("General")
        }
      }
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

#Preview {
  SettingsView()
}
