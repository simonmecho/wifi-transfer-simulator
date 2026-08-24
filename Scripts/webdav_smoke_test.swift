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

    let url = URL(string: "http://127.0.0.1:49150/\(file)")!
    let authorization = "Basic \(authData)"

    var headRequest = URLRequest(url: url)
    headRequest.httpMethod = "HEAD"
    headRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
    let (_, headResponse) = try await URLSession.shared.data(for: headRequest)
    guard let headHTTP = headResponse as? HTTPURLResponse,
          headHTTP.statusCode == 200,
          headHTTP.expectedContentLength >= 0 else {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "WebDAV HEAD failed"])
    }

    var getRequest = URLRequest(url: url)
    getRequest.httpMethod = "GET"
    getRequest.setValue(authorization, forHTTPHeaderField: "Authorization")
    let (data, getResponse) = try await URLSession.shared.data(for: getRequest)
    guard let getHTTP = getResponse as? HTTPURLResponse,
          getHTTP.statusCode == 200,
          Int64(data.count) == headHTTP.expectedContentLength else {
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
