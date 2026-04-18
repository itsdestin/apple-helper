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

// Placeholder subcommands so the package compiles before Task 6-8 fill them in.
// CalendarCommand is defined in CalendarCommands.swift (wired in Task 5).
struct RemindersCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "reminders", abstract: "Reminders ops.")
    @Argument var op: String
    @Argument(parsing: .captureForPassthrough) var rest: [String] = []
    mutating func run() throws { throw ValidationError("Reminders ops not wired yet — see Task 6.") }
}

struct ContactsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "contacts", abstract: "Contacts ops.")
    @Argument var op: String
    @Argument(parsing: .captureForPassthrough) var rest: [String] = []
    mutating func run() throws { throw ValidationError("Contacts ops not wired yet — see Task 7.") }
}

struct RequestPermissionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "request-permissions", abstract: "Serially request EventKit + Contacts permissions.")
    mutating func run() throws { throw ValidationError("Permissions flow not wired yet — see Task 8.") }
}
