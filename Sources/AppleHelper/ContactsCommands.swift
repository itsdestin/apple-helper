// Sources/AppleHelper/ContactsCommands.swift
import ArgumentParser
import Contacts
import Foundation

struct ContactsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "contacts",
        abstract: "Contacts operations (Contacts framework)."
    )

    @Argument(help: "Operation. One of: search, get, list_groups, list_group_members, create, update, add_to_group, remove_from_group.")
    var op: String

    @Option(name: .long) var query: String?
    @Option(name: .long) var id: String?
    @Option(name: .long) var contactId: String?
    @Option(name: .long) var groupId: String?
    @Option(name: .long) var first: String?
    @Option(name: .long) var last: String?
    @Option(name: .long) var organization: String?
    @Option(name: .long) var notes: String?
    @Option(name: [.customLong("phones")], parsing: .upToNextOption) var phones: [String] = []
    @Option(name: [.customLong("emails")], parsing: .upToNextOption) var emails: [String] = []
    @Option(name: .long) var limit: Int?

    private static let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactNoteKey as CNKeyDescriptor,
        CNContactImageDataAvailableKey as CNKeyDescriptor,
    ]

    mutating func run() throws {
        let store = CNContactStore()
        do {
            switch op {
            case "search":
                guard let q = query else { throw HelperError.invalidArg(service: "contacts", message: "search requires --query") }
                let predicate = CNContact.predicateForContacts(matchingName: q)
                var results: [CNContact] = []
                do {
                    results = try store.unifiedContacts(matching: predicate, keysToFetch: Self.keysToFetch)
                } catch {
                    // Name predicate isn't exhaustive — some matches live in phone/email/org.
                    // Fall back: enumerate all, filter in memory. Slow but v1-acceptable.
                    let fetchReq = CNContactFetchRequest(keysToFetch: Self.keysToFetch)
                    try store.enumerateContacts(with: fetchReq) { contact, _ in
                        let needle = q.lowercased()
                        let hay = [contact.givenName, contact.familyName, contact.organizationName,
                                   contact.phoneNumbers.map { $0.value.stringValue }.joined(separator: " "),
                                   contact.emailAddresses.map { $0.value as String }.joined(separator: " ")]
                            .joined(separator: " ").lowercased()
                        if hay.contains(needle) { results.append(contact) }
                    }
                }
                let cap = limit ?? 50
                let truncated = Array(results.prefix(cap))
                print(JSON.encode(truncated.map(contactToDict)))

            case "get":
                guard let id = id else { throw HelperError.invalidArg(service: "contacts", message: "get requires --id") }
                do {
                    let c = try store.unifiedContact(withIdentifier: id, keysToFetch: Self.keysToFetch)
                    print(JSON.encode(contactToDict(c)))
                } catch {
                    throw HelperError.notFound(service: "contacts", message: "No contact with id \(id)")
                }

            case "list_groups":
                let groups = try store.groups(matching: nil)
                print(JSON.encode(groups.map { ["id": $0.identifier, "name": $0.name] as [String: Any] }))

            case "list_group_members":
                guard let gid = groupId else { throw HelperError.invalidArg(service: "contacts", message: "list_group_members requires --group-id") }
                let predicate = CNContact.predicateForContactsInGroup(withIdentifier: gid)
                let members = try store.unifiedContacts(matching: predicate, keysToFetch: Self.keysToFetch)
                print(JSON.encode(members.map(contactToDict)))

            case "create":
                guard let first = first else { throw HelperError.invalidArg(service: "contacts", message: "create requires --first") }
                let c = CNMutableContact()
                c.givenName = first
                if let last = last { c.familyName = last }
                if let org = organization { c.organizationName = org }
                c.phoneNumbers = phones.map { CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: $0)) }
                c.emailAddresses = emails.map { CNLabeledValue(label: CNLabelHome, value: $0 as NSString) }
                if let n = notes { c.note = n }
                let req = CNSaveRequest()
                req.add(c, toContainerWithIdentifier: nil)
                try store.execute(req)
                // Re-fetch so identifier is stable + return shape matches `get`.
                let fetched = try store.unifiedContact(withIdentifier: c.identifier, keysToFetch: Self.keysToFetch)
                print(JSON.encode(contactToDict(fetched)))

            case "update":
                guard let id = id else { throw HelperError.invalidArg(service: "contacts", message: "update requires --id") }
                let existing = try store.unifiedContact(withIdentifier: id, keysToFetch: Self.keysToFetch)
                // unifiedContact is immutable; need mutable copy from the underlying contact.
                guard let mutable = existing.mutableCopy() as? CNMutableContact else {
                    throw HelperError.internalError(service: "contacts", message: "Couldn't obtain mutable copy of \(id)")
                }
                if let f = first { mutable.givenName = f }
                if let l = last { mutable.familyName = l }
                if let o = organization { mutable.organizationName = o }
                if !phones.isEmpty {
                    mutable.phoneNumbers = phones.map { CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: $0)) }
                }
                if !emails.isEmpty {
                    mutable.emailAddresses = emails.map { CNLabeledValue(label: CNLabelHome, value: $0 as NSString) }
                }
                if let n = notes { mutable.note = n }
                let req = CNSaveRequest()
                req.update(mutable)
                try store.execute(req)
                let refreshed = try store.unifiedContact(withIdentifier: id, keysToFetch: Self.keysToFetch)
                print(JSON.encode(contactToDict(refreshed)))

            case "add_to_group":
                guard let cid = contactId, let gid = groupId else {
                    throw HelperError.invalidArg(service: "contacts", message: "add_to_group requires --contact-id --group-id")
                }
                let contact = try store.unifiedContact(withIdentifier: cid, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
                let groups = try store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: [gid]))
                guard let group = groups.first else {
                    throw HelperError.notFound(service: "contacts", message: "No group with id \(gid)")
                }
                let req = CNSaveRequest()
                req.addMember(contact, to: group)
                try store.execute(req)
                print(#"{"ok":true}"#)

            case "remove_from_group":
                guard let cid = contactId, let gid = groupId else {
                    throw HelperError.invalidArg(service: "contacts", message: "remove_from_group requires --contact-id --group-id")
                }
                let contact = try store.unifiedContact(withIdentifier: cid, keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
                let groups = try store.groups(matching: CNGroup.predicateForGroups(withIdentifiers: [gid]))
                guard let group = groups.first else {
                    throw HelperError.notFound(service: "contacts", message: "No group with id \(gid)")
                }
                let req = CNSaveRequest()
                req.removeMember(contact, from: group)
                try store.execute(req)
                print(#"{"ok":true}"#)

            default:
                throw HelperError.invalidArg(service: "contacts", message: "Unknown op: \(op)")
            }
        } catch let e as HelperError {
            e.writeAndExit()
        } catch let e as CNError where e.code == .authorizationDenied {
            HelperError.tccDenied(service: "contacts", message: "Contacts access was denied.").writeAndExit()
        } catch {
            HelperError.internalError(service: "contacts", message: String(describing: error)).writeAndExit()
        }
    }

    private func contactToDict(_ c: CNContact) -> [String: Any] {
        let note: String = {
            // CNContactNoteKey is restricted since macOS 13 — requires entitlement for some apps.
            // Ad-hoc signed binaries with usage-description may not get notes; fall back to "".
            if c.isKeyAvailable(CNContactNoteKey) { return (try? c.note) ?? "" }
            return ""
        }()
        return [
            "id": c.identifier,
            "first": c.givenName,
            "last": c.familyName,
            "organization": c.organizationName,
            "phones": c.phoneNumbers.map { ["label": CNLabeledValue<NSString>.localizedString(forLabel: $0.label ?? ""), "value": $0.value.stringValue] as [String: Any] },
            "emails": c.emailAddresses.map { ["label": CNLabeledValue<NSString>.localizedString(forLabel: $0.label ?? ""), "value": $0.value as String] as [String: Any] },
            "notes": note,
            "image_data": c.imageDataAvailable,
        ]
    }
}

extension CNContact {
    func isKeyAvailable(_ key: String) -> Bool {
        return (self as NSObject).responds(to: NSSelectorFromString(key))
    }
}
