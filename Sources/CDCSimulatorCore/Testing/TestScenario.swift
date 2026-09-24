import Foundation

public enum TestScenario: String, CaseIterable, Identifiable, Sendable {
    case normalTransfer
    case emptyFileList
    case vinValidationFailure
    case cdcCancel
    case slowTransfer
    case webDAVFailure
    case webSocketDisconnect
    case userCancelNotifyFailure
    case largeFile
    case multiFile

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .normalTransfer: "Normal transfer"
        case .emptyFileList: "Empty fileList"
        case .vinValidationFailure: "VIN validation failure"
        case .cdcCancel: "CDC cancel"
        case .slowTransfer: "Slow download"
        case .webDAVFailure: "WebDAV failure"
        case .webSocketDisconnect: "WebSocket disconnect"
        case .userCancelNotifyFailure: "UserCancel notify failure"
        case .largeFile: "Large file"
        case .multiFile: "Multi-file"
        }
    }

    public var summary: String {
        switch self {
        case .normalTransfer:
            "Push sample_front.mp4"
        case .emptyFileList:
            "Push empty list — SDK should silently ignore"
        case .vinValidationFailure:
            "Push list=null — SDK should report CDC VIN digest mismatch"
        case .cdcCancel:
            "Return transfer response with status=error for the first MP4 request"
        case .slowTransfer:
            "Delay GET for 10 seconds so App cancel can interrupt an active download"
        case .webDAVFailure:
            "Return HTTP 503 for GET"
        case .webSocketDisconnect:
            "Close WebSocket when SDK sends the first transfer request"
        case .userCancelNotifyFailure:
            "Close WebSocket at GET start, then delay 10 seconds for App cancel"
        case .largeFile:
            "Generate ~5 MB file and push single large transfer"
        case .multiFile:
            "Generate 3 files and push all at once"
        }
    }

    public var pushFiles: [String] {
        switch self {
        case .normalTransfer:
            ["sample_front.mp4"]
        case .emptyFileList:
            []
        case .vinValidationFailure:
            []
        case .cdcCancel:
            ["sample_front.mp4"]
        case .slowTransfer:
            ["slow_transfer.mp4"]
        case .webDAVFailure, .webSocketDisconnect:
            ["sample_front.mp4"]
        case .userCancelNotifyFailure:
            ["slow_cancel.mp4"]
        case .largeFile:
            ["large_test.mp4"]
        case .multiFile:
            ["multi_1.mp4", "multi_2.mp4", "multi_3.mp4"]
        }
    }

    public var transferPushFiles: [String]? {
        self == .vinValidationFailure ? nil : pushFiles
    }

    public var webDAVResponseDelay: TimeInterval {
        switch self {
        case .slowTransfer, .userCancelNotifyFailure:
            10
        default:
            0
        }
    }

    public var failsWebDAVGET: Bool {
        self == .webDAVFailure
    }

    public var disconnectWebSocketOnWebDAVGET: Bool {
        self == .userCancelNotifyFailure
    }

    public var fileSpecs: [TestFileSpec] {
        switch self {
        case .normalTransfer, .emptyFileList, .vinValidationFailure, .cdcCancel,
             .webDAVFailure, .webSocketDisconnect:
            []
        case .slowTransfer:
            [TestFileSpec(filename: "slow_transfer.mp4", sizeKB: 1_024)]
        case .userCancelNotifyFailure:
            [TestFileSpec(filename: "slow_cancel.mp4", sizeKB: 1_024)]
        case .largeFile:
            [TestFileSpec(filename: "large_test.mp4", sizeKB: 5_120)]
        case .multiFile:
            [
                TestFileSpec(filename: "multi_1.mp4", sizeKB: 32),
                TestFileSpec(filename: "multi_2.mp4", sizeKB: 48),
                TestFileSpec(filename: "multi_3.mp4", sizeKB: 64),
            ]
        }
    }
}

public struct TestFileSpec: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var filename: String
    public var sizeKB: Int

    public init(id: UUID = UUID(), filename: String, sizeKB: Int) {
        self.id = id
        self.filename = filename
        self.sizeKB = sizeKB
    }
}
