import AppKit
import SwiftUI

final class AppModel: ObservableObject {
    @Published var calendarAllowed = false
    @Published var accessibilityAllowed = false
    @Published var enabled = true
    @Published var message = ""
    @Published var demoComplete = false
    var grantCalendar: (() -> Void)?
    var grantAccessibility: (() -> Void)?
    var openCalendar: (() -> Void)?
    var preview: ((NSEvent, NSView) -> Void)?
    var changeEnabled: ((Bool) -> Void)?
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 16) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 34, weight: .medium)).foregroundStyle(.teal)
                    .frame(width: 74, height: 74)
                    .background(.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 7) {
                    Text("日历打勾").font(.system(size: 27, weight: .semibold))
                    Text("把做完的事，留个记号。").font(.system(size: 14)).foregroundStyle(.secondary)
                }
            }
            Text("在苹果日历里右键一个日程，原菜单旁会出现完成按钮。点击后，日程标题前就会多一个 ✓。")
                .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                permissionRow("日历访问", detail: "读取日程，并在你点击完成时更新标题", icon: "calendar", allowed: model.calendarAllowed) { model.grantCalendar?() }
                Divider().padding(.leading, 45)
                permissionRow("辅助功能", detail: "识别你在苹果日历里右键的日程", icon: "cursorarrow.click", allowed: model.accessibilityAllowed) { model.grantAccessibility?() }
            }
            .padding(.horizontal, 14).background(.background, in: RoundedRectangle(cornerRadius: 14))
            Toggle(isOn: Binding(get: { model.enabled }, set: { model.enabled = $0; model.changeEnabled?($0) })) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("在原右键菜单旁显示完成按钮").font(.system(size: 13, weight: .medium))
                    Text("工具运行时生效；顶部菜单栏可随时暂停或退出").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }.toggleStyle(.switch).tint(.teal)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("试一下").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("右键下面的示例日程").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                DemoEventRepresentable(model: model).frame(height: 66)
                Text("这里只是演示，不会写入你的日历。").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if !model.message.isEmpty {
                Text(model.message).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Text("重复日程只更改这一次 · 再次右键可取消完成")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("打开苹果日历") { model.openCalendar?() }.buttonStyle(.borderedProminent).tint(.teal)
            }
        }.padding(28).frame(width: 520).background(Color(nsColor: .windowBackgroundColor))
    }

    private func permissionRow(_ title: String, detail: String, icon: String, allowed: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.teal).frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if allowed {
                Label("已允许", systemImage: "checkmark.circle.fill").font(.system(size: 11)).foregroundStyle(.teal)
            } else { Button("允许", action: action).controlSize(.small) }
        }.padding(.vertical, 14)
    }
}

struct DemoEventRepresentable: NSViewRepresentable {
    @ObservedObject var model: AppModel
    func makeNSView(context: Context) -> DemoEventView { DemoEventView(model: model) }
    func updateNSView(_ view: DemoEventView, context: Context) {
        view.setAccessibilityLabel(model.demoComplete ? "示例日程：✓ 整理今天的笔记，右键取消完成" : "示例日程：整理今天的笔记，右键试用完成按钮")
        view.needsDisplay = true
    }
}

final class DemoEventView: NSView {
    let model: AppModel
    init(model: AppModel) {
        self.model = model
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("示例日程：整理今天的笔记，右键试用完成按钮")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemTeal.withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10).fill()
        NSColor.systemTeal.setFill()
        NSBezierPath(roundedRect: NSRect(x: 10, y: 12, width: 3, height: bounds.height - 24), xRadius: 1.5, yRadius: 1.5).fill()
        let title = model.demoComplete ? "✓ 整理今天的笔记" : "整理今天的笔记"
        title.draw(at: NSPoint(x: 24, y: 35), withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.labelColor])
        "个人 · 今天 16:00–16:30".draw(at: NSPoint(x: 24, y: 15), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
    }
    override func rightMouseDown(with event: NSEvent) { model.preview?(event, self) }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { rightMouseDown(with: event) }
        else { super.mouseDown(with: event) }
    }
}
