import Foundation
import EventKit

final class CalendarService {
    private let queue = DispatchQueue(label: "calendar-check.event-store")
    private let store = EKEventStore()

    var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    func requestAccess(_ completion: @escaping (Result<Bool, Error>) -> Void) {
        store.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                if let error { completion(.failure(error)) } else { completion(.success(granted)) }
            }
        }
    }

    func findEvents(_ hint: EventHint, completion: @escaping (Result<[EventRecord], Error>) -> Void) {
        queue.async { [self] in
            guard hasAccess else { return deliver(.failure(ServiceError.noPermission), to: completion) }
            store.reset()
            let day = Calendar.current.startOfDay(for: hint.date)
            let end = Calendar.current.date(byAdding: .day, value: 1, to: day)!
            let calendars = store.calendars(for: .event).filter { $0.title == hint.calendarName }
            guard !calendars.isEmpty else { return deliver(.success([]), to: completion) }
            let predicate = store.predicateForEvents(withStart: day, end: end, calendars: calendars)
            let matches = store.events(matching: predicate).map(record).filter { $0.matches(hint) }
            let unique = Dictionary(matches.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            deliver(.success(unique.values.sorted { $0.start < $1.start }), to: completion)
        }
    }

    func setCompleted(_ completed: Bool, event chosen: EventRecord, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async { [self] in
            guard hasAccess else { return deliver(.failure(ServiceError.noPermission), to: completion) }
            store.reset()
            guard let calendar = store.calendar(withIdentifier: chosen.calendarID) else {
                return deliver(.failure(ServiceError.changed), to: completion)
            }
            let predicate = store.predicateForEvents(withStart: chosen.start.addingTimeInterval(-1),
                                                     end: chosen.start.addingTimeInterval(1), calendars: [calendar])
            let candidates = store.events(matching: predicate).filter { event in
                abs(event.startDate.timeIntervalSince(chosen.start)) < 1 &&
                (event.eventIdentifier == chosen.eventID ||
                 (chosen.externalID != nil && event.calendarItemExternalIdentifier == chosen.externalID))
            }
            guard candidates.count == 1, let event = candidates.first,
                  event.title == chosen.title, event.endDate == chosen.end else {
                return deliver(.failure(ServiceError.changed), to: completion)
            }
            if let reason = record(event).blockedReason { return deliver(.failure(ServiceError.blocked(reason)), to: completion) }
            let originalTitle = event.title ?? ""
            event.title = CompletionMark.setting(completed, title: originalTitle)
            do {
                // Save the fetched occurrence. Looking up a recurring series only by identifier
                // can return its first occurrence and mark the wrong day.
                try store.save(event, span: .thisEvent, commit: true)
                deliver(.success(completed ? "已完成，日历标题已加上 ✓" : "已取消完成，标题已恢复"), to: completion)
            } catch {
                event.title = originalTitle
                deliver(.failure(error), to: completion)
            }
        }
    }

    private func record(_ event: EKEvent) -> EventRecord {
        let reason: String?
        if !event.calendar.allowsContentModifications { reason = "这是只读日历，不能修改日程。" }
        else if event.hasAttendees { reason = "含参与者的会议暂不支持，避免改标题后发送会议更新。" }
        else { reason = nil }
        return EventRecord(eventID: event.eventIdentifier ?? event.calendarItemIdentifier,
                           externalID: event.calendarItemExternalIdentifier,
                           calendarID: event.calendar.calendarIdentifier, calendarName: event.calendar.title,
                           title: event.title ?? "", start: event.startDate, end: event.endDate,
                           allDay: event.isAllDay, recurring: event.hasRecurrenceRules || event.isDetached,
                           blockedReason: reason)
    }

    private func deliver<T>(_ result: Result<T, Error>, to completion: @escaping (Result<T, Error>) -> Void) {
        DispatchQueue.main.async { completion(result) }
    }
}

enum ServiceError: LocalizedError {
    case noPermission, changed, blocked(String)
    var errorDescription: String? {
        switch self {
        case .noPermission: return "请先在设置窗口允许访问日历。"
        case .changed: return "日程刚刚发生变化，请重新右键再试一次。"
        case .blocked(let message): return message
        }
    }
}
