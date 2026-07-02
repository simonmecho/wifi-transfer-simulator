#!/usr/bin/env swift
import CryptoKit
import Foundation

@available(macOS 10.15, *)
func run() async throws {
    let ssid = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "ChinaNet-SXGE-5G"
    let password = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Sm_20090524"
    let file = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "sample_front.mp4"

    let digest = Insecure.MD5.hash(data: Data((ssid + password).utf8))
    let token = digest.map { String(format: "%02x", $0) }.joined().prefix(8)
    let authString = "user:\(token)"
    let authData = Data(authString.utf8).base64EncodedString()

    var request = URLRequest(url: URL(string: "http://127.0.0.1:49150/\(file)")!)
    request.httpMethod = "GET"
    request.setValue("Basic \(authData)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "WebDAV GET failed"])
    }
    print("WEBDAV: \(file) \(data.count) bytes")
    print("PASS")
}

if #available(macOS 10.15, *) {
    let sema = DispatchSemaphore(value: 0)
    Task {
        do { try await run() } catch {
            print("FAIL:", error)
            exit(1)
        }
        sema.signal()
    }
    sema.wait()
}
