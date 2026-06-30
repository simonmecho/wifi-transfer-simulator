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

        let data = try Data(contentsOf: fileURL)
        let contentType = fileURL.pathExtension.lowercased() == "mp4" ? "video/mp4" : "application/octet-stream"
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