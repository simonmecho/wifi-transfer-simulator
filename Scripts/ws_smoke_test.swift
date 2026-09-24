#!/usr/bin/env swift
import CryptoKit
import Foundation

@available(macOS 10.15, *)
func run() async throws {
    let ssid = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ChinaNet-SXGE-5G"
    let password = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Sm_20090524"
    let idDigest = Insecure.MD5.hash(data: Data(ssid.utf8))
    let id = idDigest.map { String(format: "%02x", $0) }.joined().prefix(8)
    let passDigest = Insecure.MD5.hash(data: Data(password.utf8))
    let pass = passDigest.map { String(format: "%02x", $0) }.joined().prefix(8)

    let url = URL(string: "ws://127.0.0.1:8490/")!
    let task = URLSession.shared.webSocketTask(with: url)
    task.resume()

    let auth = #"{"cmd":"basic auth request","id":"\#(id)","pass":"\#(pass)"}"#
    try await task.send(.string(auth))
    let authReply = try await task.receive()
    switch authReply {
    case .string(let text):
        print("AUTH:", text)
        guard text.contains("\"status\":\"success\"") else { throw NSError(domain: "test", code: 1) }
    default:
        throw NSError(domain: "test", code: 2)
    }

    let vinRequest = try await task.receive()
    let vin: String
    switch vinRequest {
    case .string(let text):
        print("VIN:", text)
        let data = Data(text.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard object?["cmd"] as? String == "vin auth request",
              let value = object?["vin"] as? String else {
            throw NSError(domain: "test", code: 3)
        }
        vin = value
    default:
        throw NSError(domain: "test", code: 4)
    }

    let vinDigest = Insecure.MD5.hash(data: Data(vin.utf8))
        .map { String(format: "%02x", $0) }
        .joined()
        .prefix(8)
    let vinResponse = #"{"cmd":"vin auth response","status":"success","detail":"\#(vinDigest)"}"#
    try await task.send(.string(vinResponse))

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
