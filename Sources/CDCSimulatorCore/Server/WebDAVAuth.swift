import FlyingFox
import Foundation

enum WebDAVAuth {
    static func expectedToken(ssid: String, password: String) -> String {
        AuthUtils.webDavToken(ssid: ssid, password: password)
    }

    static func validate(request: HTTPRequest, ssid: String, wifiPassword: String) -> Bool {
        guard let header = request.headers[.authorization] else { return false }
        guard header.hasPrefix("Basic ") else { return false }

        let encoded = String(header.dropFirst(6))
        guard let data = Data(base64Encoded: encoded),
              let decoded = String(data: data, encoding: .utf8) else {
            return false
        }

        let passwordPart: String
        if let separator = decoded.firstIndex(of: ":") {
            passwordPart = String(decoded[decoded.index(after: separator)...])
        } else {
            passwordPart = decoded
        }

        return passwordPart == expectedToken(ssid: ssid, password: wifiPassword)
    }

    static func unauthorizedResponse() -> HTTPResponse {
        var headers = HTTPHeaders()
        headers[HTTPHeader("WWW-Authenticate")] = "Basic realm=\"CDC WebDAV\""
        return HTTPResponse(statusCode: .unauthorized, headers: headers)
    }
}