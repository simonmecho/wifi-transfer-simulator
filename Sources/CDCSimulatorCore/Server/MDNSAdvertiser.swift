import Foundation

@MainActor
final class MDNSAdvertiser: NSObject, NetServiceDelegate {
    private var service: NetService?
    private let manager: ConnectionManager

    init(manager: ConnectionManager) {
        self.manager = manager
    }

    func start(webSocketPort: Int, name: String = "CDC-Simulator") {
        stop()
        let netService = NetService(
            domain: "",
            type: "_drec._tcp.",
            name: name,
            port: Int32(webSocketPort)
        )
        netService.delegate = self
        netService.publish()
        service = netService
        Task { await manager.appendLog(level: "INFO", message: "mDNS publishing _drec._tcp :\(webSocketPort)") }
    }

    func stop() {
        service?.stop()
        service = nil
    }

    nonisolated func netServiceDidPublish(_ sender: NetService) {
        let name = sender.name
        let port = sender.port
        Task { @MainActor in
            await manager.appendLog(
                level: "INFO",
                message: "mDNS registered _drec._tcp name=\(name) port=\(port)"
            )
        }
    }

    nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        let errorText = String(describing: errorDict)
        Task { @MainActor in
            await manager.appendLog(level: "ERROR", message: "mDNS publish failed: \(errorText)")
        }
    }
}