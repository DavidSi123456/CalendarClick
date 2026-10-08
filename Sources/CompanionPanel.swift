import AppKit
import SwiftUI

final class PanelModel: ObservableObject {
    @Published var events: [EventRecord] = []
    @Published var message = "正在识别日程…"
    @Published var busy = false
    @Published var needsSetup = false
    @Published var finished = false
    var action: ((EventRecord) -> Void)?
    var openSetup: (() -> Void)?
    var close: (() -> Void)?
}

private struct CompanionView: View {
    @ObservedObject var model: PanelModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.mint)
                Text("日历打勾").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Button(action: { model.close?() }) { Image(systemName: "xmark").font(.system(size: 10)) }
                    .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("关闭完成按钮")
            }
            if model.events.isEmpty || model.finished {
                Text(model.message).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                if model.needsSetup {
                    Button("打开授权设置") { model.openSetup?() }.buttonStyle(.borderedProminent).tint(.teal)
                }
            } else {
                if model.events.count > 1 {
                    Text("有多个同名日程，请选一个").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ForEach(model.events) { event in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(event.displayTitle).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                        Text(detail(event)).font(.system(size: 11)).foregroundStyle(.secondary)
                        if let reason = event.blockedReason {
                            Text(reason).font(.system(size: 11)).foregroundStyle(.secondary)
                        } else {
                            Button(action: { model.action?(event) }) {
                                HStack {
                                    Image(systemName: event.completed ? "arrow.uturn.backward" : "checkmark")
                                    Text(event.completed ? "取消完成" : "标记为已完成")
                                    Spacer()
                                    if model.busy { ProgressView().controlSize(.mini) }
                                }.frame(maxWidth: .infinity).padding(.vertical, 3)
                            }
                            .buttonStyle(.borderedProminent).tint(event.completed ? .gray : .teal)
                            .disabled(model.busy)
                        }
                        if event.recurring {
                            Text("重复日程 · 只更改这一次").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                    if event.id != model.events.last?.id { Divider() }
                }
                if !model.message.isEmpty {
                    Text(model.message).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }.padding(13).frame(width: 266)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
    }
    private func detail(_ event: EventRecord) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = event.allDay ? "M月d日 · 全天" : "M月d日 HH:mm"
        return event.calendarName + " · " + formatter.string(from: event.start)
    }
}

private final class CompanionWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class CompanionPanel {
    let model = PanelModel()
    private let panel: NSPanel
    private let hosting: NSHostingView<CompanionView>
    private var anchor = CGRect.zero
    private var dismissal: Timer?
    var visible: Bool { panel.isVisible }
    var frame: CGRect { panel.frame }

    init() {
        hosting = NSHostingView(rootView: CompanionView(model: model))
        panel = CompanionWindow(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "日历打勾 · 完成按钮"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = hosting
        model.close = { [weak self] in self?.hide() }
    }

    func show(nextTo rect: CGRect) {
        dismissal?.invalidate()
        anchor = rect
        resize()
        panel.orderFrontRegardless()
    }

    func resize() {
        hosting.invalidateIntrinsicContentSize()
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        let height = max(75, size.height)
        let width: CGFloat = 266
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        let rightX = anchor.maxX + 8
        let leftX = anchor.minX - width - 8
        var x = rightX + width <= bounds.maxX ? rightX : leftX
        x = min(max(x, bounds.minX + 6), bounds.maxX - width - 6)
        let y = min(max(anchor.maxY - height, bounds.minY + 6), bounds.maxY - height - 6)
        panel.setFrame(CGRect(x: x, y: y, width: width, height: height), display: true)
    }

    func finish(_ message: String, success: Bool) {
        model.busy = false
        model.message = message
        model.finished = success
        resize()
        if success {
            dismissal = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in self?.hide() }
        }
    }

    func reset() {
        model.events = []
        model.message = "正在识别日程…"
        model.busy = false
        model.finished = false
        model.needsSetup = false
        model.action = nil
    }

    func hide() {
        dismissal?.invalidate()
        panel.orderOut(nil)
    }
}
