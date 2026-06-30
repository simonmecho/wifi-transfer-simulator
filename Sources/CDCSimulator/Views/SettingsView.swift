import AppKit
import CDCSimulatorCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var uiState: SimulatorUIState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("设置")
                    .font(.title2.bold())

                GroupBox("Wi-Fi & WebDAV Auth") {
                    VStack(alignment: .leading, spacing: 12) {
                        labeledField("SSID", text: $uiState.wifiSSID)
                        labeledField("Password", text: $uiState.wifiPassword, isSecure: true)

                        Divider()

                        Text("WebDAV Key: md5(SSID+pass)[:8]")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(uiState.webDavTokenPreview)
                            .font(.title3.monospaced())
                        Text("auto-generated on Apply")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: uiState.wifiSSID) { _ in uiState.applyWiFiSettings() }
                    .onChange(of: uiState.wifiPassword) { _ in uiState.applyWiFiSettings() }
                }

                GroupBox("WebSocket Auth") {
                    VStack(alignment: .leading, spacing: 12) {
                        labeledField("Auth ID", text: $uiState.authID)
                        labeledField("Auth Pass", text: $uiState.authPass, isSecure: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: uiState.authID) { _ in uiState.applyAuthSettings() }
                    .onChange(of: uiState.authPass) { _ in uiState.applyAuthSettings() }
                }

                GroupBox("Paths") {
                    HStack {
                        Text("Video Root:")
                            .frame(width: 90, alignment: .leading)
                        TextField("Path", text: $uiState.videoRootPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse") {
                            browseVideoRoot()
                        }
                    }
                    .onChange(of: uiState.videoRootPath) { _ in uiState.applyVideoRoot() }
                }

                GroupBox("Advanced: Port Configuration") {
                    HStack(spacing: 24) {
                        HStack {
                            Text("WebSocket:")
                            Text("\(WebSocketServerController.webSocketPort)")
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("WebDAV:")
                            Text("\(WebSocketServerController.webDAVPort)")
                                .font(.body.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Text("所有修改即时生效 (Auto-Apply)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func labeledField(_ title: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        HStack {
            Text("\(title):")
                .frame(width: 90, alignment: .leading)
            if isSecure {
                SecureField(title, text: text)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField(title, text: text)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func browseVideoRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: uiState.videoRootPath, isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        uiState.videoRootPath = url.path
        uiState.applyVideoRoot()
    }
}