// Sources/AppleHelper/CalendarCommands.swift
import ArgumentParser
import EventKit
import Foundation

struct CalendarCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calendar",
        abstract: "Calendar operations (EventKit)."
    )

    @Argument(help: "Operation name. One of: list_calendars, list_events, get_event, search_events, create_event, update_event, delete_event, free_busy.")
    var op: String

    @Option(name: .long) var from: String?
    @Option(name: .long) var to: String?
    @Option(name: .long) var calendarId: String?
    @Option(name: .long) var calendarIds: String?  // comma-separated
    @Option(name: .long) var id: String?
    @Option(name: .long) var title: String?
    @Option(name: .long) var start: String?
    @Option(name: .long) var end: String?
    @Option(name: .long) var location: String?
    @Option(name: .long) var notes: String?
    @Option(name: .long) var recurrence: String?
    @Flag(name: .long) var allDay: Bool = false
    @Option(name: .long) var query: String?

    mutating func run() throws {
        let store = EKEventStore()
        // TCC gate: EventKit read APIs return empty instead of erroring on denied
        // access, and writes throw generic errors. Probe auth up front so the
        // wrapper sees a clean TCC_DENIED marker instead of misleading "no events".
        let authStatus = EKEventStore.authorizationStatus(for: .event)
        guard authStatus == .fullAccess else {
            HelperError.tccDenied(
                service: "calendar",
                message: "Calendar access not granted (status: \(authStatus.rawValue)). Run /apple-services-setup or grant in System Settings → Privacy & Security → Calendars."
            ).writeAndExit()
        }
        do {
            switch op {
            case "list_calendars":
                let cals = store.calendars(for: .event)
                let json = cals.map { cal in
                    [
                        "id": cal.calendarIdentifier,
                        "title": cal.title,
                        "color": cal.cgColor.map { JSON.hex(from: $0) } ?? "",
                        "writable": cal.allowsContentModifications,
                    ] as [String: Any]
                }
                print(JSON.encode(json))

            case "list_events":
                guard let fromStr = from, let toStr = to else {
                    throw HelperError.invalidArg(service: "calendar", message: "list_events requires --from and --to")
                }
                let fromDate = try parseDate(fromStr, arg: "from")
                let toDate = try parseDate(toStr, arg: "to")
                let cals = calendarId.flatMap { cid in store.calendars(for: .event).filter { $0.calendarIdentifier == cid } }
                let predicate = store.predicateForEvents(withStart: fromDate, end: toDate, calendars: cals)
                let events = store.events(matching: predicate)
                print(JSON.encode(events.map(eventToDict)))

            case "get_event":
                guard let id = id else { throw HelperError.invalidArg(service: "calendar", message: "get_event requires --id") }
                // calendarItem(withIdentifier:) works for both events and reminders.
                guard let event = store.calendarItem(withIdentifier: id) as? EKEvent else {
                    throw HelperError.notFound(service: "calendar", message: "No event with id \(id)")
                }
                print(JSON.encode(eventToDict(event)))

            case "search_events":
                guard let q = query, let fromStr = from, let toStr = to else {
                    throw HelperError.invalidArg(service: "calendar", message: "search_events requires --query --from --to")
                }
                let fromDate = try parseDate(fromStr, arg: "from")
                let toDate = try parseDate(toStr, arg: "to")
                let predicate = store.predicateForEvents(withStart: fromDate, end: toDate, calendars: nil)
                let needle = q.lowercased()
                let events = store.events(matching: predicate).filter { event in
                    (event.title ?? "").lowercased().contains(needle) ||
                    (event.notes ?? "").lowercased().contains(needle) ||
                    (event.location ?? "").lowercased().contains(needle)
                }
                print(JSON.encode(events.map(eventToDict)))

            case "create_event":
                guard let title = title, let startStr = start, let endStr = end, let calId = calendarId else {
                    throw HelperError.invalidArg(service: "calendar", message: "create_event requires --title --start --end --calendar-id")
                }
                let startDate = try parseDate(startStr, arg: "start")
                let endDate = try parseDate(endStr, arg: "end")
                guard endDate >= startDate else {
                    throw HelperError.invalidArg(service: "calendar", message: "end must be >= start")
                }
                guard let cal = store.calendars(for: .event).first(where: { $0.calendarIdentifier == calId }) else {
                    throw HelperError.notFound(service: "calendar", message: "No calendar with id \(calId)")
                }
                let event = EKEvent(eventStore: store)
                event.calendar = cal
                event.title = title
                event.startDate = startDate
                event.endDate = endDate
                event.isAllDay = allDay
                if let loc = location { event.location = loc }
                if let n = notes { event.notes = n }
                if let rule = recurrence { event.recurrenceRules = [try parseRecurrence(rule)] }
                try store.save(event, span: .thisEvent, commit: true)
                print(JSON.encode(eventToDict(event)))

            case "update_event":
                guard let id = id else { throw HelperError.invalidArg(service: "calendar", message: "update_event requires --id") }
                guard let event = store.calendarItem(withIdentifier: id) as? EKEvent else {
                    throw HelperError.notFound(service: "calendar", message: "No event with id \(id)")
                }
                if let t = title { event.title = t }
                if let s = start { event.startDate = try parseDate(s, arg: "start") }
                if let e = end { event.endDate = try parseDate(e, arg: "end") }
                if let loc = location { event.location = loc }
                if let n = notes { event.notes = n }
                if let calId = calendarId, let cal = store.calendars(for: .event).first(where: { $0.calendarIdentifier == calId }) {
                    event.calendar = cal
                }
                if let rule = recurrence { event.recurrenceRules = [try parseRecurrence(rule)] }
                try store.save(event, span: .thisEvent, commit: true)
                print(JSON.encode(eventToDict(event)))

            case "delete_event":
                guard let id = id else { throw HelperError.invalidArg(service: "calendar", message: "delete_event requires --id") }
                guard let event = store.calendarItem(withIdentifier: id) as? EKEvent else {
                    throw HelperError.notFound(service: "calendar", message: "No event with id \(id)")
                }
                try store.remove(event, span: .thisEvent, commit: true)
                print(#"{"ok":true}"#)

            case "free_busy":
                guard let fromStr = from, let toStr = to else {
                    throw HelperError.invalidArg(service: "calendar", message: "free_busy requires --from --to")
                }
                let fromDate = try parseDate(fromStr, arg: "from")
                let toDate = try parseDate(toStr, arg: "to")
                let cals = calendarIds?.split(separator: ",").compactMap { cid in
                    store.calendars(for: .event).first(where: { $0.calendarIdentifier == String(cid) })
                }
                let predicate = store.predicateForEvents(withStart: fromDate, end: toDate, calendars: cals)
                let events = store.events(matching: predicate)
                // Collapse into busy windows: each event becomes one {start, end, busy: true}.
                // Gaps are implicit (free). Consumers can merge overlaps if they care.
                let slots = events
                    .sorted { $0.startDate < $1.startDate }
                    .map { ["start": $0.startDate, "end": $0.endDate, "busy": true] as [String: Any] }
                print(JSON.encode(slots))

            default:
                throw HelperError.invalidArg(service: "calendar", message: "Unknown op: \(op)")
            }
        } catch let e as HelperError {
            e.writeAndExit()
        } catch {
            // EventKit denial paths are handled by the upfront authStatus gate
            // (EKError.Code has no `.denied` case — the plan assumed an API that
            // doesn't exist). Anything reaching here is genuinely unexpected.
            HelperError.internalError(service: "calendar", message: String(describing: error)).writeAndExit()
        }
    }

    private func parseDate(_ s: String, arg: String) throws -> Date {
        if let d = JSON.iso8601.date(from: s) { return d }
        let withTz = DateFormatter()
        withTz.dateFormat = "yyyy-MM-dd'T'HH:mm"
        withTz.timeZone = .current
        if let d = withTz.date(from: s) { return d }
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = .current
        if let d = dateOnly.date(from: s) { return d }
        throw HelperError.invalidArg(service: "calendar", message: "Invalid date for --\(arg): \(s) (expected ISO-8601 or yyyy-MM-dd)")
    }

    /// v1 recurrence support: accept a tiny DSL — one of
    ///   "daily", "weekly", "monthly", "yearly"
    /// plus optional interval suffix like "weekly:2" (every 2 weeks).
    /// Richer rules (BYDAY etc.) are out of scope for v1.
    private func parseRecurrence(_ rule: String) throws -> EKRecurrenceRule {
        let parts = rule.split(separator: ":")
        let freqStr = String(parts[0]).lowercased()
        let interval = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
        let freq: EKRecurrenceFrequency
        switch freqStr {
        case "daily":   freq = .daily
        case "weekly":  freq = .weekly
        case "monthly": freq = .monthly
        case "yearly":  freq = .yearly
        default:
            throw HelperError.invalidArg(service: "calendar", message: "Unknown recurrence: \(rule). Supported: daily|weekly|monthly|yearly, optional :N interval.")
        }
        return EKRecurrenceRule(recurrenceWith: freq, interval: interval, end: nil)
    }

    private func eventToDict(_ e: EKEvent) -> [String: Any] {
        return [
            "id": e.eventIdentifier ?? "",
            "title": e.title ?? "",
            "start": e.startDate,
            "end": e.endDate,
            "all_day": e.isAllDay,
            "location": e.location ?? "",
            "notes": e.notes ?? "",
            "calendar_id": e.calendar.calendarIdentifier,
            "calendar_title": e.calendar.title,
            "recurrence": e.hasRecurrenceRules ? (e.recurrenceRules?.first.map { "\($0)" } ?? "") : "",
        ]
    }
}

extension JSON {
    /// Convert CGColor to #RRGGBB hex.
    static func hex(from color: CGColor) -> String {
        guard let components = color.components, components.count >= 3 else { return "" }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
