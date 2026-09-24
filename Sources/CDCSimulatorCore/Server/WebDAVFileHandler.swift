import FlyingFox
import Foundation

struct WebDAVFileHandler: HTTPHandler {
    let manager: ConnectionManager

    func handleRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        let settings = await manager.settings
        guard WebDAVAuth.validate(request: request, ssid: settings.wifiSSID, wifiPassword: settings.wifiPassword) else {
            await manager.appendLog(source: .webDAV, level: "WARN", message: "WebDAV auth failed for \(request.path)")
            return WebDAVAuth.unauthorizedResponse()
        }

        guard request.method == .GET else {
            await manager.appendLog(source: .webDAV, level: "WARN", message: "WebDAV method not allowed: \(request.method)")
            return HTTPResponse(statusCode: .methodNotAllowed)
        }

        let scenario = await manager.activeScenario
        if scenario?.disconnectWebSocketOnWebDAVGET == true {
            await manager.disconnectAllClients(reason: "UserCancel notify failure scenario after WebDAV GET started")
        }
        if scenario?.failsWebDAVGET == true {
            await manager.appendLog(source: .webDAV, level: "ERROR", message: "WebDAV GET forced to fail")
            return HTTPResponse(statusCode: .serviceUnavailable)
        }
        if let delay = scenario?.webDAVResponseDelay, delay > 0 {
            await manager.appendLog(source: .webDAV, level: "INFO", message: "WebDAV GET delayed by \(Int(delay)) seconds")
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        let relativePath = sanitizePath(request.path)
        guard !relativePath.isEmpty else {
            return HTTPResponse(statusCode: .notFound)
        }

        let fileURL = URL(fileURLWithPath: settings.videoRootPath, isDirectory: true)
            .appendingPathComponent(relativePath)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            await manager.appendLog(source: .webDAV, level: "WARN", message: "WebDAV missing file: \(relativePath)")
            return HTTPResponse(statusCode: .notFound)
        }

        let contentType = fileURL.pathExtension.lowercased() == "mp4" ? "video/mp4" : "application/octet-stream"

        let data = try Data(contentsOf: fileURL)
        await manager.appendLog(source: .webDAV, level: "INFO", message: "WebDAV GET \(relativePath) (\(data.count) bytes)")

        var headers = HTTPHeaders()
        headers[.contentType] = contentType
        headers[.contentLength] = "\(data.count)"
        return HTTPResponse(statusCode: .ok, headers: headers, body: data)
    }

    private func sanitizePath(_ rawPath: String) -> String {
        let trimmed = rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let components = trimmed.split(separator: "/").map(String.init)
        guard !components.contains("..") else { return "" }
        return components.joined(separator: "/")
    }
}
