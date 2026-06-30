import CDCSimulatorCore
import SwiftUI

struct InspectorView: View {
    @ObservedObject var controller: WebSocketServerController
    @ObservedObject var uiState: SimulatorUIState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Server") {
                    VStack(spacing: 10) {
                        HStack {
                            Circle()
                                .fill(uiState.isAnyServiceRunning ? Color.green : Color.red)
                                .frame(width: 10, height: 10)
                            Text(uiState.isAnyServiceRunning ? "Running" : "Stopped")
                                .font(.headline)
                            Spacer()
                        }

                        HStack(spacing: 8) {
                            Button("Start") {
                                uiState.startServices()
                            }
                            .disabled(uiState.isAnyServiceRunning)

                            Button("Stop") {
                                uiState.stopServices()
                            }
                            .disabled(!uiState.isAnyServiceRunning)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Connected Clients (\(uiState.connectedCount))") {
                    if uiState.connectedCount == 0 {
                        Text("Waiting for SDK WebSocket client")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(0..<uiState.connectedCount, id: \.self) { index in
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                Text("SDK #\(index + 1)")
                                    .font(.caption.monospaced())
                                Spacer()
                            }
                        }
                    }
                }

                GroupBox("Quick Push") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("file1.mp4,file2.json", text: $uiState.pushFilesText)
                            .textFieldStyle(.roundedBorder)

                        if !uiState.hasConnectedClient {
                            Text("Waiting for SDK WebSocket client")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if uiState.pushFileList.isEmpty {
                            Text("Enter at least one filename")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button("Send") {
                            uiState.sendQuickPush()
                        }
                        .disabled(!uiState.canQuickPush)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Active Scenario") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let title = uiState.activeScenarioTitle {
                            Text(title)
                                .font(.headline)
                            Button("End Scenario") {
                                uiState.endScenario()
                            }
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }
}