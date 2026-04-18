// Tests/AppleHelperTests/JSONTests.swift
import XCTest
@testable import AppleHelper

final class JSONTests: XCTestCase {
    func testEncodesDateAsISO8601() {
        let date = ISO8601DateFormatter().date(from: "2026-04-17T14:00:00Z")!
        let output = JSON.encode(["start": date])
        XCTAssertTrue(output.contains("\"2026-04-17T14:00:00Z\""))
    }

    func testEncodesArrayOfDictionaries() {
        let input: [[String: Any]] = [
            ["id": "1", "title": "A"],
            ["id": "2", "title": "B"],
        ]
        let output = JSON.encode(input)
        XCTAssertTrue(output.contains("\"id\":\"1\""))
        XCTAssertTrue(output.contains("\"title\":\"B\""))
    }

    func testEncodesEmptyArray() {
        XCTAssertEqual(JSON.encode([[String: Any]]()), "[]")
    }
}
