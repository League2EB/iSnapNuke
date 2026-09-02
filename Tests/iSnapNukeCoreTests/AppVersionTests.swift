import XCTest
@testable import iSnapNukeCore

final class AppVersionTests: XCTestCase {
    func testSemanticVersionParsesAndComparesThreePartVersions() throws {
        let patch = try SemanticVersion("1.2.3")
        let minor = try SemanticVersion("1.3.0")
        let major = try SemanticVersion("2.0.0")

        XCTAssertEqual(patch.description, "1.2.3")
        XCTAssertLessThan(patch, minor)
        XCTAssertLessThan(minor, major)
    }

    func testSemanticVersionRejectsIncompleteOrDecoratedValues() {
        for value in ["1", "1.2", "1.2.3.4", "v1.2.3", "1.02.3", "1.-2.3"] {
            XCTAssertThrowsError(try SemanticVersion(value), "Expected \(value) to fail")
        }
    }

    func testBuildNumberTakesPriorityForUpdateOrdering() throws {
        let oldMarketingVersion = try AppVersion(marketingVersion: "2.0.0", build: "1")
        let newMarketingVersion = try AppVersion(marketingVersion: "1.0.0", build: "2")

        XCTAssertLessThan(oldMarketingVersion, newMarketingVersion)
    }

    func testRejectsNonPositiveBuildNumbers() {
        XCTAssertThrowsError(try AppVersion(marketingVersion: "1.0.0", build: "0"))
        XCTAssertThrowsError(try AppVersion(marketingVersion: "1.0.0", build: "-1"))
        XCTAssertThrowsError(try AppVersion(marketingVersion: "1.0.0", build: "one"))
    }
}
