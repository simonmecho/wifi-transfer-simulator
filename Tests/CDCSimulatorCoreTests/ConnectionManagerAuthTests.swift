import XCTest
@testable import CDCSimulatorCore

final class ConnectionManagerAuthTests: XCTestCase {
    func testDefaultSettingsDeriveAuthFromWiFiCredentials() async {
        let manager = ConnectionManager()
        let settings = await manager.settings

        XCTAssertEqual(
            settings.webSocketAuthID,
            AuthUtils.basicAuthID(ssid: settings.wifiSSID)
        )
        XCTAssertEqual(
            settings.webSocketAuthPass,
            AuthUtils.basicAuthPass(password: settings.wifiPassword)
        )
    }

    func testUpdateWiFiSyncsAuthPass() async {
        let manager = ConnectionManager()
        await manager.updateWiFi(ssid: "DashCam_TEST", password: "test1234", securityType: "WPA2")

        let expectedID = AuthUtils.basicAuthID(ssid: "DashCam_TEST")
        let expectedPass = AuthUtils.basicAuthPass(password: "test1234")
        let authID = await manager.authID
        let authPass = await manager.authPass
        let settings = await manager.settings

        XCTAssertEqual(authID, expectedID)
        XCTAssertEqual(settings.webSocketAuthID, expectedID)
        XCTAssertEqual(authPass, expectedPass)
        XCTAssertEqual(settings.webSocketAuthPass, expectedPass)
    }

    func testUpdateWiFiRejectsStaleHardcodedPass() async {
        let manager = ConnectionManager()
        await manager.updateWiFi(ssid: "ChinaNet-SXGE-5G", password: "Sm_20090524", securityType: "WPA2")

        let authPass = await manager.authPass
        XCTAssertNotEqual(authPass, "cdc123")
        XCTAssertEqual(authPass, "b6d4d16a")
    }
}
