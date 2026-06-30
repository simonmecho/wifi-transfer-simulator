import Foundation

public struct SimulatorSettings: Sendable, Equatable {
    public var wifiSSID: String
    public var wifiPassword: String
    public var webSocketAuthID: String
    public var webSocketAuthPass: String
    public var videoRootPath: String

    public init(
        wifiSSID: String = "DashCam_TEST",
        wifiPassword: String = "test1234",
        webSocketAuthID: String = "cdc",
        webSocketAuthPass: String = "cdc123",
        videoRootPath: String = SimulatorSettings.defaultVideoRoot()
    ) {
        self.wifiSSID = wifiSSID
        self.wifiPassword = wifiPassword
        self.webSocketAuthID = webSocketAuthID
        self.webSocketAuthPass = webSocketAuthPass
        self.videoRootPath = videoRootPath
    }

    public static func defaultVideoRoot() -> String {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidate = cwd.appendingPathComponent("Fixtures/videos", isDirectory: true)
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate.path
        }
        return cwd.appendingPathComponent("simulator/Fixtures/videos", isDirectory: true).path
    }
}