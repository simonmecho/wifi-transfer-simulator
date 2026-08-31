import Foundation
import XCTest
@testable import CDCSimulatorCore

final class ConnectionManagerPushTests: XCTestCase {
    func testTransferPushContainsOnlyCommandAndFileList() async throws {
        let manager = ConnectionManager()
        let recorder = PayloadRecorder()
        await manager.registerOutbound(id: UUID()) { payload in
            recorder.record(payload)
        }

        let files = ["230707000052_DUA.MP4", "230707000052_DUF.MP4"]
        await manager.sendTransferRequestByPush(files: files)

        let payload = try XCTUnwrap(recorder.value)
        let data = try XCTUnwrap(payload.data(using: .utf8))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(Set(object.keys), ["cmd", "list"])
        XCTAssertEqual(object["cmd"] as? String, CDCCommand.transferRequestByPush)
        XCTAssertEqual(object["list"] as? [String], files)
    }
}

private final class PayloadRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var payload: String?

    var value: String? {
        lock.lock()
        defer { lock.unlock() }
        return payload
    }

    func record(_ payload: String) {
        lock.lock()
        self.payload = payload
        lock.unlock()
    }
}
