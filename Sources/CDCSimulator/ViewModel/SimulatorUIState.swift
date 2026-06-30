import CDCSimulatorCore
import CryptoKit
import Foundation

enum SidebarTab: String, CaseIterable, Identifiable {
    case dashboard
    case scenarios
    case files
    case settings
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "仪表盘"
        case .scenarios: "场景"
        case .files: "文件"
        case .settings: "设置"
        case .logs: "日志"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .scenarios: "play.rectangle"
        case .files: "doc"
        case .settings: "gearshape"
        case .logs: "list.bullet.rectangle"
        }
    }
}

struct VideoFileRow: Identifiable, Equatable {
    let id: String
    let name: String
    let sizeLabel: String
}

@MainActor
final class SimulatorUIState: ObservableObject {
    @Published var selectedTab: SidebarTab = .dashboard
    @Published var logs: [LogEntry] = []
    @Published var connectedCount = 0
    @Published var activeScenarioTitle: String?
    @Published var servicesStartedAt: Date?

    @Published var wifiSSID = "DashCam_TEST"
    @Published var wifiPassword = "test1234"
    @Published var authID = "cdc"
    @Published var authPass = "cdc123"
    @Published var videoRootPath = SimulatorSettings.defaultVideoRoot()

    @Published var pushFilesText = "sample_front.mp4,sample_front.json"
    @Published var testFileSpecs: [TestFileSpec] = [
        TestFileSpec(filename: "sample_front.mp4", sizeKB: 1),
        TestFileSpec(filename: "sample_front.json", sizeKB: 1),
    ]
    @Published var videoFiles: [VideoFileRow] = []
    @Published var selectedVideoFiles = Set<String>()

    @Published var customScenarioFiles = "sample_front.mp4,sample_front.json"
    @Published var customRejectTransfer = false
    @Published var customEmptyFileList = false

    @Published var logSearchText = ""
    @Published var logSourceFilter: LogSourceFilter = .all
    @Published var logLevelFilter: LogLevelFilter = .all

    private weak var controller: WebSocketServerController?

    func bind(controller: WebSocketServerController) {
        self.controller = controller
    }

    var isAnyServiceRunning: Bool {
        guard let controller else { return false }
        return controller.isRunning || controller.isWebDAVRunning || controller.isMDNSRunning
    }

    var uptimeLabel: String {
        guard let servicesStartedAt, isAnyServiceRunning else { return "—" }
        let elapsed = Int(Date().timeIntervalSince(servicesStartedAt))
        let hours = elapsed / 3600
        let minutes = (elapsed % 3600) / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var webDavTokenPreview: String {
        let digest = Insecure.MD5.hash(data: Data((wifiSSID + wifiPassword).utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(8))
    }

    var filteredLogs: [LogEntry] {
        logs.filter { entry in
            logSourceFilter.includes(entry.source)
                && logLevelFilter.includes(entry.level)
                && (logSearchText.isEmpty || entry.message.localizedCaseInsensitiveContains(logSearchText))
        }
    }

    func loadDefaults() async {
        guard let controller else { return }
        let settings = await controller.manager.settings
        wifiSSID = settings.wifiSSID
        wifiPassword = settings.wifiPassword
        videoRootPath = settings.videoRootPath
        authID = settings.webSocketAuthID
        authPass = settings.webSocketAuthPass
        await refresh()
    }

    func refresh() async {
        guard let controller else { return }
        logs = await controller.manager.logs
        connectedCount = await controller.manager.connectedClientCount
        if let scenario = await controller.manager.activeScenario {
            activeScenarioTitle = scenario.title
        } else {
            activeScenarioTitle = nil
        }

        if isAnyServiceRunning {
            if servicesStartedAt == nil {
                servicesStartedAt = Date()
            }
        } else {
            servicesStartedAt = nil
        }

        reloadVideoFiles()
    }

    func reloadVideoFiles() {
        let url = URL(fileURLWithPath: videoRootPath, isDirectory: true)
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            videoFiles = []
            return
        }

        videoFiles = items
            .filter { $0.hasDirectoryPath == false }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { fileURL in
                let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return VideoFileRow(
                    id: fileURL.lastPathComponent,
                    name: fileURL.lastPathComponent,
                    sizeLabel: Self.formatBytes(Int64(size))
                )
            }
    }

    func startServices() {
        controller?.start()
        Task { await refresh() }
    }

    func stopServices() {
        controller?.stop()
        Task { await refresh() }
    }

    func applyWiFiSettings() {
        guard let controller else { return }
        Task {
            await controller.manager.updateWiFi(ssid: wifiSSID, password: wifiPassword)
            await refresh()
        }
    }

    func applyAuthSettings() {
        guard let controller else { return }
        Task {
            await controller.manager.updateAuth(id: authID, pass: authPass)
            await refresh()
        }
    }

    func applyVideoRoot() {
        guard let controller else { return }
        Task {
            await controller.manager.updateVideoRoot(path: videoRootPath)
            await refresh()
        }
    }

    func runScenario(_ scenario: TestScenario) {
        controller?.runScenario(scenario)
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await refresh()
        }
    }

    func runCustomScenario() {
        guard let controller else { return }
        let files = customEmptyFileList
            ? []
            : customScenarioFiles
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

        Task {
            do {
                if customRejectTransfer {
                    _ = try await controller.manager.applyScenario(.cdcCancel)
                    if !customEmptyFileList {
                        await controller.manager.sendTransferRequestByPush(files: files)
                    }
                } else {
                    await controller.manager.sendTransferRequestByPush(files: files)
                }
            } catch {
                // Errors surface via ConnectionManager logs when core handles them.
                _ = error
            }
            await refresh()
        }
    }

    func endScenario() {
        guard let controller else { return }
        Task {
            await controller.manager.clearScenario()
            await refresh()
        }
    }

    func sendQuickPush() {
        controller?.pushTransfer(files: pushFileList)
    }

    func generateTestFiles() {
        controller?.generateTestFiles(specs: testFileSpecs)
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await refresh()
        }
    }

    func deleteSelectedVideoFiles() {
        for name in selectedVideoFiles {
            let path = URL(fileURLWithPath: videoRootPath).appendingPathComponent(name).path
            try? FileManager.default.removeItem(atPath: path)
        }
        selectedVideoFiles.removeAll()
        reloadVideoFiles()
    }

    func clearLogs() {
        guard let controller else { return }
        Task {
            await controller.manager.clearLogs()
            await refresh()
        }
    }

    func exportLogs(to url: URL) {
        let lines = filteredLogs.reversed().map { entry in
            let time = Self.logFormatter.string(from: entry.timestamp)
            return "\(time)\t\(entry.source.rawValue)\t\(entry.level)\t\(entry.message)"
        }
        let body = lines.joined(separator: "\n")
        try? body.write(to: url, atomically: true, encoding: .utf8)
    }

    var pushFileList: [String] {
        pushFilesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static func formatBytes(_ bytes: Int64) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        }
        if bytes >= 1024 {
            return String(format: "%.0f KB", Double(bytes) / 1024)
        }
        return "\(bytes) B"
    }
}

enum LogSourceFilter: String, CaseIterable, Identifiable {
    case all
    case webSocket
    case webDAV
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .webSocket: "WS"
        case .webDAV: "DAV"
        case .system: "SYS"
        }
    }

    func includes(_ source: LogSource) -> Bool {
        switch self {
        case .all: true
        case .webSocket: source == .webSocket
        case .webDAV: source == .webDAV
        case .system: source == .system
        }
    }
}

enum LogLevelFilter: String, CaseIterable, Identifiable {
    case all
    case info
    case warn
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .info: "INFO"
        case .warn: "WARN"
        case .error: "ERROR"
        }
    }

    func includes(_ level: String) -> Bool {
        switch self {
        case .all: true
        case .info: level == "INFO" || level == "DEBUG"
        case .warn: level == "WARN"
        case .error: level == "ERROR"
        }
    }
}