// Sources/AppleHelper/RemindersCommands.swift
import ArgumentParser
import EventKit
import Foundation

struct RemindersCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reminders",
        abstract: "Reminders operations (EventKit)."
    )

    @Argument(help: "Operation name. One of: list_lists, list_reminders, get_reminder, create_reminder, update_reminder, complete_reminder, delete_reminder.")
    var op: String

    @Option(name: .long) var listId: String?
    @Option(name: .long) var id: String?
    @Option(name: .long) var title: String?
    @Option(name: .long) var due: String?
    @Option(name: .long) var priority: Int?
    @Option(name: .long) var notes: String?
    @Flag(name: .long) var incompleteOnly: Bool = false

    mutating func run() throws {
        let store = EKEventStore()
        // TCC gate: EventKit read APIs return empty instead of erroring on denied
        // access, and writes throw generic errors. Probe auth up front so the
        // wrapper sees a clean TCC_DENIED marker instead of misleading "no reminders".
        let authStatus = EKEventStore.authorizationStatus(for: .reminder)
        guard authStatus == .fullAccess else {
            HelperError.tccDenied(
                service: "reminders",
                message: "Reminders access not granted (status: \(authStatus.rawValue)). Run /apple-services-setup or grant in System Settings → Privacy & Security → Reminders."
            ).writeAndExit()
        }
        do {
            switch op {
            case "list_lists":
                let lists = store.calendars(for: .reminder)
                let json = lists.map { l in
                    [
                        "id": l.calendarIdentifier,
                        "title": l.title,
                        "color": l.cgColor.map { JSON.hex(from: $0) } ?? "",
                    ] as [String: Any]
                }
                print(JSON.encode(json))

            case "list_reminders":
                let cals = listId.flatMap { lid in store.calendars(for: .reminder).filter { $0.calendarIdentifier == lid } }
                let predicate = incompleteOnly
                    ? store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: cals)
                    : store.predicateForReminders(in: cals)
                let reminders = try fetchReminders(store: store, predicate: predicate)
                print(JSON.encode(reminders.map(reminderToDict)))

            case "get_reminder":
                guard let id = id else { throw HelperError.invalidArg(service: "reminders", message: "get_reminder requires --id") }
                guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else {
                    throw HelperError.notFound(service: "reminders", message: "No reminder with id \(id)")
                }
                print(JSON.encode(reminderToDict(r)))

            case "create_reminder":
                guard let title = title, let lid = listId else {
                    throw HelperError.invalidArg(service: "reminders", message: "create_reminder requires --title --list-id")
                }
                guard let cal = store.calendars(for: .reminder).first(where: { $0.calendarIdentifier == lid }) else {
                    throw HelperError.notFound(service: "reminders", message: "No list with id \(lid)")
                }
                let r = EKReminder(eventStore: store)
                r.calendar = cal
                r.title = title
                if let d = due {
                    r.dueDateComponents = try dateComponents(from: parseDate(d))
                }
                if let p = priority { r.priority = p }
                if let n = notes { r.notes = n }
                try store.save(r, commit: true)
                print(JSON.encode(reminderToDict(r)))

            case "update_reminder":
                guard let id = id else { throw HelperError.invalidArg(service: "reminders", message: "update_reminder requires --id") }
                guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else {
                    throw HelperError.notFound(service: "reminders", message: "No reminder with id \(id)")
                }
                if let t = title { r.title = t }
                if let d = due { r.dueDateComponents = try dateComponents(from: parseDate(d)) }
                if let p = priority { r.priority = p }
                if let n = notes { r.notes = n }
                try store.save(r, commit: true)
                print(JSON.encode(reminderToDict(r)))

            case "complete_reminder":
                guard let id = id else { throw HelperError.invalidArg(service: "reminders", message: "complete_reminder requires --id") }
                guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else {
                    throw HelperError.notFound(service: "reminders", message: "No reminder with id \(id)")
                }
                r.isCompleted = true
                try store.save(r, commit: true)
                print(#"{"ok":true}"#)

            case "delete_reminder":
                guard let id = id else { throw HelperError.invalidArg(service: "reminders", message: "delete_reminder requires --id") }
                guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else {
                    throw HelperError.notFound(service: "reminders", message: "No reminder with id \(id)")
                }
                try store.remove(r, commit: true)
                print(#"{"ok":true}"#)

            default:
                throw HelperError.invalidArg(service: "reminders", message: "Unknown op: \(op)")
            }
        } catch let e as HelperError {
            e.writeAndExit()
        } catch {
            // EventKit denial paths are handled by the upfront authStatus gate
            // (EKError.Code has no `.denied` case — the plan assumed an API that
            // doesn't exist). Anything reaching here is genuinely unexpected.
            HelperError.internalError(service: "reminders", message: String(describing: error)).writeAndExit()
        }
    }

    /// EventKit's reminder query is async-only. Bridge to sync via a semaphore
    /// so the CLI op model stays "one invocation = one blocking call".
    private func fetchReminders(store: EKEventStore, predicate: NSPredicate) throws -> [EKReminder] {
        let sem = DispatchSemaphore(value: 0)
        var result: [EKReminder] = []
        store.fetchReminders(matching: predicate) { reminders in
            result = reminders ?? []
            sem.signal()
        }
        _ = sem.wait(timeout: .now() + 10)
        return result
    }

    private func parseDate(_ s: String) throws -> Date {
        if let d = JSON.iso8601.date(from: s) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.timeZone = .current
        if let d = f.date(from: s) { return d }
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = .current
        if let d = dateOnly.date(from: s) { return d }
        throw HelperError.invalidArg(service: "reminders", message: "Invalid date: \(s)")
    }

    private func dateComponents(from date: Date) throws -> DateComponents {
        let cal = Calendar.current
        return cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    }

    private func reminderToDict(_ r: EKReminder) -> [String: Any] {
        var d: [String: Any] = [
            "id": r.calendarItemIdentifier,
            "title": r.title ?? "",
            "completed": r.isCompleted,
            "list_id": r.calendar.calendarIdentifier,
            "list_title": r.calendar.title,
            "notes": r.notes ?? "",
            "priority": r.priority,
        ]
        if let due = r.dueDateComponents, let date = Calendar.current.date(from: due) {
            d["due"] = date
        }
        return d
    }
}
