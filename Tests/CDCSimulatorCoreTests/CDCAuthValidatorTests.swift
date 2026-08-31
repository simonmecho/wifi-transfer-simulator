import XCTest
@testable import CDCSimulatorCore

final class CDCAuthValidatorTests: XCTestCase {
    func testValidateAcceptsMatchingCredentials() {
        XCTAssertTrue(
            CDCAuthValidator.validate(
                id: "1357f7d3",
                pass: "b6d4d16a",
                expectedID: "1357f7d3",
                expectedPass: "b6d4d16a"
            )
        )
    }

    func testValidateRejectsWrongPassword() {
        XCTAssertFalse(
            CDCAuthValidator.validate(
                id: "1357f7d3",
                pass: "cdc123",
                expectedID: "1357f7d3",
                expectedPass: "b6d4d16a"
            )
        )
    }

    func testValidateRejectsWrongID() {
        XCTAssertFalse(
            CDCAuthValidator.validate(
                id: "other",
                pass: "b6d4d16a",
                expectedID: "1357f7d3",
                expectedPass: "b6d4d16a"
            )
        )
    }

    func testValidateRejectsMissingFields() {
        XCTAssertFalse(
            CDCAuthValidator.validate(
                id: nil,
                pass: "b6d4d16a",
                expectedID: "1357f7d3",
                expectedPass: "b6d4d16a"
            )
        )
    }
}
