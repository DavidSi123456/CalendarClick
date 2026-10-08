import Foundation

enum CompletionMark {
    static let prefix = "✓ "
    static func isCompleted(_ title: String) -> Bool { title.hasPrefix(prefix) }
    static func plainTitle(_ title: String) -> String {
        isCompleted(title) ? String(title.dropFirst(prefix.count)) : title
    }
    static func setting(_ completed: Bool, title: String) -> String {
        completed ? (isCompleted(title) ? title : prefix + title) : plainTitle(title)
    }
}

struct EventHint {
    let titles: [String]
    let calendarName: String
    let date: Date
    let hasExactTime: Bool
}

struct ParsedEventDate {
    let date: Date
    let hasExactTime: Bool
}

enum EventDateParser {
    // Calendar exposes localized dates through Accessibility. Never guess today's date.
    static func parse(_ text: String, timeZone: TimeZone = .current) -> ParsedEventDate? {
        let cleaned = text.unicodeScalars.filter {
            ![0x2066, 0x2067, 0x2068, 0x2069, 0x200E, 0x200F].contains(Int($0.value))
        }.map(String.init).joined()
        let patterns = [
            #"(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日(?:\s*(\d{1,2}):(\d{2}))?"#,
            #"(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2}))?"#,
            #"(\d{1,2})/(\d{1,2})/(\d{2,4})(?:,?\s*(\d{1,2}):(\d{2})\s*(AM|PM)?)?"#
        ]
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) else { continue }
            func group(_ n: Int) -> String? {
                guard n < match.numberOfRanges, let range = Range(match.range(at: n), in: cleaned) else { return nil }
                return String(cleaned[range])
            }
            guard let a = group(1).flatMap(Int.init), let b = group(2).flatMap(Int.init),
                  let c = group(3).flatMap(Int.init) else { continue }
            let year = index == 2 ? (c < 100 ? 2000 + c : c) : a
            let month = index == 2 ? a : b
            let day = index == 2 ? b : c
            var hour = group(4).flatMap(Int.init) ?? 0
            let minute = group(5).flatMap(Int.init) ?? 0
            if let meridiem = group(6)?.uppercased() {
                hour = hour % 12 + (meridiem == "PM" ? 12 : 0)
            }
            guard (1...12).contains(month), (1...31).contains(day), (0...23).contains(hour), (0...59).contains(minute) else { continue }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let components = DateComponents(timeZone: timeZone, year: year, month: month, day: day, hour: hour, minute: minute)
            guard let date = calendar.date(from: components) else { continue }
            let check = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            guard check.year == year, check.month == month, check.day == day, check.hour == hour, check.minute == minute else { continue }
            return ParsedEventDate(date: date, hasExactTime: group(4) != nil)
        }
        return nil
    }
}

struct EventRecord: Identifiable {
    let eventID: String
    let externalID: String?
    let calendarID: String
    let calendarName: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let recurring: Bool
    let blockedReason: String?
    var id: String { calendarID + ":" + eventID + ":" + String(start.timeIntervalSince1970) }
    var completed: Bool { CompletionMark.isCompleted(title) }
    var displayTitle: String { CompletionMark.plainTitle(title) }

    func matches(_ hint: EventHint, calendar: Calendar = .current) -> Bool {
        guard calendarName == hint.calendarName,
              hint.titles.contains(where: { CompletionMark.plainTitle($0) == displayTitle }) else { return false }
        if hint.hasExactTime { return abs(start.timeIntervalSince(hint.date)) < 60 }
        // Multi-day all-day events may be clicked on a later visible day.
        let day = calendar.startOfDay(for: hint.date)
        return calendar.isDate(start, inSameDayAs: hint.date) ||
            (allDay && start <= day && end > day)
    }
}
