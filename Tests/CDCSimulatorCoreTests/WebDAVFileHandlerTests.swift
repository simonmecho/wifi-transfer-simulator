import FlyingFox
import Foundation
import XCTest
@testable import CDCSimulatorCore

final class WebDAVFileHandlerTests: XCTestCase {
    func testHEADIsRejectedAndGETReturnsContentLength() async throws {
        let fileData = Data(repeating: 0x42, count: 1_024)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try fileData.write(to: directory.appendingPathComponent("sample.mp4"))

        let manager = ConnectionManager()
        await manager.updateVideoRoot(path: directory.path)
        let handler = WebDAVFileHandler(manager: manager)
        let authorization = await makeAuthorization(manager: manager)

        let headResponse = try await handler.handleRequest(
            makeRequest(method: .HEAD, path: "/sample.mp4", authorization: authorization)
        )
        XCTAssertEqual(headResponse.statusCode, .methodNotAllowed)

        let getResponse = try await handler.handleRequest(
            makeRequest(method: .GET, path: "/sample.mp4", authorization: authorization)
        )
        XCTAssertEqual(getResponse.statusCode, .ok)
        XCTAssertEqual(getResponse.headers[.contentLength], "1024")
        let getBody = try await getResponse.bodyData
        XCTAssertEqual(getBody, fileData)
    }

    func testWebDAVFailureScenarioReturnsServiceUnavailable() async throws {
        let manager = ConnectionManager()
        _ = try await manager.applyScenario(.webDAVFailure)
        let handler = WebDAVFileHandler(manager: manager)
        let authorization = await makeAuthorization(manager: manager)

        let response = try await handler.handleRequest(
            makeRequest(method: .GET, path: "/sample.mp4", authorization: authorization)
        )

        XCTAssertEqual(response.statusCode, .serviceUnavailable)
    }

    func testUserCancelNotifyFailureScenarioDisconnectsWebSocketWhenGETStarts() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let manager = ConnectionManager()
        await manager.updateVideoRoot(path: directory.path)
        _ = try await manager.applyScenario(.userCancelNotifyFailure)
        let disconnected = expectation(description: "WebSocket disconnected")
        await manager.registerOutbound(id: UUID(), close: {
            disconnected.fulfill()
        }) { _ in }
        let handler = WebDAVFileHandler(manager: manager)
        let authorization = await makeAuthorization(manager: manager)
        let request = makeRequest(
            method: .GET,
            path: "/slow_cancel.mp4",
            authorization: authorization
        )

        let requestTask = Task {
            try await handler.handleRequest(request)
        }
        await fulfillment(of: [disconnected], timeout: 1)
        requestTask.cancel()
        _ = try? await requestTask.value

        let connectedClientCount = await manager.connectedClientCount
        XCTAssertEqual(connectedClientCount, 0)
    }

    private func makeAuthorization(manager: ConnectionManager) async -> String {
        let settings = await manager.settings
        let token = AuthUtils.webDavToken(ssid: settings.wifiSSID, password: settings.wifiPassword)
        let credentials = Data("user:\(token)".utf8).base64EncodedString()
        return "Basic \(credentials)"
    }

    private func makeRequest(method: HTTPMethod, path: String, authorization: String) -> HTTPRequest {
        var headers = HTTPHeaders()
        headers[.authorization] = authorization
        return HTTPRequest(
            method: method,
            version: .http11,
            path: path,
            query: [],
            headers: headers,
            body: HTTPBodySequence()
        )
    }
}
