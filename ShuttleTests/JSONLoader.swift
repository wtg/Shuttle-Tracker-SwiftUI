import Foundation
@testable import ShuttleTrackerApp

enum JSONLoader {
    static func loadFile(named name: String) throws -> Data {
        let bundle = Bundle(for: MockURLProtocol.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            fatalError("Could not find \(name).json in the test bundle.")
        }
        return try Data(contentsOf: url)
    }
}
