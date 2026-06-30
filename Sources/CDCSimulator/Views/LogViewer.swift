import AppKit
import CDCSimulatorCore
import SwiftUI
import UniformTypeIdentifiers

struct LogViewer: View {
    @ObservedObject var uiState: SimulatorUIState
    @State private var expandedLogID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search…", text: $uiState.logSearchText)
                        .textFieldStyle(.plain)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
                .frame(maxWidth: 220)

                Picker("Source", selection: $uiState.logSourceFilter) {
                    ForEach(LogSourceFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                Picker("Level", selection: $uiState.logLevelFilter) {
                    ForEach(LogLevelFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)

                Spacer()

                Button("Clear") {
                    uiState.clearLogs()
                }

                Button("Export…") {
                    exportLogs()
                }
            }

            Table(uiState.filteredLogs.reversed()) {
                TableColumn("Time") { entry in
                    Text(entry.timestamp, style: .time)
                        .font(.caption.monospaced())
                }
                .width(72)

                TableColumn("Src") { entry in
                    Text(entry.source.rawValue)
                        .font(.caption2.bold())
                }
                .width(40)

                TableColumn("Level") { entry in
                    Text(entry.level)
                        .font(.caption.bold())
                }
                .width(52)

                TableColumn("Message") { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.message)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .lineLimit(expandedLogID == entry.id ? nil : 2)

                        if entry.message.count > 80 || entry.level == "ERROR" {
                            HStack(spacing: 8) {
                                Button(expandedLogID == entry.id ? "Collapse" : "Expand") {
                                    expandedLogID = expandedLogID == entry.id ? nil : entry.id
                                }
                                .buttonStyle(.link)
                                .font(.caption2)

                                Button("Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(entry.message, forType: .string)
                                }
                                .buttonStyle(.link)
                                .font(.caption2)

                                if entry.level == "ERROR" {
                                    Button("Jump to Settings →") {
                                        uiState.selectedTab = .settings
                                    }
                                    .buttonStyle(.link)
                                    .font(.caption2)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "simulator-logs.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        uiState.exportLogs(to: url)
    }
}