import AppKit
import ApplicationServices

struct CalendarContext {
    let hint: EventHint
    let element: AXUIElement
}

enum CalendarAccessibility {
    static func value(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success else { return nil }
        return result
    }
    static func string(_ element: AXUIElement, _ name: String) -> String {
        if let string = value(element, name) as? String { return string }
        if let text = value(element, name) as? NSAttributedString { return text.string }
        return ""
    }
    static func children(_ element: AXUIElement) -> [AXUIElement] {
        value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }
    static func elementValue(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let result = value(element, name), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }

    static func context(at point: CGPoint, pid: pid_t) -> CalendarContext? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        var hit: AXUIElement?
        AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &hit)
        // The native context menu can already cover the pointer. Its focused element
        // remains the event; require the same hit/ancestor to avoid a stale selection.
        if let hit, let result = eventContext(near: hit) { return result }
        if let focused = elementValue(app, kAXFocusedUIElementAttribute),
           let frame = frame(of: focused), frame.insetBy(dx: -3, dy: -3).contains(point),
           let result = eventContext(near: focused) { return result }
        return nil
    }

    private static func eventContext(near element: AXUIElement) -> CalendarContext? {
        var current: AXUIElement? = element
        for _ in 0..<7 {
            guard let candidate = current else { break }
            let help = string(candidate, kAXHelpAttribute)
            let description = string(candidate, kAXDescriptionAttribute)
            let role = string(candidate, kAXRoleAttribute)
            // A calendar sidebar row also exposes its name; only event nodes have
            // the Calendar-specific Help text plus a date and static-text children.
            if role != kAXMenuRole, let name = calendarName(from: help),
               let parsed = EventDateParser.parse(dateDescription(description)) ?? ancestorDate(candidate) {
                var titles = children(candidate).filter { string($0, kAXRoleAttribute) == kAXStaticTextRole }
                    .map { child -> String in
                        let title = string(child, kAXValueAttribute)
                        return title.isEmpty ? string(child, kAXTitleAttribute) : title
                    }.filter { !$0.isEmpty }
                let ownTitle = string(candidate, kAXTitleAttribute)
                if !ownTitle.isEmpty { titles.insert(ownTitle, at: 0) }
                guard !titles.isEmpty else { return nil }
                return CalendarContext(hint: EventHint(titles: titles, calendarName: name,
                                                      date: parsed.date, hasExactTime: parsed.hasExactTime), element: candidate)
            }
            current = elementValue(candidate, kAXParentAttribute)
        }
        return nil
    }

    private static func dateDescription(_ description: String) -> String {
        // A title or a location can itself contain a date. Parse Calendar's date
        // clause instead of accidentally treating that text as the occurrence.
        for marker in ["开始于", "Starts on", "Starts at", "Starting on", "starting at"] {
            if let range = description.range(of: marker, options: .caseInsensitive) {
                return String(description[range.upperBound...])
            }
        }
        if let separator = description.range(of: ". ", options: .backwards) {
            return String(description[separator.upperBound...])
        }
        return ""
    }

    private static func ancestorDate(_ element: AXUIElement) -> ParsedEventDate? {
        var parent = elementValue(element, kAXParentAttribute)
        for _ in 0..<3 {
            guard let node = parent else { break }
            // A column value includes the pointer time, which is not the event's
            // start time. Use only its date, then ask the user if matches collide.
            for attribute in [kAXValueAttribute, kAXDescriptionAttribute] {
                if let parsed = EventDateParser.parse(string(node, attribute)) {
                    return ParsedEventDate(date: parsed.date, hasExactTime: false)
                }
            }
            parent = elementValue(node, kAXParentAttribute)
        }
        return nil
    }

    static func calendarName(from help: String) -> String? {
        let patterns = [#"日历[“\"](.+?)[”\"]"#, #"calendar\s+[“\"](.+?)[”\"]"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: help, range: NSRange(help.startIndex..., in: help)),
                  let range = Range(match.range(at: 1), in: help) else { continue }
            return String(help[range])
        }
        return nil
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = value(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions), dimensions.width > 0, dimensions.height > 0 else { return nil }
        return CGRect(origin: origin, size: dimensions)
    }

    static func menuFrame(in context: CalendarContext) -> CGRect? {
        children(context.element).first(where: { string($0, kAXRoleAttribute) == kAXMenuRole }).flatMap(frame)
    }

    static func cocoaRect(_ rect: CGRect) -> CGRect {
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: rect.minX, y: top - rect.maxY, width: rect.width, height: rect.height)
    }
}
