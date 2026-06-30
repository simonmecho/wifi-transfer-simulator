import Foundation

public enum TestScenario: String, CaseIterable, Identifiable, Sendable {
    case normalTransfer
    case emptyFileList
    case cdcCancel
    case largeFile
    case multiFile

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .normalTransfer: "Normal transfer"
        case .emptyFileList: "Empty fileList"
        case .cdcCancel: "CDC cancel"
        case .largeFile: "Large file"
        case .multiFile: "Multi-file"
        }
    }

    public var summary: String {
        switch self {
        case .normalTransfer:
            "Push sample_front.mp4 + sample_front.json"
        case .emptyFileList:
            "Push empty list — SDK should silently ignore"
        case .cdcCancel:
            "Reject first transfer request with error (UserCancel path)"
        case .largeFile:
            "Generate ~5 MB file and push single large transfer"
        case .multiFile:
            "Generate 3 files and push all at once"
        }
    }

    public var pushFiles: [String] {
        switch self {
        case .normalTransfer:
            ["sample_front.mp4", "sample_front.json"]
        case .emptyFileList:
            []
        case .cdcCancel:
            ["sample_front.mp4", "sample_front.json"]
        case .largeFile:
            ["large_test.mp4"]
        case .multiFile:
            ["multi_1.mp4", "multi_2.mp4", "multi_3.mp4"]
        }
    }

    public var fileSpecs: [TestFileSpec] {
        switch self {
        case .normalTransfer, .emptyFileList, .cdcCancel:
            []
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