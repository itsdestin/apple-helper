// Sources/AppleHelper/Permissions.swift
import ArgumentParser
import Contacts
import EventKit
import Foundation

struct RequestPermissionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "request-permissions",
        abstract: "Serially request Calendar, Reminders, and Contacts access."
    )

    mutating func run() throws {
        let eventStore = EKEventStore()
        let contactStore = CNContactStore()

        // Run serially so the dialogs appear in predictable order.
        let calendarGranted = awaitGrant { completion in
            eventStore.requestFullAccessToEvents { granted, _ in completion(granted) }
        }
        if !calendarGranted {
            HelperError.tccDenied(service: "calendar", message: "Calendar access was denied.").writeAndExit()
        }

        let remindersGranted = awaitGrant { completion in
            eventStore.requestFullAccessToReminders { granted, _ in completion(granted) }
        }
        if !remindersGranted {
            HelperError.tccDenied(service: "reminders", message: "Reminders access was denied.").writeAndExit()
        }

        let contactsGranted = awaitGrant { completion in
            contactStore.requestAccess(for: .contacts) { granted, _ in completion(granted) }
        }
        if !contactsGranted {
            HelperError.tccDenied(service: "contacts", message: "Contacts access was denied.").writeAndExit()
        }

        print(#"{"ok":true,"granted":["calendar","reminders","contacts"]}"#)
    }

    /// Block until the provided async closure calls its completion with the grant result.
    private func awaitGrant(_ request: (@escaping (Bool) -> Void) -> Void) -> Bool {
        let sem = DispatchSemaphore(value: 0)
        var result = false
        request { granted in
            result = granted
            sem.signal()
        }
        sem.wait()
        return result
    }
}
