import Foundation
import Combine

@MainActor
final class AgendaModel: ObservableObject {
    @Published var day = Date()
    @Published var filter: AgendaFilter = .all
    @Published private(set) var calendars: [AgendaCalendar] = []
    @Published private(set) var events: [AgendaEvent] = []
    @Published private(set) var calendarIDs: Set<String>? = nil
    @Published private(set) var isDemo: Bool
    @Published private(set) var hasAccess = false
    @Published private(set) var loading = false
    @Published private(set) var savingID: String?
    @Published private(set) var lastRead: Date?
    @Published var errorMessage: String?
    @Published var message: String?
    @Published var selectedEvent: AgendaEvent?
    private lazy var repository = CalendarRepository()
    private var generation = 0
    private var demoStates: [String: Bool] = [:]
    let previewOnly: Bool

    init(demo: Bool = false, previewOnly: Bool = false) {
        self.previewOnly = previewOnly
        isDemo = demo || previewOnly
        if !previewOnly { hasAccess = CalendarRepository.hasAccess }
        if isDemo { loadDemo() }
    }

    var visibleEvents: [AgendaEvent] { events.filter(filter.includes) }
    var completedCount: Int { events.filter(\.completed).count }
    var progress: Double { events.isEmpty ? 0 : Double(completedCount) / Double(events.count) }
    var ready: Bool { isDemo || hasAccess }
    var allCalendarsSelected: Bool { calendarIDs == nil }
    func includesCalendar(_ id: String) -> Bool { calendarIDs?.contains(id) ?? true }

    func reload() async {
        generation += 1
        let request = generation
        if isDemo { loadDemo(); loading = false; return }
        hasAccess = CalendarRepository.hasAccess
        guard hasAccess else {
            events = []; calendars = []; lastRead = nil; loading = false
            return
        }
        loading = true
        do {
            let data = try await repository.load(day: day, calendarIDs: calendarIDs)
            guard request == generation, !isDemo else { return }
            calendars = data.calendars; events = data.events; lastRead = Date(); loading = false
        } catch {
            guard request == generation, !isDemo else { return }
            events = []; loading = false; errorMessage = error.localizedDescription
        }
    }

    func requestAccess() async {
        guard !loading, !previewOnly, savingID == nil else { return }
        generation += 1
        let request = generation
        loading = true
        do {
            let granted = try await repository.requestAccess()
            guard request == generation else { return }
            loading = false
            if granted { isDemo = false; calendarIDs = nil; await reload() }
            else { errorMessage = "日历访问尚未允许，可以先试用演示，或到系统设置中允许完全访问。" }
        } catch {
            guard request == generation else { return }
            loading = false; errorMessage = error.localizedDescription
        }
    }

    func useDemo() {
        guard savingID == nil else { return }
        generation += 1; isDemo = true; calendarIDs = nil; message = nil
        selectedEvent = nil; loading = false; loadDemo()
    }

    func leaveDemo() async {
        guard !previewOnly, savingID == nil else { return }
        generation += 1; isDemo = false; calendarIDs = nil; message = nil
        selectedEvent = nil; await reload()
    }

    func selectCalendar(_ id: String, included: Bool) {
        var selected = calendarIDs ?? Set(calendars.map(\.id))
        if included { selected.insert(id) } else { selected.remove(id) }
        calendarIDs = selected
        Task { await reload() }
    }

    func selectAllCalendars() { calendarIDs = nil; Task { await reload() } }
    func selectNoCalendars() { calendarIDs = []; Task { await reload() } }

    func toggle(_ chosen: AgendaEvent) async {
        guard savingID == nil else { return }
        if let reason = chosen.blockedReason { errorMessage = reason; return }
        let completed = !chosen.completed
        savingID = chosen.id; selectedEvent = nil
        defer { savingID = nil }
        do {
            if isDemo { demoStates[chosen.id] = completed }
            else { try await repository.setCompleted(completed, chosen: chosen) }
            message = isDemo ? (completed ? "示例已完成" : "示例已取消完成") :
                (completed ? "已完成，日历标题已加上 ✓" : "已取消完成，日历标题已恢复")
            await reload()
        } catch { errorMessage = error.localizedDescription; await reload() }
    }

    private func loadDemo() {
        calendars = AgendaDemo.calendars
        events = AgendaDemo.events(on: day).filter { includesCalendar($0.calendarID) }.map { event in
            var updated = event
            if let completed = demoStates[event.id] { updated.title = CompletionMark.setting(completed, title: event.title) }
            return updated
        }
        lastRead = nil
    }
}
