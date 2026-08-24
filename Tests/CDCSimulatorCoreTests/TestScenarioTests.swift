import XCTest
@testable import CDCSimulatorCore

final class TestScenarioTests: XCTestCase {
    func testTransferScenariosOnlyPushMP4Files() {
        let scenarios: [TestScenario] = [
            .normalTransfer,
            .cdcCancel,
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
}
