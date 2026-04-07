import SwiftUI

struct DeveloperSettingsView: View {
    @EnvironmentObject var container: DependencyContainer
    @AppStorage("useMockData") private var useMockData: Bool = false
    @AppStorage("mockScenario") private var mockScenario: String = "standard"
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = true

    var body: some View {
        Form {
            Section(header: Text("Mock Data Integration")) {
                Toggle("Use Mock Data", isOn: $useMockData)
                    .onChange(of: useMockData) { _, _ in refreshMockData() }

                if useMockData {
                    Picker("Scenario", selection: $mockScenario) {
                        Text("Standard (4 Shuttles)").tag("standard")
                        Text("Empty (0 Shuttles)").tag("empty")
                        Text("Clustered (Union)").tag("clustered")
                    }
                    .onChange(of: mockScenario) { _, _ in refreshMockData() }
                }
            }

            Section(header: Text("App State")) {
                Button(role: .destructive) {
                    hasSeenOnboarding = false
                } label: {
                    Text("Reset Onboarding Flag")
                }
            }
        }
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func refreshMockData() {
        Task {
            await container.vehicleService.refreshVehicles(isManualRefresh: true)
        }
    }
}
