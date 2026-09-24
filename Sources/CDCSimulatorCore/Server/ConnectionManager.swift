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
    private struct OutboundClient {
        let send: (String) -> Void
        let close: () -> Void
    }

    private var outboundClients: [UUID: OutboundClient] = [:]
    public private(set) var logs: [LogEntry] = []
    public private(set) var connectedClientCount = 0
    public private(set) var settings = SimulatorSettings()
    public private(set) var activeScenario: TestScenario?
    private var rejectNextTransfer = false
    private var pendingMoviePath: String?

    public var authID: String { settings.webSocketAuthID }
    public var authPass: String { settings.webSocketAuthPass }

    func registerOutbound(
        id: UUID,
        close: @escaping () -> Void = {},
        handler: @escaping (String) -> Void
    ) {
        outboundClients[id] = OutboundClient(send: handler, close: close)
        connectedClientCount = outboundClients.count
        appendLog(source: .webSocket, level: "INFO", message: "Client connected (\(connectedClientCount) total)")
    }

    func unregisterOutbound(id: UUID) {
        guard outboundClients.removeValue(forKey: id) != nil else { return }
        connectedClientCount = outboundClients.count
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
        for client in outboundClients.values {
            client.send(text)
        }
    }

    func disconnectAllClients(reason: String) {
        let clients = Array(outboundClients.values)
        outboundClients.removeAll()
        connectedClientCount = 0
        appendLog(source: .webSocket, level: "WARN", message: "Disconnect all clients: \(reason)")
        for client in clients {
            client.close()
        }
    }

    public func updateWiFi(ssid: String, password: String, securityType: String) {
        settings.wifiSSID = ssid
        settings.wifiPassword = password
        settings.securityType = securityType
        appendLog(source: .system, level: "INFO", message: "Wi-Fi/WebDAV/WebSocket auth config updated")
    }

    public func updateVehicleVIN(_ vin: String) {
        settings.vehicleVIN = vin
        appendLog(source: .system, level: "INFO", message: "VIN auth config updated")
    }

    public func updateVideoRoot(path: String) {
        settings.videoRootPath = path
        appendLog(source: .system, level: "INFO", message: "Video root updated: \(path)")
    }

    public func sendTransferRequestByPush(files: [String]?) {
        guard let payload = try? CDCMessage.transferRequestByPush(files: files) else { return }
        appendLog(
            source: .webSocket,
            level: "INFO",
            message: transferPushLog(files: files)
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

    public func applyScenario(_ scenario: TestScenario) throws -> [String]? {
        activeScenario = scenario
        rejectNextTransfer = scenario == .cdcCancel
        pendingMoviePath = nil

        if !scenario.fileSpecs.isEmpty {
            _ = try generateTestFiles(specs: scenario.fileSpecs)
        }

        appendLog(source: .system, level: "INFO", message: "Scenario armed: \(scenario.title)")
        return scenario.transferPushFiles
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

    private func transferPushLog(files: [String]?) -> String {
        guard let files else {
            return "Send transfer request by push: <null list / VIN digest mismatch>"
        }
        return files.isEmpty
            ? "Send transfer request by push: <empty list>"
            : "Send transfer request by push: \(files.joined(separator: ", "))"
    }
}
