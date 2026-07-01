import Foundation

public enum WiFiPairingURI {
    public static func build(ssid: String, password: String, securityType: String) -> String {
        let type = securityType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedType = type.isEmpty ? "WPA2" : type
        return "WIFI:S:\(escape(ssid));P:\(escape(password));T:\(normalizedType);;"
    }

    private static func escape(_ value: String) -> String {
        var result = ""
        result.reserveCapacity(value.count)
        for character in value {
            switch character {
            case "\\":
                result += "\\\\"
            case ";":
                result += "\\;"
            case ":":
                result += "\\:"
            case "\"":
                result += "\\\""
            default:
                result.append(character)
            }
        }
        return result
    }
}