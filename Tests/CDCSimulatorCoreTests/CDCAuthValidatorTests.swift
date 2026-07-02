import XCTest
@testable import CDCSimulatorCore

final class CDCAuthValidatorTests: XCTestCase {
    func testValidateAcceptsMatchingCredentials() {
        XCTAssertTrue(
            CDCAuthValidator.validate(
                id: "cdc",
                pass: "006d1135",
                expectedID: "cdc",
                expectedPass: "006d1135"
            )
        )
    }

    func testValidateRejectsWrongPassword() {
        XCTAssertFalse(
            CDCAuthValidator.validate(
                id: "cdc",
                pass: "cdc123",
                expectedID: "cdc",
                expectedPass: "006d1135"
            )
        )
    }

    func testValidateRejectsWrongID() {
        XCTAssertFalse(
            CDCAuthValidator.validate(
                id: "other",
                pass: "006d1135",
                expectedID: "cdc",
                expectedPass: "006d1135"
            )
        )
    }

    func testValidateRejectsMissingFields() {
        XCTAssertFalse(
            CDCAuthValidator.validate(
                id: nil,
                pass: "006d1135",
                expectedID: "cdc",
                expectedPass: "006d1135"
            )
        )
    }
}