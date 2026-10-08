import Foundation

struct CalendarTint: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    static let teal = CalendarTint(red: 0.09, green: 0.53, blue: 0.49)
}

struct AgendaCalendar: Identifiable {
    let id: String
    let name: String
    let account: String
    let tint: CalendarTint
    let allowsEditing: Bool
    let isLocal: Bool
}

struct AgendaEvent: Identifiable, Equatable {
    let eventID: String
    let externalID: String?
    let calendarID: String
    let calendarName: String
    let account: String
    let tint: CalendarTint
    var title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let recurring: Bool
    let allowsEditing: Bool
    let hasAttendees: Bool
    let canceled: Bool
    let location: String

    var id: String { calendarID + ":" + eventID + ":" + String(start.timeIntervalSince1970) }
    var completed: Bool { CompletionMark.isCompleted(title) }
    var displayTitle: String {
        let title = CompletionMark.plainTitle(title)
        return title.isEmpty ? "无标题日程" : title
    }
    var blockedReason: String? {
        if !allowsEditing { return "这个日历是只读的，不能修改日程。" }
        if hasAttendees { return "含参与者的会议暂不支持打勾，避免发送会议更新。" }
        if canceled { return "这个日程已取消。" }
        return nil
    }

    // Identifiers may change after account synchronization. Never match just by title
    // or by a recurring series ID: require the same calendar and occurrence time.
    func matchesOccurrence(_ other: AgendaEvent) -> Bool {
        let sameExternalID = externalID?.isEmpty == false && externalID == other.externalID
        return calendarID == other.calendarID && start == other.start &&
            (eventID == other.eventID || sameExternalID)
    }

    func isUnchanged(_ other: AgendaEvent) -> Bool {
        matchesOccurrence(other) && title == other.title && end == other.end && allDay == other.allDay
    }

    var timeDescription: String {
        let calendar = Calendar.current
        if allDay {
            let finalDay = end.addingTimeInterval(-1)
            if calendar.isDate(start, inSameDayAs: finalDay) { return "全天" }
            return Self.format(start, "M月d日") + " – " + Self.format(finalDay, "M月d日") + " · 全天"
        }
        let pattern = calendar.isDate(start, inSameDayAs: end) ? "HH:mm" : "M月d日 HH:mm"
        return Self.format(start, pattern) + " – " + Self.format(end, pattern)
    }

    static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

enum AgendaFilter: String, CaseIterable, Identifiable {
    case all = "全部", pending = "待完成", completed = "已完成"
    var id: String { rawValue }
    func includes(_ event: AgendaEvent) -> Bool {
        switch self {
        case .all: return true
        case .pending: return !event.completed
        case .completed: return event.completed
        }
    }
}

enum AgendaOrder {
    static func sorted(_ events: [AgendaEvent]) -> [AgendaEvent] {
        events.sorted {
            if $0.allDay != $1.allDay { return $0.allDay }
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.calendarName != $1.calendarName { return $0.calendarName < $1.calendarName }
            return $0.id < $1.id
        }
    }
}

struct AgendaData {
    let calendars: [AgendaCalendar]
    let events: [AgendaEvent]
}

enum AgendaError: LocalizedError {
    case noPermission, changed, blocked(String), invalidDate
    var errorDescription: String? {
        switch self {
        case .noPermission: return "需要日历完全访问权限。请到系统设置中允许日历访问。"
        case .changed: return "日程刚刚发生了变化，请刷新后再试。"
        case .blocked(let reason): return reason
        case .invalidDate: return "无法读取这个日期，请重新选择。"
        }
    }
}
