import XCTest
@testable import CDCSimulatorCore

final class ConnectionManagerAuthTests: XCTestCase {
    func testDefaultSettingsDeriveAuthPassFromWiFiCredentials() async {
        let manager = ConnectionManager()
        let settings = await manager.settings

        XCTAssertEqual(settings.webSocketAuthID, "cdc")
        XCTAssertEqual(
            settings.webSocketAuthPass,
            AuthUtils.webDavToken(ssid: settings.wifiSSID, password: settings.wifiPassword)
        )
    }

    func testUpdateWiFiSyncsAuthPass() async {
        let manager = ConnectionManager()
        await manager.updateWiFi(ssid: "DashCam_TEST", password: "test1234", securityType: "WPA2")

        let expected = AuthUtils.webDavToken(ssid: "DashCam_TEST", password: "test1234")
        let authPass = await manager.authPass
        let settings = await manager.settings

        XCTAssertEqual(authPass, expected)
        XCTAssertEqual(settings.webSocketAuthPass, expected)
    }

    func testUpdateWiFiRejectsStaleHardcodedPass() async {
        let manager = ConnectionManager()
        await manager.updateWiFi(ssid: "ChinaNet-SXGE-5G", password: "Sm_20090524", securityType: "WPA2")

        let authPass = await manager.authPass
        XCTAssertNotEqual(authPass, "cdc123")
        XCTAssertEqual(authPass, "006d1135")
    }
}