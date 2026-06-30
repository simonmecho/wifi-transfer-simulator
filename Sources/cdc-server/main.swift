import CDCSimulatorCore
import Foundation

let controller = WebSocketServerController()
let args = CommandLine.arguments

if let pushIndex = args.firstIndex(of: "--push"), pushIndex + 1 < args.count {
    let files = args[pushIndex + 1]
        .split(separator: ",")
        .map { String($0).trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
    if !files.isEmpty {
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            controller.pushTransfer(files: files)
        }
    }
}

fputs("cdc-server listening on :8490\n", stderr)
dispatchMain()