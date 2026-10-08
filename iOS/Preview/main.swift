import AppKit
import SwiftUI

@MainActor
final class PreviewDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var hosting: NSHostingView<AnyView>!
    private let model = AgendaModel(demo: true, previewOnly: true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        model.day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 12))!
        hosting = NSHostingView(rootView: AnyView(AgendaView().environmentObject(model).preferredColorScheme(.light)))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 430, height: 850),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "日历打勾 · iOS 界面预览"
        window.minSize = NSSize(width: 390, height: 700)
        window.contentView = hosting
        window.center(); window.makeKeyAndOrderFront(nil)
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出预览", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; NSApp.mainMenu = menu
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.exportPreview() }
    }

    private func exportPreview() {
        hosting.layoutSubtreeIfNeeded()
        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        let url = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("preview.png")
        try? data.write(to: url)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct PreviewMain {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        let delegate = PreviewDelegate()
        application.delegate = delegate
        application.run()
    }
}
