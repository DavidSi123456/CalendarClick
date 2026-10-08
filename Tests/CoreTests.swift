import Foundation

@main
struct CoreTests {
    static func main() {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            count += 1
            guard condition() else { fatalError("失败：\(message)") }
        }
        let zone = TimeZone(identifier: "Asia/Shanghai")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        func date(_ text: String) -> Date { EventDateParser.parse(text, timeZone: zone)!.date }
        let title = "高数作业 ✓ 第二题"
        let marked = CompletionMark.setting(true, title: title)
        check(marked == "✓ 高数作业 ✓ 第二题", "保留标题内部的勾号")
        check(CompletionMark.setting(true, title: marked) == marked, "重复完成不添加重复前缀")
        check(CompletionMark.setting(false, title: marked) == title, "取消完成恢复原题目")
        check(CompletionMark.setting(false, title: title) == title, "取消未完成日程不损坏标题")
        check(!CompletionMark.isCompleted("✓原有符号"), "只识别约定的带空格前缀")
        let chinese = EventDateParser.parse("作业. 开始于2026年10月8日 09:00，结束于10:00。", timeZone: zone)!
        check(chinese.hasExactTime, "中文时间精确识别")
        check(chinese.date == date("2026-10-08 09:00"), "中文和 ISO 日期一致")
        check(date("10/8/26, 09:00") == chinese.date, "macOS 短日期")
        check(date("10/8/2026, 9:00 AM") == chinese.date, "美式上午")
        check(date("10/8/2026, 12:00 AM") == date("2026-10-08 00:00"), "凌晨十二点")
        check(date("10/8/2026, 12:00 PM") == date("2026-10-08 12:00"), "正午十二点")
        check(date("10/8/2026, 3:00 PM") == date("2026-10-08 15:00"), "美式下午")
        check(date("2026年10月8日 ⁨09:00⁩") == chinese.date, "去除双向文本控制字符")
        check(EventDateParser.parse("2026年2月30日", timeZone: zone) == nil, "拒绝不存在的日期")
        check(EventDateParser.parse("2026年10月8日 25:00", timeZone: zone) == nil, "拒绝无效时间")
        check(EventDateParser.parse("没有日期的日程", timeZone: zone) == nil, "不猜测今天")
        check(!EventDateParser.parse("生日. 2026年10月8日, 全天", timeZone: zone)!.hasExactTime, "全天日程没有时间")
        let start = date("2026-10-08 09:00")
        let record = EventRecord(eventID: "series", externalID: "external", calendarID: "work", calendarName: "作业",
                                 title: "✓ 高数作业", start: start, end: start.addingTimeInterval(3600), allDay: false,
                                 recurring: true, blockedReason: nil)
        func hint(_ title: String, _ name: String, _ time: String, exact: Bool = true) -> EventHint {
            EventHint(titles: [title], calendarName: name, date: date(time), hasExactTime: exact)
        }
        check(record.matches(hint("高数作业", "作业", "2026-10-08 09:00"), calendar: calendar), "匹配已完成日程")
        check(!record.matches(hint("高数作业", "生活", "2026-10-08 09:00"), calendar: calendar), "拒绝其他日历里的同名日程")
        check(!record.matches(hint("高数作业", "作业", "2026-10-08 10:00"), calendar: calendar), "拒绝同一天另一时段")
        check(!record.matches(hint("高数作业", "作业", "2026-10-15 09:00"), calendar: calendar), "拒绝重复日程的另一周")
        check(!record.matches(hint("高数作业第二题", "作业", "2026-10-08 09:00"), calendar: calendar), "不用模糊标题匹配")
        let allDay = EventRecord(eventID: "all-day", externalID: nil, calendarID: "personal", calendarName: "个人",
                                title: "假期", start: date("2026-10-01"), end: date("2026-10-08"),
                                allDay: true, recurring: false, blockedReason: nil)
        check(allDay.matches(hint("假期", "个人", "2026-10-07", exact: false), calendar: calendar), "跨日全天日程")
        check(!allDay.matches(hint("假期", "个人", "2026-10-08", exact: false), calendar: calendar), "全天日程结束日为开区间")
        print("通过 \(count) 项检查：日期解析、完成与取消、同名日程隔离、重复日程日期匹配。")
    }
}
