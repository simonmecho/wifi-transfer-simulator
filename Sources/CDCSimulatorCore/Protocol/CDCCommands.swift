import Foundation

enum CDCCommand {
    static let basicAuthRequest = "basic auth request"
    static let basicAuthResponse = "basic auth response"
    static let vinAuthRequest = "vin auth request"
    static let vinAuthResponse = "vin auth response"
    static let statusNotify = "status notify"
    static let transferRequestByPush = "transfer request by push"
    static let transferRequest = "transfer request"
    static let transferResponse = "transfer response"
    static let moviePathRequest = "movie path request"
    static let moviePathResponse = "movie path response"
}

struct CDCMessage: Codable, Sendable {
    let cmd: String
    var id: String?
    var pass: String?
    var status: String?
    var detail: String?
    var vin: String?
    var list: [String]?
    var camera: String?
    var kind: String?
    var path: String?

    init(cmd: String) {
        self.cmd = cmd
    }

    enum CodingKeys: String, CodingKey {
        case cmd, id, pass, status, detail, vin, list, camera, kind, path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cmd = try container.decode(String.self, forKey: .cmd)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        pass = try container.decodeIfPresent(String.self, forKey: .pass)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        vin = try container.decodeIfPresent(String.self, forKey: .vin)
        list = try container.decodeIfPresent([String].self, forKey: .list)
        camera = try container.decodeIfPresent(String.self, forKey: .camera)
        kind = try container.decodeIfPresent(String.self, forKey: .kind)
        path = try container.decodeIfPresent(String.self, forKey: .path)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cmd, forKey: .cmd)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(pass, forKey: .pass)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(detail, forKey: .detail)
        try container.encodeIfPresent(vin, forKey: .vin)
        try container.encodeIfPresent(list, forKey: .list)
        try container.encodeIfPresent(camera, forKey: .camera)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encodeIfPresent(path, forKey: .path)
    }

    func encoded() throws -> String {
        let data = try JSONEncoder().encode(self)
        guard let text = String(data: data, encoding: .utf8) else {
            throw CDCProtocolError.encodingFailed
        }
        return text
    }

    static func decode(from text: String) throws -> CDCMessage {
        guard let data = text.data(using: .utf8) else {
            throw CDCProtocolError.invalidJSON
        }
        return try JSONDecoder().decode(CDCMessage.self, from: data)
    }

    static func transferRequestByPush(files: [String]?) throws -> String {
        let payload: [String: Any] = [
            "cmd": CDCCommand.transferRequestByPush,
            "list": files ?? NSNull(),
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        guard let text = String(data: data, encoding: .utf8) else {
            throw CDCProtocolError.encodingFailed
        }
        return text
    }
}

enum CDCProtocolError: Error {
    case invalidJSON
    case encodingFailed
    case unknownCommand(String)
}

enum CDCAuthValidator {
    static func validate(id: String?, pass: String?, expectedID: String, expectedPass: String) -> Bool {
        guard let id, let pass, !id.isEmpty, !pass.isEmpty else { return false }
        return id == expectedID && pass == expectedPass
    }
}
