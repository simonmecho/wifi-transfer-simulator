import FlyingFox
import Foundation

struct CDCWebSocketHandler: WSMessageHandler {
    let manager: ConnectionManager

    func makeMessages(for client: AsyncStream<WSMessage>) async throws -> AsyncStream<WSMessage> {
        let clientID = UUID()

        return AsyncStream { continuation in
            continuation.onTermination = { _ in
                Task { await manager.unregisterOutbound(id: clientID) }
            }

            Task {
                await manager.registerOutbound(id: clientID, close: {
                    continuation.finish()
                }) { text in
                    continuation.yield(.text(text))
                }

                for await message in client {
                    switch message {
                    case .text(let text):
                        for response in await responses(for: text) {
                            continuation.yield(.text(response))
                        }
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            for response in await responses(for: text) {
                                continuation.yield(.text(response))
                            }
                        }
                    case .close:
                        continuation.finish()
                        return
                    }
                }
                continuation.finish()
            }
        }
    }

    func responses(for text: String) async -> [String] {
        await manager.appendLog(source: .webSocket, level: "DEBUG", message: sanitizedInboundLog(text))

        guard let message = try? CDCMessage.decode(from: text) else {
            await manager.appendLog(source: .webSocket, level: "ERROR", message: "Invalid JSON payload")
            return []
        }

        switch message.cmd {
        case CDCCommand.basicAuthRequest:
            return await handleBasicAuth(message)
        case CDCCommand.vinAuthResponse:
            return await handleVINAuthResponse(message)
        case CDCCommand.statusNotify:
            await handleStatusNotify(message)
            return []
        case CDCCommand.transferRequest:
            guard let response = await handleTransferRequest(message) else {
                return []
            }
            return [response]
        case CDCCommand.moviePathRequest:
            return [await handleMoviePathRequest(message)]
        default:
            await manager.appendLog(source: .webSocket, level: "WARN", message: "Unhandled cmd: \(message.cmd)")
            return []
        }
    }

    private func handleBasicAuth(_ message: CDCMessage) async -> [String] {
        let expectedID = await manager.authID
        let expectedPass = await manager.authPass
        let ok = CDCAuthValidator.validate(
            id: message.id,
            pass: message.pass,
            expectedID: expectedID,
            expectedPass: expectedPass
        )

        var response = CDCMessage(cmd: CDCCommand.basicAuthResponse)
        response.status = ok ? "success" : "error"
        response.detail = ""

        let level = ok ? "INFO" : "ERROR"
        let suffix = ok ? "OK" : "FAILED"
        await manager.appendLog(source: .webSocket, level: level, message: "Basic Auth \(suffix) (id=\(message.id ?? ""))")

        guard ok else {
            return [(try? response.encoded()) ?? "{\"cmd\":\"basic auth response\",\"status\":\"error\",\"detail\":\"\"}"]
        }

        let settings = await manager.settings
        var vinRequest = CDCMessage(cmd: CDCCommand.vinAuthRequest)
        vinRequest.vin = settings.vehicleVIN
        await manager.appendLog(source: .webSocket, level: "INFO", message: "VIN Auth Request sent")

        guard let authPayload = try? response.encoded(),
              let vinPayload = try? vinRequest.encoded() else {
            return []
        }
        return [authPayload, vinPayload]
    }

    private func handleVINAuthResponse(_ message: CDCMessage) async -> [String] {
        let status = message.status ?? ""
        let detail = message.detail ?? ""
        let expectedVIN = await manager.settings.vehicleVIN

        switch status {
        case "success" where detail == AuthUtils.vinDigest(vin: expectedVIN):
            await manager.appendLog(source: .webSocket, level: "INFO", message: "VIN Auth digest verified")
            return []
        case "success":
            await manager.appendLog(source: .webSocket, level: "ERROR", message: "VIN Auth digest mismatch")
            guard let payload = try? CDCMessage.transferRequestByPush(files: nil) else {
                return []
            }
            return [payload]
        case "error":
            await manager.appendLog(source: .webSocket, level: "WARN", message: "VIN Auth rejected by App")
            return []
        default:
            await manager.appendLog(source: .webSocket, level: "ERROR", message: "Invalid VIN Auth response status")
            return []
        }
    }

    private func handleStatusNotify(_ message: CDCMessage) async {
        let status = message.status ?? ""
        let detail = message.detail ?? ""
        await manager.appendLog(
            source: .webSocket,
            level: "INFO",
            message: "Status notify: status=\(status) detail=\(detail.isEmpty ? "(empty)" : detail)"
        )
    }

    private func handleTransferRequest(_ message: CDCMessage) async -> String? {
        let files = message.list ?? []
        let detail = message.detail ?? ""
        let filename = files.first ?? ""

        if await manager.activeScenario == .webSocketDisconnect {
            await manager.disconnectAllClients(reason: "WebSocket disconnect scenario during transfer request")
            return nil
        }

        if await manager.shouldRejectTransfer() {
            await manager.appendLog(
                source: .webSocket,
                level: "WARN",
                message: "Transfer request rejected (CDC cancel scenario): \(filename)"
            )
            var response = CDCMessage(cmd: CDCCommand.transferResponse)
            response.status = "error"
            return (try? response.encoded()) ?? "{\"cmd\":\"transfer response\",\"status\":\"error\"}"
        }

        await manager.setPendingMoviePath(filename)
        await manager.appendLog(
            source: .webSocket,
            level: "INFO",
            message: "Transfer request accepted: \(filename) detail=\(detail.isEmpty ? "(empty)" : detail)"
        )

        var response = CDCMessage(cmd: CDCCommand.transferResponse)
        response.status = "success"
        return (try? response.encoded()) ?? "{\"cmd\":\"transfer response\",\"status\":\"success\"}"
    }

    private func handleMoviePathRequest(_ message: CDCMessage) async -> String {
        let camera = message.camera ?? "front"
        let kind = message.kind ?? "continuous"
        let path = await manager.consumePendingMoviePath() ?? "sample_front.mp4"

        await manager.appendLog(
            source: .webSocket,
            level: "INFO",
            message: "Movie path response: camera=\(camera) kind=\(kind) path=\(path)"
        )

        var response = CDCMessage(cmd: CDCCommand.moviePathResponse)
        response.camera = camera
        response.kind = kind
        response.path = path
        return (try? response.encoded()) ?? "{\"cmd\":\"movie path response\",\"path\":\"\(path)\"}"
    }

    private func sanitizedInboundLog(_ text: String) -> String {
        guard let message = try? CDCMessage.decode(from: text) else {
            return "RX: <invalid json>"
        }

        switch message.cmd {
        case CDCCommand.basicAuthRequest:
            let id = message.id ?? ""
            return "RX: cmd=\(CDCCommand.basicAuthRequest) id=\(id) pass=<masked>"
        case CDCCommand.vinAuthResponse:
            let status = message.status ?? ""
            return "RX: cmd=\(CDCCommand.vinAuthResponse) status=\(status) detail=<masked>"
        case CDCCommand.statusNotify:
            let status = message.status ?? ""
            let detail = message.detail ?? ""
            return "RX: cmd=\(CDCCommand.statusNotify) status=\(status) detail=\(detail.isEmpty ? "(empty)" : detail)"
        case CDCCommand.transferRequest:
            let files = message.list ?? []
            return "RX: cmd=\(CDCCommand.transferRequest) list=\(files.joined(separator: ", "))"
        case CDCCommand.moviePathRequest:
            let camera = message.camera ?? ""
            let kind = message.kind ?? ""
            return "RX: cmd=\(CDCCommand.moviePathRequest) camera=\(camera) kind=\(kind)"
        default:
            return "RX: cmd=\(message.cmd)"
        }
    }
}
