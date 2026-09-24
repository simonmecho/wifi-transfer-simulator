import XCTest
@testable import CDCSimulatorCore

final class TestScenarioTests: XCTestCase {
    func testTransferScenariosOnlyPushMP4Files() {
        let scenarios: [TestScenario] = [
            .normalTransfer,
            .cdcCancel,
            .slowTransfer,
            .webDAVFailure,
            .webSocketDisconnect,
            .userCancelNotifyFailure,
            .largeFile,
            .multiFile,
        ]

        for scenario in scenarios {
            XCTAssertFalse(scenario.pushFiles.isEmpty)
            XCTAssertTrue(
                scenario.pushFiles.allSatisfy { $0.lowercased().hasSuffix(".mp4") },
                "\(scenario.title) contains a non-MP4 file"
            )
        }
    }

    func testVINValidationFailureUsesNullFileList() {
        XCTAssertNil(TestScenario.vinValidationFailure.transferPushFiles)
        XCTAssertEqual(TestScenario.emptyFileList.transferPushFiles, [])
    }

    func testFailureScenariosExposeExpectedFaultBehavior() {
        XCTAssertEqual(TestScenario.slowTransfer.webDAVResponseDelay, 10)
        XCTAssertTrue(TestScenario.webDAVFailure.failsWebDAVGET)
        XCTAssertTrue(TestScenario.userCancelNotifyFailure.disconnectWebSocketOnWebDAVGET)
        XCTAssertEqual(TestScenario.userCancelNotifyFailure.webDAVResponseDelay, 10)
        XCTAssertFalse(TestScenario.normalTransfer.failsWebDAVGET)
    }
}
