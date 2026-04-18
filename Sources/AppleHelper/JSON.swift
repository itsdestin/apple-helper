// Sources/AppleHelper/JSON.swift
import Foundation

enum JSON {
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Encode a JSON-compatible value (dict, array, scalar) to a compact JSON string.
    /// Dates are stringified ISO-8601 before encoding.
    static func encode(_ value: Any) -> String {
        let normalized = normalize(value)
        guard let data = try? JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys]) else {
            return "null"
        }
        return String(data: data, encoding: .utf8) ?? "null"
    }

    private static func normalize(_ value: Any) -> Any {
        switch value {
        case let date as Date:
            return iso8601.string(from: date)
        case let dict as [String: Any]:
            return dict.mapValues { normalize($0) }
        case let arr as [Any]:
            return arr.map { normalize($0) }
        case let arrDict as [[String: Any]]:
            return arrDict.map { $0.mapValues { normalize($0) } }
        default:
            return value
        }
    }
}
