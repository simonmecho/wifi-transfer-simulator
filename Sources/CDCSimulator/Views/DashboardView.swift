import CDCSimulatorCore
import SwiftUI

struct DashboardView: View {
    @ObservedObject var controller: WebSocketServerController
    @ObservedObject var uiState: SimulatorUIState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("仪表盘")
                    .font(.title2.bold())

                HStack(spacing: 16) {
                    serviceCard(
                        title: "WebSocket",
                        port: ":\(WebSocketServerController.webSocketPort)",
                        subtitle: "Active",
                        isOn: controller.isRunning
                    )
                    serviceCard(
                        title: "WebDAV",
                        port: ":\(WebSocketServerController.webDAVPort)",
                        subtitle: "Active",
                        isOn: controller.isWebDAVRunning
                    )
                    serviceCard(
                        title: "mDNS",
                        port: "_drec._tcp",
                        subtitle: "Advertise",
                        isOn: controller.isMDNSRunning
                    )
                }

                HStack(spacing: 32) {
                    metric(title: "已连接 SDK", value: "\(uiState.connectedCount)")
                    metric(title: "活跃场景", value: uiState.activeScenarioTitle ?? "—")
                    metric(title: "运行时长", value: uiState.uptimeLabel)
                }

                GroupBox("最近日志") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(uiState.logs.prefix(6)) { entry in
                            logLine(entry)
                        }
                        if uiState.logs.isEmpty {
                            Text("暂无日志")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("查看全部日志 →") {
                            uiState.selectedTab = .logs
                        }
                        .buttonStyle(.link)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func serviceCard(title: String, port: String, subtitle: String, isOn: Bool) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Circle()
                        .fill(isOn ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                }
                Text(port)
                    .font(.title3.monospaced())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(isOn ? "Stop" : "Start") {
                    if isOn {
                        uiState.stopServices()
                    } else {
                        uiState.startServices()
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
    }

    private func logLine(_ entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.timestamp, style: .time)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(entry.source.rawValue)
                .font(.caption2.bold())
                .frame(width: 34, alignment: .leading)
            Text(entry.level)
                .font(.caption.bold())
                .frame(width: 44, alignment: .leading)
            Text(entry.message)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}