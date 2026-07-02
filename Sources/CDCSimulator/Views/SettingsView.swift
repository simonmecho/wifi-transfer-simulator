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
                        securityTypePicker

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
                    .onChange(of: uiState.securityType) { _ in uiState.applyWiFiSettings() }
                }

                GroupBox("Wi-Fi QR Code") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan with DemoApp to pair")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(uiState.wifiPairingURI)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        wifiQRCodeImage
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("WebSocket Auth") {
                    VStack(alignment: .leading, spacing: 12) {
                        labeledField("Auth ID", text: $uiState.authID)

                        Text("Auth Pass: md5(SSID+pass)[:8]")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(uiState.authPass)
                            .font(.title3.monospaced())
                        Text("derived from Wi-Fi settings (matches production SDK)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: uiState.authID) { _ in uiState.applyAuthSettings() }
                    .onChange(of: uiState.wifiSSID) { _ in uiState.applyAuthSettings() }
                    .onChange(of: uiState.wifiPassword) { _ in uiState.applyAuthSettings() }
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

    private var securityTypePicker: some View {
        HStack {
            Text("Security:")
                .frame(width: 90, alignment: .leading)
            Picker("Security", selection: $uiState.securityType) {
                Text("WPA2").tag("WPA2")
                Text("WPA3").tag("WPA3")
                Text("OPEN").tag("OPEN")
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var wifiQRCodeImage: some View {
        if let image = QRCodeGenerator.image(from: uiState.wifiPairingURI) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .frame(width: 160, height: 160)
                .padding(8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Text("Unable to generate QR code")
                .font(.caption)
                .foregroundStyle(.secondary)
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