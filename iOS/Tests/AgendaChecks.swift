import Foundation

@main
struct AgendaChecks {
    @MainActor static func main() async {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            count += 1
            guard condition() else { fatalError("失败：\(name)") }
        }
        let start = Date(timeIntervalSince1970: 1_791_421_200)
        func event(id: String = "series", external: String? = "external", calendar: String = "work",
                   title: String = "项目资料 ✓ 第二份", date: Date = start, end: Date? = nil,
                   allDay: Bool = false, editable: Bool = true, attendees: Bool = false, canceled: Bool = false) -> AgendaEvent {
            AgendaEvent(eventID: id, externalID: external, calendarID: calendar, calendarName: calendar,
                        account: "示例账户", tint: .teal, title: title, start: date,
                        end: end ?? date.addingTimeInterval(3600), allDay: allDay, recurring: true,
                        allowsEditing: editable, hasAttendees: attendees, canceled: canceled, location: "")
        }
        let chosen = event()
        check(chosen.isUnchanged(event()), "同一日程允许保存")
        check(!chosen.matchesOccurrence(event(calendar: "personal")), "拒绝其他日历的同名日程")
        check(!chosen.matchesOccurrence(event(date: start.addingTimeInterval(7 * 86400))), "拒绝重复日程另一周")
        check(!chosen.isUnchanged(event(date: start.addingTimeInterval(0.5))), "拒绝被微调的开始时间")
        check(!chosen.isUnchanged(event(title: "新的标题")), "拒绝覆盖同步来的新标题")
        check(!chosen.isUnchanged(event(end: start.addingTimeInterval(7200))), "拒绝已更改的结束时间")
        check(!chosen.isUnchanged(event(allDay: true)), "拒绝已更改的全天属性")
        check(chosen.matchesOccurrence(event(id: "new-local-id")), "同步更换本机 ID 后用外部 ID 校验同一次")
        check(!chosen.matchesOccurrence(event(id: "other", external: nil)), "不以缺失外部 ID 匹配")
        check(!event(external: nil).matchesOccurrence(event(id: "other", external: nil)), "两个 nil 外部 ID 不相等匹配")
        check(!event(external: "").matchesOccurrence(event(id: "other", external: "")), "两个空外部 ID 不相等匹配")
        check(event(editable: false).blockedReason != nil, "只读日历禁止修改")
        check(event(attendees: true).blockedReason != nil, "有参与者会议禁止修改")
        check(event(canceled: true).blockedReason != nil, "已取消日程禁止修改")
        check(chosen.blockedReason == nil, "个人可编辑日程可修改")
        let marked = CompletionMark.setting(true, title: chosen.title)
        check(marked == "✓ 项目资料 ✓ 第二份", "与 Mac 完成前缀完全一致")
        check(CompletionMark.setting(false, title: marked) == chosen.title, "保留标题内部的勾号")
        check(CompletionMark.setting(true, title: marked) == marked, "重复标记幂等")
        check(AgendaFilter.pending.includes(chosen), "待完成筛选")
        check(AgendaFilter.completed.includes(event(title: marked)), "已完成筛选")
        check(!AgendaFilter.completed.includes(chosen), "完成筛选排除未完成")
        check(AgendaOrder.sorted([chosen, event(id: "all-day", allDay: true)]).first?.allDay == true, "全天排在前面")
        check(AgendaOrder.sorted([event(id: "late", date: start.addingTimeInterval(7200)), chosen]).first?.id == chosen.id, "按时间排序")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let dstDay = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
        check(calendar.dateInterval(of: .day, for: dstDay)!.duration == 23 * 3600, "查询按日历日边界处理夏令时")

        let model = AgendaModel(demo: true, previewOnly: true)
        await model.reload()
        check(model.events.count == 4 && model.completedCount == 1, "免授权演示初始化")
        let sample = model.events.first { $0.eventID == "project" }!
        await model.toggle(sample)
        check(model.events.first { $0.eventID == "project" }!.completed, "演示点击完成")
        check(model.completedCount == 2, "完成计数更新")
        await model.toggle(model.events.first { $0.eventID == "project" }!)
        check(!model.events.first { $0.eventID == "project" }!.completed, "演示取消完成")
        let meeting = model.events.first { $0.eventID == "meeting" }!
        await model.toggle(meeting)
        check(!model.events.first { $0.eventID == "meeting" }!.completed && model.errorMessage != nil, "演示会议同样禁止修改")
        model.selectNoCalendars(); await model.reload()
        check(model.events.isEmpty, "取消全部日历不会被解释成显示全部")
        model.selectAllCalendars(); await model.reload()
        check(model.events.count == 4, "恢复所有日历")
        model.selectCalendar("demo-work", included: false); await model.reload()
        check(model.events.allSatisfy { $0.calendarID != "demo-work" }, "按日历 ID 筛选")
        await model.leaveDemo()
        check(model.isDemo, "Mac 界面预览不能切换到真实日历")
        check(model.savingID == nil, "完成或失败后释放保存状态")
        print("通过 \(count) 项 iOS 核心与演示检查。未读取或修改真实日历。")
    }
}
