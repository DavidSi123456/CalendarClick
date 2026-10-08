import AppKit

final class CalendarMonitor {
    private let service: CalendarService
    private let panel: CompanionPanel
    private var monitor: Any?
    private var timer: Timer?
    private var generation = 0
    private var context: CalendarContext?
    private var menuSeen = false
    private var shownAt = Date.distantPast
    private var lastDown = Date.distantPast
    var enabled = true
    var openSetup: (() -> Void)?
    var status: ((String) -> Void)?

    init(service: CalendarService, panel: CompanionPanel) {
        self.service = service
        self.panel = panel
    }

    func start() {
        guard monitor == nil else { return }
        // Observe mouse clicks only. Native events are never intercepted or synthesized.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseDown, .rightMouseUp, .leftMouseDown]) { [weak self] event in
            self?.handle(event)
        }
        timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in self?.checkDismissal() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        timer?.invalidate()
        timer = nil
        generation += 1
        context = nil
        panel.hide()
    }

    private func handle(_ event: NSEvent) {
        let isContextClick = event.type == .rightMouseDown || event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        if !isContextClick {
            if panel.visible && !panel.frame.contains(NSEvent.mouseLocation) && !panel.model.busy { panel.hide() }
            return
        }
        guard enabled, let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier == "com.apple.iCal" else { return }
        if event.type == .rightMouseUp && context != nil && Date().timeIntervalSince(lastDown) < 1 { return }
        if event.type == .rightMouseDown { lastDown = Date() }
        status?("已收到苹果日历中的右键，正在识别日程…")
        generation += 1
        let token = generation
        panel.hide()
        context = nil
        guard let point = event.cgEvent?.location else { status?("未能读取鼠标位置，请重新右键。"); return }
        guard let captured = CalendarAccessibility.context(at: point, pid: application.processIdentifier) else {
            status?("收到了右键，但还未识别到日程。请确认辅助功能已允许，并右键日程文字区域。")
            return
        }
        context = captured
        menuSeen = false
        shownAt = Date()
        // Let Calendar open its original menu before measuring it.
        let delay = Timer(timeInterval: 0.15, repeats: false) { [weak self] _ in
            guard let self, self.generation == token else { return }
            self.show(captured, point: point, token: token)
        }
        RunLoop.main.add(delay, forMode: .common)
    }

    private func show(_ captured: CalendarContext, point: CGPoint, token: Int) {
        panel.reset()
        panel.model.openSetup = { [weak self] in self?.panel.hide(); self?.openSetup?() }
        let menuRect = CalendarAccessibility.menuFrame(in: captured)
        menuSeen = menuRect != nil
        let anchor = CalendarAccessibility.cocoaRect(menuRect ?? CGRect(x: point.x, y: point.y, width: 220, height: 1))
        panel.show(nextTo: anchor)
        guard service.hasAccess else {
            panel.model.message = "先允许访问日历，即可给这个日程打勾。"
            panel.model.needsSetup = true
            panel.resize()
            return
        }
        service.findEvents(captured.hint) { [weak self] result in
            guard let self, self.generation == token, self.panel.visible else { return }
            switch result {
            case .success(let events):
                self.status?(events.isEmpty ? "已读到右键日程，但没有匹配到已同步的日历记录。" : "右键识别成功，已显示完成按钮。")
                self.panel.model.events = events
                self.panel.model.message = events.isEmpty ? "没有找到对应日程。请确认日历已同步后重新右键。" : ""
                self.panel.model.action = { [weak self] chosen in
                    guard let self, !self.panel.model.busy else { return }
                    self.panel.model.busy = true
                    self.service.setCompleted(!chosen.completed, event: chosen) { [weak self] result in
                        guard let self, self.generation == token else { return }
                        switch result {
                        case .success(let message): self.panel.finish(message, success: true)
                        case .failure(let error): self.panel.finish(error.localizedDescription, success: false)
                        }
                    }
                }
            case .failure(let error): self.panel.model.message = error.localizedDescription
            }
            self.panel.resize()
        }
    }

    private func checkDismissal() {
        guard panel.visible, let context, !panel.model.busy, !panel.model.finished else { return }
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if frontmost != "com.apple.iCal" && frontmost != Bundle.main.bundleIdentifier { panel.hide(); return }
        if let menu = CalendarAccessibility.menuFrame(in: context) {
            menuSeen = true
            panel.show(nextTo: CalendarAccessibility.cocoaRect(menu))
        } else if menuSeen && Date().timeIntervalSince(shownAt) > 1 && !panel.frame.contains(NSEvent.mouseLocation) {
            panel.hide()
        } else if Date().timeIntervalSince(shownAt) > 45 { panel.hide() }
    }
}
