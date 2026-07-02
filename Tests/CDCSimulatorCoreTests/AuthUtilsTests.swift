import XCTest
@testable import CDCSimulatorCore

final class AuthUtilsTests: XCTestCase {
    func testWebDavTokenMatchesKnownDefaultCredentials() {
        XCTAssertEqual(
            AuthUtils.webDavToken(ssid: "ChinaNet-SXGE-5G", password: "Sm_20090524"),
            "006d1135"
        )
    }

    func testWebDavTokenChangesWhenSSIDOrPasswordChanges() {
        let baseline = AuthUtils.webDavToken(ssid: "DashCam_TEST", password: "test1234")
        XCTAssertEqual(baseline.count, 8)
        XCTAssertNotEqual(
            AuthUtils.webDavToken(ssid: "DashCam_TEST", password: "other"),
            baseline
        )
        XCTAssertNotEqual(
            AuthUtils.webDavToken(ssid: "Other_SSID", password: "test1234"),
            baseline
        )
    }
}