import Foundation
import EventKit
import CoreGraphics

// The event store never leaves this class; all mutable EventKit access runs on queue.
final class CalendarRepository: @unchecked Sendable {
    private let queue = DispatchQueue(label: "calendarclick.ios.event-store")
    private let store = EKEventStore()
    static var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                store.requestFullAccessToEvents { granted, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: granted) }
                }
            }
        }
    }

    // nil means all calendars; an empty set deliberately means none.
    func load(day: Date, calendarIDs: Set<String>?) async throws -> AgendaData {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    guard Self.hasAccess else { throw AgendaError.noPermission }
                    store.reset()
                    let calendars = store.calendars(for: .event)
                    let choices = calendars.map(calendarRecord).sorted {
                        ($0.account, $0.name, $0.id) < ($1.account, $1.name, $1.id)
                    }
                    let selected = calendars.filter { calendarIDs?.contains($0.calendarIdentifier) ?? true }
                    guard let interval = Calendar.current.dateInterval(of: .day, for: day) else {
                        throw AgendaError.invalidDate
                    }
                    let events: [AgendaEvent]
                    if selected.isEmpty { events = [] }
                    else {
                        let predicate = store.predicateForEvents(withStart: interval.start,
                                                                 end: interval.end, calendars: selected)
                        let records = store.events(matching: predicate).map(eventRecord)
                        let unique = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                        events = AgendaOrder.sorted(Array(unique.values))
                    }
                    continuation.resume(returning: AgendaData(calendars: choices, events: events))
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func setCompleted(_ completed: Bool, chosen: AgendaEvent) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    guard Self.hasAccess else { throw AgendaError.noPermission }
                    store.reset()
                    guard let calendar = store.calendar(withIdentifier: chosen.calendarID) else {
                        throw AgendaError.changed
                    }
                    let predicate = store.predicateForEvents(withStart: chosen.start.addingTimeInterval(-1),
                                                             end: chosen.start.addingTimeInterval(1), calendars: [calendar])
                    let candidates = store.events(matching: predicate).filter {
                        chosen.matchesOccurrence(eventRecord($0))
                    }
                    guard candidates.count == 1, let event = candidates.first else { throw AgendaError.changed }
                    let latest = eventRecord(event)
                    guard chosen.isUnchanged(latest) else { throw AgendaError.changed }
                    if let reason = latest.blockedReason { throw AgendaError.blocked(reason) }
                    let original = event.title ?? ""
                    event.title = CompletionMark.setting(completed, title: original)
                    do { try store.save(event, span: .thisEvent, commit: true) }
                    catch { event.title = original; throw error }
                    continuation.resume(returning: ())
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func calendarRecord(_ calendar: EKCalendar) -> AgendaCalendar {
        var tint = CalendarTint.teal
        if let color = calendar.cgColor,
           let space = CGColorSpace(name: CGColorSpace.sRGB),
           let components = color.converted(to: space, intent: .defaultIntent, options: nil)?.components,
           components.count >= 3 {
            tint = CalendarTint(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2]))
        }
        return AgendaCalendar(id: calendar.calendarIdentifier, name: calendar.title,
                              account: calendar.source.title, tint: tint,
                              allowsEditing: calendar.allowsContentModifications,
                              isLocal: calendar.source.sourceType == .local)
    }

    private func eventRecord(_ event: EKEvent) -> AgendaEvent {
        let calendar = calendarRecord(event.calendar)
        return AgendaEvent(eventID: event.eventIdentifier ?? event.calendarItemIdentifier,
                           externalID: event.calendarItemExternalIdentifier,
                           calendarID: calendar.id, calendarName: calendar.name, account: calendar.account,
                           tint: calendar.tint, title: event.title ?? "", start: event.startDate, end: event.endDate,
                           allDay: event.isAllDay, recurring: event.hasRecurrenceRules || event.isDetached,
                           allowsEditing: calendar.allowsEditing, hasAttendees: event.hasAttendees,
                           canceled: event.status == .canceled, location: event.location ?? "")
    }
}
