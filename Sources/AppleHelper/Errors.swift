// Sources/AppleHelper/Errors.swift
import Foundation

enum HelperError: Error {
    case tccDenied(service: String, message: String)
    case notFound(service: String, message: String)
    case invalidArg(service: String, message: String)
    case unavailable(service: String, message: String)
    case internalError(service: String, message: String)

    var code: String {
        switch self {
        case .tccDenied:    return "TCC_DENIED"
        case .notFound:     return "NOT_FOUND"
        case .invalidArg:   return "INVALID_ARG"
        case .unavailable:  return "UNAVAILABLE"
        case .internalError: return "INTERNAL"
        }
    }

    var service: String {
        switch self {
        case .tccDenied(let s, _), .notFound(let s, _), .invalidArg(let s, _),
             .unavailable(let s, _), .internalError(let s, _):
            return s
        }
    }

    var message: String {
        switch self {
        case .tccDenied(_, let m), .notFound(_, let m), .invalidArg(_, let m),
             .unavailable(_, let m), .internalError(_, let m):
            return m
        }
    }

    var recovery: String {
        switch self {
        case .tccDenied:
            return "Run /apple-services-setup and re-grant \(service) access, or toggle it back on in System Settings → Privacy & Security."
        case .notFound:
            return "Verify the ID is current (IDs change when items are deleted and recreated)."
        case .invalidArg:
            return "Check the argument values and retry."
        case .unavailable:
            return "The service isn't ready. See the message for specifics."
        case .internalError:
            return "Please report this — unexpected internal failure."
        }
    }

    /// Marker line written to stderr for the wrapper to detect.
    var marker: String {
        switch self {
        case .tccDenied: return "TCC_DENIED:\(service)"
        default: return ""
        }
    }

    var exitCode: Int32 {
        switch self {
        case .tccDenied: return 2
        default: return 1
        }
    }

    func asJSON() -> String {
        let envelope: [String: Any] = [
            "error": [
                "code": code,
                "service": service,
                "message": message,
                "recovery": recovery,
            ]
        ]
        return JSON.encode(envelope)
    }

    /// Write the envelope + marker to stderr, then exit with the right code.
    func writeAndExit() -> Never {
        FileHandle.standardError.write(asJSON().data(using: .utf8)!)
        FileHandle.standardError.write("\n".data(using: .utf8)!)
        if !marker.isEmpty {
            FileHandle.standardError.write(marker.data(using: .utf8)!)
            FileHandle.standardError.write("\n".data(using: .utf8)!)
        }
        exit(exitCode)
    }
}
