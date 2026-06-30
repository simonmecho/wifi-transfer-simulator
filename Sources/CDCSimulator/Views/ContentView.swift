import CDCSimulatorCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: WebSocketServerController
    @StateObject private var uiState = SimulatorUIState()

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 240)
        } content: {
            contentArea
                .frame(minWidth: 520)
        } detail: {
            InspectorView(controller: controller, uiState: uiState)
                .navigationSplitViewColumnWidth(min: 260, ideal: 260, max: 300)
        }
        .frame(minWidth: 1024, minHeight: 680)
        .onAppear {
            uiState.bind(controller: controller)
        }
        .task {
            await uiState.loadDefaults()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            Task { await uiState.refresh() }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $uiState.selectedTab) {
                ForEach(SidebarTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbol)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 8) {
                Circle()
                    .fill(uiState.isAnyServiceRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(uiState.isAnyServiceRunning ? "Running" : "Stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        switch uiState.selectedTab {
        case .dashboard:
            DashboardView(controller: controller, uiState: uiState)
        case .scenarios:
            ScenarioView(controller: controller, uiState: uiState)
        case .files:
            FileManagerView(controller: controller, uiState: uiState)
        case .settings:
            SettingsView(uiState: uiState)
        case .logs:
            LogViewer(uiState: uiState)
        }
    }
}