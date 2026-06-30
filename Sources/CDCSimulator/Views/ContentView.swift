import AppKit
import CDCSimulatorCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: WebSocketServerController
    @State private var pushFilesText = "sample_front.mp4,sample_front.json"
    @State private var authID = "cdc"
    @State private var authPass = "cdc123"
    @State private var wifiSSID = "DashCam_TEST"
    @State private var wifiPassword = "test1234"
    @State private var videoRootPath = SimulatorSettings.defaultVideoRoot()
    @State private var testFileSpecs: [TestFileSpec] = [
        TestFileSpec(filename: "sample_front.mp4", sizeKB: 1),
        TestFileSpec(filename: "sample_front.json", sizeKB: 1),
    ]
    @State private var selectedScenario: TestScenario = .normalTransfer
    @State private var logFilter: LogFilter = .all
    @State private var logs: [LogEntry] = []
    @State private var connectedCount = 0
    @State private var activeScenarioTitle: String?

    var body: some View {
        HSplitView {
            configPanel
                .frame(minWidth: 420, idealWidth: 460, maxWidth: 520)
            logPanel
                .frame(minWidth: 360)
        }
        .padding(20)
        .frame(minWidth: 980, minHeight: 700)
        .task { await loadFormDefaults() }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            Task { await refreshRuntimeState() }
        }
    }

    private var configPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                wifiSection
                videoSection
                testFilesSection
                scenarioSection
                authSection
                pushSection
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CDC Wi-Fi Simulator")
                .font(.title2.bold())
            Text("WS :8490 · WebDAV :49150 · mDNS _drec._tcp")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                statusDot(controller.isRunning, label: "WebSocket")
                statusDot(controller.isWebDAVRunning, label: "WebDAV")
                statusDot(controller.isMDNSRunning, label: "mDNS")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Connected SDKs: \(connectedCount)")
                        .font(.caption.bold())
                    if let activeScenarioTitle {
                        Text("Scenario: \(activeScenarioTitle)")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private func statusDot(_ on: Bool, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(on ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(label).font(.caption)
        }
    }

    private var wifiSection: some View {
        GroupBox("Wi-Fi / WebDAV Auth (md5(SSID+password)[:8])") {
            HStack {
                TextField("SSID", text: $wifiSSID)
                    .textFieldStyle(.roundedBorder)
                SecureField("Wi-Fi password", text: $wifiPassword)
                    .textFieldStyle(.roundedBorder)
                Button("Apply") {
                    Task {
                        await controller.manager.updateWiFi(ssid: wifiSSID, password: wifiPassword)
                        await refreshRuntimeState()
                    }
                }
            }
        }
    }

    private var videoSection: some View {
        GroupBox("Test Video Root") {
            HStack {
                TextField("Directory path", text: $videoRootPath)
                    .textFieldStyle(.roundedBorder)
                Button("Browse…") { chooseVideoRoot() }
                Button("Apply") {
                    Task {
                        await controller.manager.updateVideoRoot(path: videoRootPath)
                        await refreshRuntimeState()
                    }
                }
            }
        }
    }

    private var testFilesSection: some View {
        GroupBox("Test Files") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Filename").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Size (KB)").frame(width: 72, alignment: .trailing)
                    Text("").frame(width: 24)
                }
                .font(.caption.bold())
                .foregroundStyle(.secondary)

                ForEach($testFileSpecs) { $spec in
                    HStack(spacing: 8) {
                        TextField("filename.mp4", text: $spec.filename)
                            .textFieldStyle(.roundedBorder)
                        TextField("KB", value: $spec.sizeKB, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 72)
                        Button {
                            testFileSpecs.removeAll { $0.id == spec.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button("Add File") {
                        testFileSpecs.append(TestFileSpec(filename: "test.mp4", sizeKB: 64))
                    }
                    Button("Generate Files") {
                        controller.generateTestFiles(specs: testFileSpecs)
                    }
                    .disabled(testFileSpecs.isEmpty)
                }
            }
        }
    }

    private var scenarioSection: some View {
        GroupBox("Test Scenarios") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Scenario", selection: $selectedScenario) {
                    ForEach(TestScenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                .pickerStyle(.menu)

                Text(selectedScenario.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Run Scenario + Push") {
                    controller.runScenario(selectedScenario)
                }
                .disabled(connectedCount == 0)
                .help(connectedCount == 0 ? "Connect an SDK client first" : "Generate fixtures if needed, arm scenario, then push")
            }
        }
    }

    private var authSection: some View {
        GroupBox("WebSocket Basic Auth (expected credentials)") {
            HStack {
                TextField("id", text: $authID)
                    .textFieldStyle(.roundedBorder)
                SecureField("pass", text: $authPass)
                    .textFieldStyle(.roundedBorder)
                Button("Apply") {
                    Task {
                        await controller.manager.updateAuth(id: authID, pass: authPass)
                        await refreshRuntimeState()
                    }
                }
            }
        }
    }

    private var pushSection: some View {
        GroupBox("Transfer Request by Push") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("file list (comma-separated)", text: $pushFilesText)
                        .textFieldStyle(.roundedBorder)
                    Button("Send Push") {
                        controller.pushTransfer(files: filesForPush)
                    }
                    .disabled(connectedCount == 0 || filesForPush.isEmpty)
                }
                Text(connectedCount == 0
                    ? "Waiting for SDK WebSocket client…"
                    : "CLI: cdc-server --push sample_front.mp4,sample_front.json")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var logPanel: some View {
        GroupBox("Live Logs") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("Filter", selection: $logFilter) {
                        ForEach(LogFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 280)
                    Spacer()
                    Button("Clear") {
                        Task {
                            await controller.manager.clearLogs()
                            await refreshRuntimeState()
                        }
                    }
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(filteredLogs) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.timestamp, style: .time)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(entry.source.rawValue)
                                    .font(.caption2.bold())
                                    .foregroundStyle(sourceColor(entry.source))
                                    .frame(width: 34, alignment: .leading)
                                Text(entry.level)
                                    .font(.caption.bold())
                                    .foregroundStyle(color(for: entry.level))
                                    .frame(width: 48, alignment: .leading)
                                Text(entry.message)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var filesForPush: [String] {
        pushFilesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var filteredLogs: [LogEntry] {
        logs.filter { logFilter.includes($0.source) }
    }

    private func chooseVideoRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            videoRootPath = url.path
        }
    }

    private func color(for level: String) -> Color {
        switch level {
        case "ERROR": .red
        case "WARN": .orange
        case "DEBUG": .blue
        default: .primary
        }
    }

    private func sourceColor(_ source: LogSource) -> Color {
        switch source {
        case .webSocket: .blue
        case .webDAV: .purple
        case .system: .secondary
        }
    }

    private func loadFormDefaults() async {
        let settings = await controller.manager.settings
        wifiSSID = settings.wifiSSID
        wifiPassword = settings.wifiPassword
        videoRootPath = settings.videoRootPath
        authID = settings.webSocketAuthID
        authPass = settings.webSocketAuthPass
        await refreshRuntimeState()
    }

    private func refreshRuntimeState() async {
        logs = await controller.manager.logs
        connectedCount = await controller.manager.connectedClientCount
        if let scenario = await controller.manager.activeScenario {
            activeScenarioTitle = scenario.title
        } else {
            activeScenarioTitle = nil
        }
    }
}

private enum LogFilter: String, CaseIterable, Identifiable {
    case all
    case webSocket
    case webDAV

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .webSocket: "WebSocket"
        case .webDAV: "WebDAV"
        }
    }

    func includes(_ source: LogSource) -> Bool {
        switch self {
        case .all: true
        case .webSocket: source == .webSocket
        case .webDAV: source == .webDAV
        }
    }
}