import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) var dismiss

  var body: some View {
    NavigationStack {
      List {
        // Empty for now
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
