import AppKit
import CDCSimulatorCore
import SwiftUI
import UniformTypeIdentifiers

struct FileManagerView: View {
    @ObservedObject var controller: WebSocketServerController
    @ObservedObject var uiState: SimulatorUIState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Test Files")
                    .font(.title2.bold())
                Spacer()
                videoRootPicker
            }

            Table(uiState.videoFiles, selection: $uiState.selectedVideoFiles) {
                TableColumn("Filename") { row in
                    Text(row.name)
                        .font(.body.monospaced())
                }
                TableColumn("Size") { row in
                    Text(row.sizeLabel)
                        .font(.body.monospaced())
                }
            }
            .frame(minHeight: 240)

            HStack(spacing: 12) {
                Button("Add File") {
                    addFilesFromPanel()
                }
                Button("Generate from specs") {
                    uiState.generateTestFiles()
                }
                Button("Delete Selected") {
                    uiState.deleteSelectedVideoFiles()
                }
                .disabled(uiState.selectedVideoFiles.isEmpty)
            }

            GroupBox("Generate Specs") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach($uiState.testFileSpecs) { $spec in
                        HStack {
                            TextField("filename", text: $spec.filename)
                                .textFieldStyle(.roundedBorder)
                            TextField("KB", value: $spec.sizeKB, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Button(role: .destructive) {
                                uiState.testFileSpecs.removeAll { $0.id == spec.id }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button("Add Spec") {
                        uiState.testFileSpecs.append(TestFileSpec(filename: "new_file.mp4", sizeKB: 64))
                    }
                }
            }

            Text("Drag & drop files here to add")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .foregroundStyle(.quaternary)
                )
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers)
                }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var videoRootPicker: some View {
        HStack(spacing: 8) {
            Text("Video Root")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("Path", text: $uiState.videoRootPath)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 280)
            Button("Browse…") {
                browseVideoRoot()
            }
            Button("Apply") {
                uiState.applyVideoRoot()
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

    private func addFilesFromPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: uiState.videoRootPath, isDirectory: true)
        guard panel.runModal() == .OK else { return }
        copyFiles(panel.urls)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                let url = await withCheckedContinuation { continuation in
                    _ = provider.loadObject(ofClass: URL.self) { object, _ in
                        continuation.resume(returning: object)
                    }
                }
                if let url {
                    urls.append(url)
                }
            }
            copyFiles(urls)
        }
        return true
    }

    private func copyFiles(_ urls: [URL]) {
        let destinationRoot = URL(fileURLWithPath: uiState.videoRootPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: destinationRoot, withIntermediateDirectories: true)

        for source in urls {
            let destination = destinationRoot.appendingPathComponent(source.lastPathComponent)
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: source, to: destination)
        }
        uiState.reloadVideoFiles()
    }
}