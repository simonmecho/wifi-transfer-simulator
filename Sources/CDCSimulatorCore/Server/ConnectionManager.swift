import Foundation

public enum LogSource: String, Sendable {
    case system = "SYS"
    case webSocket = "WS"
    case webDAV = "DAV"
}

public struct LogEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let level: String
    public let source: LogSource
    public let message: String
}

public actor ConnectionManager {
    private var outboundHandlers: [UUID: (String) -> Void] = [:]
    public private(set) var logs: [LogEntry] = []
    public private(set) var connectedClientCount = 0
    public private(set) var settings = SimulatorSettings()
    public private(set) var activeScenario: TestScenario?
    private var rejectNextTransfer = false
    private var pendingMoviePath: String?

    public var authID: String { settings.webSocketAuthID }
    public var authPass: String { settings.webSocketAuthPass }

    func registerOutbound(id: UUID, handler: @escaping (String) -> Void) {
        outboundHandlers[id] = handler
        connectedClientCount = outboundHandlers.count
        appendLog(source: .webSocket, level: "INFO", message: "Client connected (\(connectedClientCount) total)")
    }

    func unregisterOutbound(id: UUID) {
        outboundHandlers.removeValue(forKey: id)
        connectedClientCount = outboundHandlers.count
        appendLog(source: .webSocket, level: "INFO", message: "Client disconnected (\(connectedClientCount) remaining)")
    }

    func appendLog(source: LogSource = .system, level: String, message: String) {
        logs.insert(
            LogEntry(id: UUID(), timestamp: Date(), level: level, source: source, message: message),
            at: 0
        )
        if logs.count > 200 {
            logs.removeLast(logs.count - 200)
        }
    }

    public func clearLogs() {
        logs.removeAll()
    }

    func broadcast(text: String) {
        for handler in outboundHandlers.values {
            handler(text)
        }
    }

    public func updateAuth(id: String) {
        settings.webSocketAuthID = id
        settings.webSocketAuthPass = AuthUtils.webDavToken(
            ssid: settings.wifiSSID,
            password: settings.wifiPassword
        )
        appendLog(source: .system, level: "INFO", message: "WebSocket auth credentials updated")
    }

    public func updateWiFi(ssid: String, password: String, securityType: String) {
        settings.wifiSSID = ssid
        settings.wifiPassword = password
        settings.securityType = securityType
        settings.webSocketAuthPass = AuthUtils.webDavToken(ssid: ssid, password: password)
        appendLog(source: .system, level: "INFO", message: "Wi-Fi/WebDAV/WebSocket auth config updated")
    }

    public func updateVideoRoot(path: String) {
        settings.videoRootPath = path
        appendLog(source: .system, level: "INFO", message: "Video root updated: \(path)")
    }

    public func sendTransferRequestByPush(
        files: [String],
        camera: String = "front",
        kind: String = "continuous"
    ) {
        var message = CDCMessage(cmd: CDCCommand.transferRequestByPush)
        message.camera = camera
        message.kind = kind
        message.list = files

        guard let payload = try? message.encoded() else { return }
        appendLog(
            source: .webSocket,
            level: "INFO",
            message: files.isEmpty
                ? "Send transfer request by push: <empty list>"
                : "Send transfer request by push: \(files.joined(separator: ", "))"
        )
        broadcast(text: payload)
    }

    public func generateTestFiles(specs: [TestFileSpec]) throws -> [String] {
        let written = try TestFileGenerator.generate(specs: specs, in: settings.videoRootPath)
        appendLog(
            source: .system,
            level: "INFO",
            message: "Generated \(written.count) test file(s): \(written.joined(separator: ", "))"
        )
        return written
    }

    public func applyScenario(_ scenario: TestScenario) throws -> [String] {
        activeScenario = scenario
        rejectNextTransfer = scenario == .cdcCancel
        pendingMoviePath = nil

        if !scenario.fileSpecs.isEmpty {
            _ = try generateTestFiles(specs: scenario.fileSpecs)
        }

        appendLog(source: .system, level: "INFO", message: "Scenario armed: \(scenario.title)")
        return scenario.pushFiles
    }

    public func clearScenario() {
        activeScenario = nil
        rejectNextTransfer = false
        pendingMoviePath = nil
    }

    func shouldRejectTransfer() -> Bool {
        guard rejectNextTransfer else { return false }
        rejectNextTransfer = false
        return true
    }

    func setPendingMoviePath(_ path: String) {
        pendingMoviePath = path
    }

    func consumePendingMoviePath() -> String? {
        defer { pendingMoviePath = nil }
        return pendingMoviePath
    }
}