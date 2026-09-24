import Foundation
import XCTest
@testable import CDCSimulatorCore

final class CDCWebSocketHandlerTests: XCTestCase {
    func testSuccessfulBasicAuthReturnsSuccessThenVINRequest() async throws {
        let manager = ConnectionManager()
        let settings = await manager.settings
        let handler = CDCWebSocketHandler(manager: manager)
        var request = CDCMessage(cmd: CDCCommand.basicAuthRequest)
        request.id = settings.webSocketAuthID
        request.pass = settings.webSocketAuthPass

        let responses = await handler.responses(for: try request.encoded())

        XCTAssertEqual(responses.count, 2)
        let authResponse = try CDCMessage.decode(from: responses[0])
        XCTAssertEqual(authResponse.cmd, CDCCommand.basicAuthResponse)
        XCTAssertEqual(authResponse.status, "success")
        XCTAssertEqual(authResponse.detail, "")
        let vinRequest = try CDCMessage.decode(from: responses[1])
        XCTAssertEqual(vinRequest.cmd, CDCCommand.vinAuthRequest)
        XCTAssertEqual(vinRequest.vin, settings.vehicleVIN)
    }

    func testFailedBasicAuthDoesNotSendVINRequest() async throws {
        let manager = ConnectionManager()
        let handler = CDCWebSocketHandler(manager: manager)
        var request = CDCMessage(cmd: CDCCommand.basicAuthRequest)
        request.id = "wrong"
        request.pass = "wrong"

        let responses = await handler.responses(for: try request.encoded())

        XCTAssertEqual(responses.count, 1)
        let authResponse = try CDCMessage.decode(from: responses[0])
        XCTAssertEqual(authResponse.status, "error")
    }

    func testCorrectVINDigestCompletesAuthenticationWithoutPush() async throws {
        let manager = ConnectionManager()
        let settings = await manager.settings
        let handler = CDCWebSocketHandler(manager: manager)
        var response = CDCMessage(cmd: CDCCommand.vinAuthResponse)
        response.status = "success"
        response.detail = AuthUtils.vinDigest(vin: settings.vehicleVIN)

        let responses = await handler.responses(for: try response.encoded())

        XCTAssertTrue(responses.isEmpty)
    }

    func testWrongVINDigestReturnsExplicitNullListPush() async throws {
        let manager = ConnectionManager()
        let handler = CDCWebSocketHandler(manager: manager)
        var response = CDCMessage(cmd: CDCCommand.vinAuthResponse)
        response.status = "success"
        response.detail = "00000000"

        let responses = await handler.responses(for: try response.encoded())

        XCTAssertEqual(responses.count, 1)
        let data = try XCTUnwrap(responses[0].data(using: .utf8))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["cmd"] as? String, CDCCommand.transferRequestByPush)
        XCTAssertTrue(object["list"] is NSNull)
    }

    func testVINRejectionDoesNotSendIdleOrTransferPush() async throws {
        let manager = ConnectionManager()
        let handler = CDCWebSocketHandler(manager: manager)
        var response = CDCMessage(cmd: CDCCommand.vinAuthResponse)
        response.status = "error"
        response.detail = "InvalidVIN"

        let responses = await handler.responses(for: try response.encoded())

        XCTAssertTrue(responses.isEmpty)
    }

    func testWebSocketDisconnectScenarioClosesClientWithoutTransferResponse() async throws {
        let manager = ConnectionManager()
        let recorder = HandlerDisconnectRecorder()
        await manager.registerOutbound(id: UUID(), close: {
            recorder.recordClose()
        }) { _ in }
        _ = try await manager.applyScenario(.webSocketDisconnect)
        let handler = CDCWebSocketHandler(manager: manager)
        var request = CDCMessage(cmd: CDCCommand.transferRequest)
        request.list = ["sample_front.mp4"]

        let responses = await handler.responses(for: try request.encoded())

        XCTAssertTrue(responses.isEmpty)
        XCTAssertTrue(recorder.didClose)
        let connectedClientCount = await manager.connectedClientCount
        XCTAssertEqual(connectedClientCount, 0)
    }
}

private final class HandlerDisconnectRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var closed = false

    var didClose: Bool {
        lock.lock()
        defer { lock.unlock() }
        return closed
    }

    func recordClose() {
        lock.lock()
        closed = true
        lock.unlock()
    }
}
