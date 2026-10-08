import AppKit
import SwiftUI
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let service = CalendarService()
    let panel = CompanionPanel()
    lazy var monitor = CalendarMonitor(service: service, panel: panel)
    var window: NSWindow!
    var statusItem: NSStatusItem!
    var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makeMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 570),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "日历打勾"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        model.enabled = !UserDefaults.standard.bool(forKey: "paused")
        monitor.enabled = model.enabled
        model.grantCalendar = { [weak self] in self?.requestCalendar() }
        model.grantAccessibility = { [weak self] in self?.requestAccessibility() }
        model.openCalendar = { [weak self] in self?.openCalendar() }
        model.changeEnabled = { [weak self] value in
            UserDefaults.standard.set(!value, forKey: "paused")
            self?.monitor.enabled = value
            if !value { self?.panel.hide() }
        }
        model.preview = { [weak self] event, view in self?.preview(event, view: view) }
        monitor.openSetup = { [weak self] in self?.showSettings() }
        monitor.status = { [weak self] message in self?.model.message = message }
        monitor.start()
        refreshPermissions()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshPermissions() }
        showSettings()
    }

    func applicationWillTerminate(_ notification: Notification) { monitor.stop(); permissionTimer?.invalidate() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }

    private func makeMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "calendar.badge.checkmark", accessibilityDescription: "日历打勾")
        statusItem.button?.toolTip = "日历打勾"
        let menu = NSMenu()
        let settings = NSMenuItem(title: "日历打勾设置…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let calendar = NSMenuItem(title: "打开苹果日历", action: #selector(openCalendar), keyEquivalent: "")
        calendar.target = self
        menu.addItem(calendar)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出日历打勾", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "日历打勾")
        let mainQuit = NSMenuItem(title: "退出日历打勾", action: #selector(quit), keyEquivalent: "q")
        mainQuit.target = self
        applicationMenu.addItem(mainQuit)
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
    }

    @objc func showSettings() {
        panel.hide()
        refreshPermissions()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func openCalendar() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
    @objc func quit() { NSApp.terminate(nil) }

    private func refreshPermissions() {
        let previouslyAllowed = model.accessibilityAllowed
        model.calendarAllowed = service.hasAccess
        model.accessibilityAllowed = AXIsProcessTrusted()
        if model.accessibilityAllowed && !previouslyAllowed { monitor.stop(); monitor.start() }
    }

    private func requestCalendar() {
        service.requestAccess { [weak self] result in
            guard let self else { return }
            self.refreshPermissions()
            switch result {
            case .success(true): self.model.message = "日历已连接。允许辅助功能后，就可以在苹果日历里使用。"
            case .success(false):
                self.model.message = "请在系统设置 → 隐私与安全性 → 日历中，允许日历打勾完全访问。"
                self.openPrivacy("Privacy_Calendars")
            case .failure(let error): self.model.message = error.localizedDescription
            }
        }
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        model.message = "在辅助功能列表中打开“日历打勾”。如果没有显示，点 + 添加当前文件夹中的应用。"
        openPrivacy("Privacy_Accessibility")
    }
    private func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?" + pane) { NSWorkspace.shared.open(url) }
    }

    private func preview(_ event: NSEvent, view: NSView) {
        panel.reset()
        let now = Date()
        let day = Calendar.current.startOfDay(for: now)
        let start = Calendar.current.date(byAdding: .hour, value: 16, to: day)!
        let demo = EventRecord(eventID: "demo", externalID: nil, calendarID: "demo", calendarName: "示例 · 个人",
                               title: CompletionMark.setting(model.demoComplete, title: "整理今天的笔记"),
                               start: start, end: start.addingTimeInterval(1800), allDay: false, recurring: false, blockedReason: nil)
        panel.model.events = [demo]
        panel.model.message = "演示日程，不会写入日历"
        panel.model.action = { [weak self] _ in
            guard let self else { return }
            self.model.demoComplete.toggle()
            self.panel.finish(self.model.demoComplete ? "✓ 示例日程已完成" : "示例日程已取消完成", success: true)
        }
        let point = NSEvent.mouseLocation
        let menu = NSMenu(title: "示例日程菜单")
        menu.addItem(NSMenuItem(title: "显示简介（演示）", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "日历", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "拷贝", action: nil, keyEquivalent: ""))
        // Own native menu is only for the safe preview, never for Calendar's menu.
        let show = Timer(timeInterval: 0.08, repeats: false) { [weak self] _ in
            self?.panel.show(nextTo: CGRect(x: point.x, y: point.y - 80, width: 180, height: 80))
        }
        RunLoop.main.add(show, forMode: .common)
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
