import XCTest
import SwiftUI
@testable import HermesGlass

final class HermesGlassTests: XCTestCase {
    func testSpacingScaleIsMonotonic() {
        XCTAssertLessThan(Tokens.Space.xs, Tokens.Space.sm)
        XCTAssertLessThan(Tokens.Space.sm, Tokens.Space.md)
        XCTAssertLessThan(Tokens.Space.lg, Tokens.Space.xl)
        XCTAssertLessThan(Tokens.Space.xl, Tokens.Space.xxl)
    }

    func testThemeDefaultsToAccent() {
        XCTAssertEqual(HermesTheme().accent, Tokens.accent)
    }

    func testStatusPillStateLabels() {
        XCTAssertEqual(StatusPill.State.ok("Connected").label, "Connected")
        XCTAssertEqual(StatusPill.State.bad("Offline").color, .red)
    }
}
