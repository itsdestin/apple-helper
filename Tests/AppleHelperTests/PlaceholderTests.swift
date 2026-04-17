// Placeholder so SwiftPM's AppleHelperTests target has at least one source
// file — without it, SwiftPM's path-resolution fallback collides with the
// executable target at Sources/AppleHelper/ and `swift build` errors out
// with "target 'AppleHelperTests' has overlapping sources".
//
// Task 3 replaces this file with real JSON encoder + error-envelope tests.
import XCTest
@testable import AppleHelper

final class PlaceholderTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
