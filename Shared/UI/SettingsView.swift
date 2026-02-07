import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
    @State private var showingCacheAlert = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Developer Mode", isOn: $isDeveloperMode)
                } header: {
                    Text("General")
                }

                Section {
                    Button(role: .destructive) {
                        clearCache()
                    } label: {
                        Text("Clear Data Cache")
                    }
                } header: {
                    Text("Troubleshooting")
                } footer: {
                    Text("Use this if schedules or routes appear incorrect.")
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
            .alert("Cache Cleared", isPresented: $showingCacheAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Route and schedule data has been reset. It will re-download automatically.")
            }
        }
    }

    private func clearCache() {
        CacheManager.shared.clear(key: .routes)
        CacheManager.shared.clear(key: .aggregatedSchedule)
        Task {
            await container.routeService.refreshData()
        }
        showingCacheAlert = true
    }
}

#Preview {
    SettingsView()
        .environmentObject(DependencyContainer.preview)
}
