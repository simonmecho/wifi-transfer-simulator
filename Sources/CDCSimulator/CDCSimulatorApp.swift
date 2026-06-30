import AppKit
import CDCSimulatorCore
import SwiftUI

@main
struct CDCSimulatorApp: App {
    @StateObject private var controller = WebSocketServerController()

    init() {
        // SPM 产出的是裸 Mach-O 可执行文件，不是 .app bundle，需显式声明为前台 GUI 应用。
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(controller: controller)
                .frame(minWidth: 1024, minHeight: 680)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    schedulePushIfNeeded(controller: controller)
                }
        }
        .defaultSize(width: 1200, height: 760)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Send Test Push") {
                    controller.pushTransfer(files: ["sample_front.mp4", "sample_front.json"])
                }
                .keyboardShortcut("P", modifiers: [.command, .shift])
            }
        }
    }

    private func schedulePushIfNeeded(controller: WebSocketServerController) {
        let args = CommandLine.arguments
        guard let pushIndex = args.firstIndex(of: "--push"), pushIndex + 1 < args.count else {
            return
        }
        let files = args[pushIndex + 1]
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !files.isEmpty else { return }

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            controller.pushTransfer(files: files)
        }
    }
}