import CDCSimulatorCore
import SwiftUI

struct ScenarioView: View {
    @ObservedObject var controller: WebSocketServerController
    @ObservedObject var uiState: SimulatorUIState

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Test Scenarios")
                    .font(.title2.bold())

                if !uiState.hasConnectedClient {
                    Text("Waiting for SDK WebSocket client")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(TestScenario.allCases) { scenario in
                        scenarioCard(scenario)
                    }
                }

                Divider()

                GroupBox("Custom Scenario") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Files:")
                            TextField("sample_front.mp4,sample_front.json", text: $uiState.customScenarioFiles)
                                .textFieldStyle(.roundedBorder)
                        }

                        Toggle("Reject transfer (CDC cancel)", isOn: $uiState.customRejectTransfer)
                        Toggle("Empty fileList", isOn: $uiState.customEmptyFileList)

                        HStack {
                            Spacer()
                            Button("Run Custom") {
                                uiState.runCustomScenario()
                            }
                            .disabled(!uiState.canRunScenario)
                            .keyboardShortcut(.return, modifiers: .command)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func scenarioCard(_ scenario: TestScenario) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(scenario.title)
                    .font(.headline)

                Text(scenario.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !scenario.pushFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(scenario.pushFiles, id: \.self) { file in
                            Text(file)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Run") {
                        uiState.runScenario(scenario)
                    }
                    .disabled(!uiState.canRunScenario)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        }
    }
}