import Foundation

private let scheduleTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
}()

extension String {
    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoStandardFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // for parsing ISO-8601 strings, with or without fractinal seconds, into a Date object
    var isoTimeToDate: Date? {
        return String.isoFractionalFormatter.date(from: self) ?? String.isoStandardFormatter.date(from: self)
    }

    // for parsing strings like "12:30 AM" that come from the schedule endpoint
    var simpleTimeToDate: Date? {
        return scheduleTimeFormatter.date(from: self)
    }

    // parses the ISO string and returns a formatted time like "12:30 AM", or "—" if invalid
    var formattedTime: String {
        guard let date = self.isoTimeToDate else { return "—" }
        return date.formattedTime
    }
}

extension Date {
    // formatting into a time string
    var formattedTime: String {
        return scheduleTimeFormatter.string(from: self)
    }
}
