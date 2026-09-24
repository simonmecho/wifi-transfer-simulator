import Foundation

public struct SimulatorSettings: Sendable, Equatable {
    public var wifiSSID: String
    public var wifiPassword: String
    public var securityType: String
    public var vehicleVIN: String
    public var videoRootPath: String

    public var webSocketAuthID: String { AuthUtils.basicAuthID(ssid: wifiSSID) }
    public var webSocketAuthPass: String { AuthUtils.basicAuthPass(password: wifiPassword) }

    public init(
        wifiSSID: String = "ChinaNet-SXGE-5G",
        wifiPassword: String = "Sm_20090524",
        securityType: String = "WPA2",
        vehicleVIN: String = "TESTVIN0000000001",
        videoRootPath: String = SimulatorSettings.defaultVideoRoot()
    ) {
        self.wifiSSID = wifiSSID
        self.wifiPassword = wifiPassword
        self.securityType = securityType
        self.vehicleVIN = vehicleVIN
        self.videoRootPath = videoRootPath
    }

    public static func defaultVideoRoot() -> String {
        let fm = FileManager.default
        let candidates = [
            URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("Fixtures/videos", isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent("Fixtures/videos", isDirectory: true),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Fixtures/videos", isDirectory: true),
        ]
        for candidate in candidates where fm.fileExists(atPath: candidate.path) {
            return candidate.path
        }
        return candidates[0].path
    }
}
