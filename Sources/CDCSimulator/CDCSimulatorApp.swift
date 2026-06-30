import CDCSimulatorCore
import SwiftUI

@main
struct CDCSimulatorApp: App {
    @StateObject private var controller = WebSocketServerController()

    var body: some Scene {
        WindowGroup {
            ContentView(controller: controller)
                .onAppear { schedulePushIfNeeded(controller: controller) }
        }
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