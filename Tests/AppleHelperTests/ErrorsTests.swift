// Tests/AppleHelperTests/ErrorsTests.swift
import XCTest
@testable import AppleHelper

final class ErrorsTests: XCTestCase {
    func testTCCDeniedMarkerFormat() {
        let err = HelperError.tccDenied(service: "calendar", message: "Calendar access was denied.")
        XCTAssertEqual(err.marker, "TCC_DENIED:calendar")
        XCTAssertEqual(err.exitCode, 2)
    }

    func testErrorEnvelopeShape() {
        let err = HelperError.notFound(service: "reminders", message: "No reminder with ID abc.")
        let json = err.asJSON()
        XCTAssertTrue(json.contains("\"code\":\"NOT_FOUND\""))
        XCTAssertTrue(json.contains("\"service\":\"reminders\""))
        XCTAssertTrue(json.contains("\"message\":\"No reminder with ID abc.\""))
    }

    func testAllCodes() {
        let codes: [(HelperError, String)] = [
            (.tccDenied(service: "calendar", message: ""), "TCC_DENIED"),
            (.notFound(service: "calendar", message: ""), "NOT_FOUND"),
            (.invalidArg(service: "calendar", message: ""), "INVALID_ARG"),
            (.unavailable(service: "calendar", message: ""), "UNAVAILABLE"),
            (.internalError(service: "calendar", message: ""), "INTERNAL"),
        ]
        for (err, code) in codes {
            XCTAssertTrue(err.asJSON().contains("\"code\":\"\(code)\""))
        }
    }
}
