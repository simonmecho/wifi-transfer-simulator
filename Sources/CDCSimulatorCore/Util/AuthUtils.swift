import CryptoKit
import Foundation

public enum AuthUtils {
    /// Matches iOS `AuthUtils.webDavToken` and production `DefaultAuthCredentialProvider`.
    public static func webDavToken(ssid: String, password: String) -> String {
        let digest = Insecure.MD5.hash(data: Data((ssid + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(8).description
    }
}