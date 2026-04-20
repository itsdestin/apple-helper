// Sources/AppleHelper/RootCommand.swift
import ArgumentParser
import Foundation

struct RootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apple-helper",
        abstract: "JSON CLI over EventKit (Calendar, Reminders) and Contacts framework.",
        version: "0.1.0",
        subcommands: [
            CalendarCommand.self,
            RemindersCommand.self,
            ContactsCommand.self,
            RequestPermissionsCommand.self,
        ]
    )
}

// Subcommand implementations live alongside this file:
//   CalendarCommands.swift     (Task 5)
//   RemindersCommands.swift    (Task 6)
//   ContactsCommands.swift     (Task 7)
//   Permissions.swift          (Task 8 — RequestPermissionsCommand)
