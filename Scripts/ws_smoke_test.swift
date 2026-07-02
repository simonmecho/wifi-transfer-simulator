#!/usr/bin/env swift
import CryptoKit
import Foundation

@available(macOS 10.15, *)
func run() async throws {
    let ssid = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ChinaNet-SXGE-5G"
    let password = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Sm_20090524"
    let digest = Insecure.MD5.hash(data: Data((ssid + password).utf8))
    let pass = digest.map { String(format: "%02x", $0) }.joined().prefix(8)

    let url = URL(string: "ws://127.0.0.1:8490/")!
    let task = URLSession.shared.webSocketTask(with: url)
    task.resume()

    let auth = #"{"cmd":"basic auth request","id":"cdc","pass":"\#(pass)"}"#
    try await task.send(.string(auth))
    let authReply = try await task.receive()
    switch authReply {
    case .string(let text):
        print("AUTH:", text)
        guard text.contains("\"status\":\"ok\"") else { throw NSError(domain: "test", code: 1) }
    default:
        throw NSError(domain: "test", code: 2)
    }

    let status = #"{"cmd":"status notify","status":"idle","detail":""}"#
    try await task.send(.string(status))
    print("STATUS: sent")
    task.cancel(with: .goingAway, reason: nil)
}

if #available(macOS 10.15, *) {
    let sema = DispatchSemaphore(value: 0)
    Task {
        do {
            try await run()
            print("PASS")
        } catch {
            print("FAIL:", error)
            exit(1)
        }
        sema.signal()
    }
    sema.wait()
} else {
    fputs("macOS 10.15+ required\n", stderr)
    exit(1)
}