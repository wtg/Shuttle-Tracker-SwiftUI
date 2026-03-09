import Foundation
import Combine

@MainActor
class ScheduleService: ObservableObject {
    @Published var scheduleData: ScheduleData?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let client = APIClient.shared

    func fetchSchedule() async {
        guard scheduleData == nil else { return } // dont refetch if we have it
        self.isLoading = true
        do {
            let data = try await client.fetch(ScheduleData.self, endpoint: .schedule)
            self.scheduleData = data
            self.isLoading = false
        } catch {
            self.error = error
            self.isLoading = false
        }
    }
}
