import CryptoKit
import Foundation

public enum AuthUtils {
    public static func basicAuthID(ssid: String) -> String {
        md5Prefix8(ssid)
    }

    public static func basicAuthPass(password: String) -> String {
        md5Prefix8(password)
    }

    public static func webDavToken(ssid: String, password: String) -> String {
        md5Prefix8(ssid + password)
    }

    private static func md5Prefix8(_ value: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(8).description
    }
}
