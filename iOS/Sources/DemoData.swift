import Foundation

enum AgendaDemo {
    static let calendars = [
        AgendaCalendar(id: "demo-work", name: "工作", account: "iCloud", tint: .teal, allowsEditing: true, isLocal: false),
        AgendaCalendar(id: "demo-personal", name: "个人", account: "iCloud",
                       tint: CalendarTint(red: 0.60, green: 0.43, blue: 0.77), allowsEditing: true, isLocal: false),
        AgendaCalendar(id: "demo-subscription", name: "订阅日历", account: "订阅",
                       tint: CalendarTint(red: 0.78, green: 0.56, blue: 0.19), allowsEditing: false, isLocal: false)
    ]

    static func events(on day: Date) -> [AgendaEvent] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        func event(_ id: String, _ title: String, hour: Int, duration: Int = 60,
                   choice: Int = 0, allDay: Bool = false, recurring: Bool = false,
                   attendees: Bool = false) -> AgendaEvent {
            let source = calendars[choice]
            let time = calendar.date(byAdding: .hour, value: hour, to: start)!
            let end = allDay ? calendar.date(byAdding: .day, value: 1, to: start)! : time.addingTimeInterval(Double(duration * 60))
            return AgendaEvent(eventID: id, externalID: "demo-" + id, calendarID: source.id,
                               calendarName: source.name, account: source.account, tint: source.tint,
                               title: title, start: time, end: end, allDay: allDay, recurring: recurring,
                               allowsEditing: source.allowsEditing, hasAttendees: attendees, canceled: false,
                               location: "")
        }
        return AgendaOrder.sorted([
            event("photos", "✓ 整理本周照片", hour: 0, choice: 1, allDay: true),
            event("project", "整理项目资料", hour: 9),
            event("reading", "阅读与学习", hour: 13, choice: 1, recurring: true),
            event("meeting", "团队会议", hour: 15, duration: 45, attendees: true)
        ])
    }
}
