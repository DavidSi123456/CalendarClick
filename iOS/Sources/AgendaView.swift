import SwiftUI
import EventKit
import Combine
#if os(iOS)
import UIKit
#else
import AppKit
#endif

private let accent = Color(red: 0.09, green: 0.53, blue: 0.49)

extension CalendarTint {
    var color: Color { Color(red: red, green: green, blue: blue) }
}

private var pageColor: Color {
    #if os(iOS)
    return Color(uiColor: .systemGroupedBackground)
    #else
    return Color(nsColor: .windowBackgroundColor)
    #endif
}

private var cardColor: Color {
    #if os(iOS)
    return Color(uiColor: .secondarySystemGroupedBackground)
    #else
    return Color(nsColor: .controlBackgroundColor)
    #endif
}

struct AgendaView: View {
    @EnvironmentObject private var model: AgendaModel
    @Environment(\.scenePhase) private var phase
    @State private var showSettings = false
    @State private var showCalendars = false
    @State private var showDatePicker = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.ready { agenda } else { permissionView }
        }
        .background(pageColor)
        .tint(accent)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .task { await model.reload() }
        .onChange(of: model.day) { _, _ in Task { await model.reload() } }
        .onChange(of: phase) { _, value in if value == .active { Task { await model.reload() } } }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)) { _ in
                if !model.isDemo { Task { await model.reload() } }
            }
        .sheet(isPresented: $showSettings) { SettingsSheet().environmentObject(model) }
        .sheet(isPresented: $showCalendars) { CalendarSheet().environmentObject(model) }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("选择日期", selection: $model.day, displayedComponents: .date)
                    .datePickerStyle(.graphical).padding()
                    .navigationTitle("选择日期")
                    .toolbar { ToolbarItem { Button("完成") { showDatePicker = false } } }
            }.frame(minHeight: 380)
        }
        .sheet(item: $model.selectedEvent) { event in
            EventSheet(event: event).environmentObject(model)
        }
        .alert("暂时无法完成", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } })) {
                Button("知道了", role: .cancel) { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(accent)
            Text("日历打勾").font(.title2.bold())
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.title3).padding(8)
            }.buttonStyle(.plain).accessibilityLabel("设置")
        }.padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 18)
    }

    private var agenda: some View {
        VStack(spacing: 0) {
            if model.isDemo {
                HStack {
                    Label("演示模式", systemImage: "sparkles").font(.caption.weight(.medium))
                    Spacer()
                    Text("不读取或修改真实日历").font(.caption2)
                }.foregroundStyle(accent).padding(.horizontal, 13).padding(.vertical, 9)
                    .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 22).padding(.bottom, 16)
            }
            HStack(alignment: .center) {
                Button { showDatePicker = true } label: {
                    HStack(spacing: 6) {
                        Text(AgendaEvent.format(model.day, "M月d日 EEEE")).font(.title3.bold())
                        Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                    }.foregroundStyle(.primary)
                }.buttonStyle(.plain)
                Spacer()
                Button("今天") { model.day = Date() }.font(.subheadline.weight(.medium))
            }.padding(.horizontal, 22).padding(.bottom, 12)
            weekStrip.padding(.horizontal, 16).padding(.bottom, 18)
            progressCard.padding(.horizontal, 22).padding(.bottom, 16)
            Picker("完成状态", selection: $model.filter) {
                ForEach(AgendaFilter.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).padding(.horizontal, 22).padding(.bottom, 18)
            HStack {
                Text("日程 · \(model.visibleEvents.count)").font(.subheadline.weight(.semibold))
                Spacer()
                Button { showCalendars = true } label: {
                    Label(model.allCalendarsSelected ? "所有日历" : "选择日历", systemImage: "line.3.horizontal.decrease")
                        .font(.caption)
                }.buttonStyle(.plain).foregroundStyle(accent)
            }.padding(.horizontal, 22).padding(.bottom, 10)
            ScrollView {
                LazyVStack(spacing: 10) {
                    if model.loading && model.events.isEmpty {
                        ProgressView("正在读取日历…").padding(.vertical, 50)
                    } else if model.visibleEvents.isEmpty {
                        emptyView
                    } else {
                        ForEach(model.visibleEvents) { event in
                            AgendaRow(event: event, busy: model.savingID != nil,
                                      saving: model.savingID == event.id,
                                      toggle: { Task { await model.toggle(event) } },
                                      details: { model.selectedEvent = event })
                        }
                    }
                }.padding(.horizontal, 22).padding(.bottom, 18)
            }.refreshable { await model.reload() }
            footer
        }
    }

    private var weekStrip: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: model.day)?.start ?? model.day
        return HStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
                let selected = calendar.isDate(day, inSameDayAs: model.day)
                Button { model.day = day } label: {
                    VStack(spacing: 8) {
                        Text(AgendaEvent.format(day, "EEEEE")).font(.caption2)
                        Text(AgendaEvent.format(day, "d")).font(.subheadline.weight(.semibold))
                    }.frame(maxWidth: .infinity).padding(.vertical, 11)
                        .foregroundStyle(selected ? .white : .primary)
                        .background(selected ? accent : .clear, in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
                    .accessibilityLabel(AgendaEvent.format(day, "M月d日 EEEE"))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.completedCount == model.events.count && !model.events.isEmpty ? "这一天的日程都完成了" : "一点一点，完成今天")
                        .font(.subheadline.weight(.semibold))
                    Text("已完成 \(model.completedCount) / \(model.events.count) 个日程")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(model.progress * 100))%")
                    .font(.title2.weight(.semibold)).monospacedDigit().foregroundStyle(accent)
            }
            ProgressView(value: model.progress).tint(accent)
        }.padding(16).background(cardColor, in: RoundedRectangle(cornerRadius: 16))
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark").font(.system(size: 35)).foregroundStyle(accent.opacity(0.7))
            Text(model.calendarIDs?.isEmpty == true ? "还没有选中日历" : "这里暂时没有日程")
                .font(.headline)
            Text(model.calendarIDs?.isEmpty == true ? "点上方的“选择日历”来显示日程。" : "换个日期或完成状态看看。")
                .font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(.vertical, 38)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if let message = model.message {
                Label(message, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(accent)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            HStack(spacing: 5) {
                Image(systemName: model.isDemo ? "hand.tap" : "calendar")
                Text(model.isDemo ? "点日程旁的圆圈试试完成" : "完成标记随系统日历账户同步")
                Spacer()
                Button { Task { await model.reload() } } label: {
                    Image(systemName: "arrow.clockwise").padding(5)
                }.buttonStyle(.plain).disabled(model.loading).accessibilityLabel("刷新日历")
            }.font(.caption2).foregroundStyle(.secondary)
        }.padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 16)
    }

    private var permissionView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "calendar.badge.checkmark").font(.system(size: 65)).foregroundStyle(accent)
            Text("让日程也能打个勾").font(.title2.bold())
            Text("读取你的系统日历，完成一件事时\n在日程标题前加上 ✓。\nMac 和 iPhone 共用同一份日历数据。")
                .font(.body).multilineTextAlignment(.center).foregroundStyle(.secondary)
            VStack(spacing: 14) {
                Button { Task { await model.requestAccess() } } label: {
                    HStack { Spacer(); if model.loading { ProgressView().controlSize(.small) }
                        Text("允许访问日历"); Spacer() }.padding(.vertical, 7)
                }.buttonStyle(.borderedProminent).disabled(model.loading)
                Button("先试用演示") { model.useDemo() }.buttonStyle(.plain)
            }.padding(.horizontal, 16)
            Text("需要日历完全访问权限，才能读取并修改已有日程。\n只在你点击完成时修改标题。")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
            Button("打开权限设置") { openPermissions() }.font(.caption)
        }.padding(26)
    }
}

private struct AgendaRow: View {
    let event: AgendaEvent
    let busy: Bool
    let saving: Bool
    let toggle: () -> Void
    let details: () -> Void

    var body: some View {
        HStack(spacing: 13) {
            Button(action: toggle) {
                Group {
                if saving { ProgressView().controlSize(.small).frame(width: 28, height: 28) }
                else {
                    Image(systemName: event.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 27, weight: .light))
                        .foregroundStyle(event.completed ? accent : event.blockedReason == nil ? Color.secondary.opacity(0.5) : Color.secondary.opacity(0.2))
                }
                }.frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(busy || event.blockedReason != nil)
                .accessibilityLabel((event.completed ? "取消完成：" : "标记完成：") + event.displayTitle)
            Button(action: details) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(event.displayTitle).font(.body.weight(.medium))
                        .strikethrough(event.completed).foregroundStyle(event.completed ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(event.timeDescription).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 5) {
                        Circle().fill(event.tint.color).frame(width: 6, height: 6)
                        Text(event.calendarName)
                        if event.recurring { Image(systemName: "repeat") }
                        if event.blockedReason != nil { Image(systemName: "lock"); Text("仅查看") }
                    }.font(.caption2).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
        }.padding(15).background(cardColor, in: RoundedRectangle(cornerRadius: 15))
            .contextMenu {
                Button(event.completed ? "取消完成" : "标记为已完成", action: toggle)
                    .disabled(busy || event.blockedReason != nil)
                Button("查看日程", action: details)
            }
    }
}

private struct CalendarSheet: View {
    @EnvironmentObject private var model: AgendaModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("显示所有日历") { model.selectAllCalendars() }
                    Button("取消全部选择") { model.selectNoCalendars() }
                }
                Section("选择要显示的日历") {
                    ForEach(model.calendars) { calendar in
                        Toggle(isOn: Binding(get: { model.includesCalendar(calendar.id) },
                                             set: { model.selectCalendar(calendar.id, included: $0) })) {
                            HStack(spacing: 10) {
                                Circle().fill(calendar.tint.color).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(calendar.name)
                                    Text(calendar.account + (calendar.isLocal ? " · 本机日历" : "") +
                                         (calendar.allowsEditing ? "" : " · 只读"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    Text("两台设备需要使用同一个日历账户。仅保存在本机的日历无法通过账户同步。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("选择日历")
                .toolbar { ToolbarItem { Button("完成") { dismiss() } } }
        }.frame(minHeight: 440).tint(accent)
    }
}

private struct SettingsSheet: View {
    @EnvironmentObject private var model: AgendaModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("日历访问") {
                    LabeledContent("状态", value: model.previewOnly ? "界面预览" : model.hasAccess ? "已允许完全访问" : "尚未允许")
                    if !model.previewOnly { Button("打开系统权限设置") { openPermissions() } }
                }
                Section("完成标记") {
                    Text("完成后，标题会显示“✓ 原标题”。退出应用后标记仍然保留，Mac 版也能识别。")
                    Text("重复日程只修改本次。只读日历、已取消日程和含参与者的会议不支持修改。")
                }
                Section("跨设备使用") {
                    Text("Mac 与 iPhone 使用同一个 iCloud 或其他日历账户，并开启日历同步即可。")
                    Text("日历账户负责同步，不需要应用配对或额外注册。打开应用或下拉刷新时，会重新读取系统日历。同步速度由日历服务决定。")
                    if let date = model.lastRead {
                        LabeledContent("上次读取", value: AgendaEvent.format(date, "HH:mm:ss"))
                    }
                }
                Section("试用") {
                    if model.isDemo && !model.previewOnly {
                        Button("退出演示，使用我的日历") { Task { await model.leaveDemo(); dismiss() } }
                    } else { Button("查看演示日程") { model.useDemo(); dismiss() } }
                    Text("演示使用虚构日程，不读取或修改你的日历。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("设置")
                .toolbar { ToolbarItem { Button("完成") { dismiss() } } }
        }.frame(minHeight: 550).tint(accent)
    }
}

private struct EventSheet: View {
    @EnvironmentObject private var model: AgendaModel
    @Environment(\.dismiss) private var dismiss
    let event: AgendaEvent
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(event.displayTitle).font(.title2.weight(.semibold))
                    LabeledContent("状态", value: event.completed ? "已完成 ✓" : "待完成")
                    LabeledContent("时间", value: event.timeDescription)
                    LabeledContent("日历", value: event.calendarName)
                    LabeledContent("账户", value: event.account)
                    if !event.location.isEmpty { LabeledContent("地点", value: event.location) }
                }
                if let reason = event.blockedReason {
                    Section { Label(reason, systemImage: "lock").foregroundStyle(.secondary) }
                } else {
                    Section {
                        Button { Task { await model.toggle(event) } } label: {
                            Label(event.completed ? "取消完成" : "标记为已完成",
                                  systemImage: event.completed ? "arrow.uturn.backward" : "checkmark")
                        }.disabled(model.savingID != nil)
                        if event.recurring { Text("重复日程 · 只更改这一次").font(.footnote).foregroundStyle(.secondary) }
                    }
                }
            }.navigationTitle("日程详情")
                .toolbar { ToolbarItem { Button("关闭") { dismiss() } } }
        }.frame(minHeight: 430).tint(accent)
    }
}

@MainActor private func openPermissions() {
    #if os(iOS)
    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    #else
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
        NSWorkspace.shared.open(url)
    }
    #endif
}
