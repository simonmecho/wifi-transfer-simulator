import Combine
import FlyingFox
import Foundation

@MainActor
public final class WebSocketServerController: ObservableObject {
    public static let webSocketPort: UInt16 = 8490
    public static let webDAVPort: UInt16 = 49150

    @Published public private(set) var isRunning = false
    @Published public private(set) var isWebDAVRunning = false
    @Published public private(set) var isMDNSRunning = false
    @Published public private(set) var lastError: String?

    public let manager = ConnectionManager()
    private var webSocketServer: HTTPServer?
    private var webDAVServer: HTTPServer?
    private var webSocketTask: Task<Void, Never>?
    private var webDAVTask: Task<Void, Never>?
    private var mdnsAdvertiser: MDNSAdvertiser?

    public init() {
        start()
    }

    public func start() {
        guard !isRunning else { return }
        stop()

        startWebSocket()
        startWebDAV()
        startMDNS()
    }

    public func stop() {
        webSocketTask?.cancel()
        webDAVTask?.cancel()
        webSocketTask = nil
        webDAVTask = nil
        webSocketServer = nil
        webDAVServer = nil
        mdnsAdvertiser?.stop()
        mdnsAdvertiser = nil
        isRunning = false
        isWebDAVRunning = false
        isMDNSRunning = false
        Task { await manager.appendLog(level: "INFO", message: "Simulator services stopped") }
    }

    public func pushTransfer(files: [String]) {
        Task { await manager.sendTransferRequestByPush(files: files) }
    }

    public func generateTestFiles(specs: [TestFileSpec]) {
        Task {
            do {
                _ = try await manager.generateTestFiles(specs: specs)
            } catch {
                await manager.appendLog(
                    source: .system,
                    level: "ERROR",
                    message: "Failed to generate test files: \(error.localizedDescription)"
                )
            }
        }
    }

    public func runScenario(_ scenario: TestScenario) {
        Task {
            do {
                let files = try await manager.applyScenario(scenario)
                await manager.sendTransferRequestByPush(files: files)
            } catch {
                await manager.appendLog(
                    source: .system,
                    level: "ERROR",
                    message: "Failed to run scenario \(scenario.title): \(error.localizedDescription)"
                )
            }
        }
    }

    private func startWebSocket() {
        webSocketTask = Task {
            do {
                let handler = CDCWebSocketHandler(manager: manager)
                let server = HTTPServer(port: Self.webSocketPort)
                await server.appendRoute("GET /", to: .webSocket(handler))
                await server.appendRoute("GET /api", to: .webSocket(handler))

                async let runLoop: Void = server.run()
                try await server.waitUntilListening()

                await MainActor.run {
                    self.webSocketServer = server
                    self.isRunning = true
                    self.lastError = nil
                }
                await manager.appendLog(level: "INFO", message: "WebSocket server listening on :\(Self.webSocketPort)")

                try await runLoop
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.isRunning = false
                    self.webSocketServer = nil
                }
                await manager.appendLog(
                    level: "ERROR",
                    message: "WebSocket server failed: \(error.localizedDescription)"
                )
            }
        }
    }

    private func startWebDAV() {
        webDAVTask = Task {
            do {
                let handler = WebDAVFileHandler(manager: manager)
                let server = HTTPServer(port: Self.webDAVPort)
                await server.appendRoute("GET /*", to: handler)

                async let runLoop: Void = server.run()
                try await server.waitUntilListening()

                await MainActor.run {
                    self.webDAVServer = server
                    self.isWebDAVRunning = true
                }
                await manager.appendLog(level: "INFO", message: "WebDAV server listening on :\(Self.webDAVPort)")

                try await runLoop
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.isWebDAVRunning = false
                    self.webDAVServer = nil
                }
                await manager.appendLog(
                    level: "ERROR",
                    message: "WebDAV server failed: \(error.localizedDescription)"
                )
            }
        }
    }

    private func startMDNS() {
        let advertiser = MDNSAdvertiser(manager: manager)
        advertiser.start(webSocketPort: Int(Self.webSocketPort))
        mdnsAdvertiser = advertiser
        isMDNSRunning = true
    }
}