import SwiftUI
import CoreLocation

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    var locationManager: LocationManager

    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    @State private var currentPage = 0

    private let totalPages = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                featuresPage.tag(1)
                appearancePage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Page indicator + button
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Button(action: {
                    if currentPage < totalPages - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        hasSeenOnboarding = true
                    }
                }) {
                    Text(currentPage == totalPages - 1 ? "Get Started" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .cornerRadius(16)

                if currentPage < totalPages - 1 {
                    Button("Skip") {
                        hasSeenOnboarding = true
                    }
                    .foregroundStyle(.secondary)
                } else {
                    // Invisible placeholder to keep layout stable
                    Text(" ")
                        .font(.body)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var locationButtonLabel: String {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return "Open Settings"
        case .authorizedAlways, .authorizedWhenInUse:
            return "Location Enabled"
        default:
            return "Enable Location"
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bus.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Shuttle Tracker")
                .font(.largeTitle)
                .bold()
            Text("Track campus shuttles in real time, view schedules, and never miss your ride.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var featuresPage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Live Location")
                .font(.largeTitle)
                .bold()
            Text("We use your location to center the map and show accurate arrival times for nearby stops.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                locationManager.requestAuthorization()
            }) {
                Label(locationButtonLabel, systemImage: "location.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .padding(.top, 8)

            Spacer()
        }
    }

    private var appearancePage: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Appearance")
                .font(.largeTitle)
                .bold()
            Text("Choose how you'd like the app to look.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                AppearanceOptionButton(
                    title: "System Default",
                    icon: "gear",
                    isSelected: appearanceMode == "system",
                    action: { appearanceMode = "system" }
                )
                AppearanceOptionButton(
                    title: "Light",
                    icon: "sun.max.fill",
                    isSelected: appearanceMode == "light",
                    action: { appearanceMode = "light" }
                )
                AppearanceOptionButton(
                    title: "Dark",
                    icon: "moon.fill",
                    isSelected: appearanceMode == "dark",
                    action: { appearanceMode = "dark" }
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()
        }
    }
}

struct AppearanceOptionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.08))
            .foregroundStyle(.primary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    OnboardingView(
        hasSeenOnboarding: .constant(false),
        locationManager: DependencyContainer.preview.locationManager
    )
}
