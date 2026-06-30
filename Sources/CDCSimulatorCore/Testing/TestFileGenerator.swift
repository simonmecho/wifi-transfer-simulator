import Foundation

public enum TestFileGenerator {
    public static func generate(specs: [TestFileSpec], in rootPath: String) throws -> [String] {
        let rootURL = URL(fileURLWithPath: rootPath, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        var written: [String] = []
        for spec in specs {
            let name = sanitizedFilename(spec.filename)
            guard !name.isEmpty else { continue }
            let url = rootURL.appendingPathComponent(name)
            let data = payload(sizeKB: max(spec.sizeKB, 1), filename: name)
            try data.write(to: url, options: .atomic)
            written.append(name)
        }
        return written
    }

    private static func sanitizedFilename(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = (trimmed as NSString).lastPathComponent
        guard !base.isEmpty, !base.contains(".."), !base.contains("/") else { return "" }
        return base
    }

    private static func payload(sizeKB: Int, filename: String) -> Data {
        let ext = (filename as NSString).pathExtension.lowercased()
        if ext == "json" {
            let json = #"{"camera":"front","generated":true}"#
            return Data(json.utf8)
        }

        let targetBytes = sizeKB * 1024
        var data = Data()
        // Minimal ISO BMFF header so players recognize mp4-like fixtures.
        let header = Data([
            0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70,
            0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00,
            0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32,
            0x6D, 0x70, 0x34, 0x31,
        ])
        data.append(header)
        if data.count < targetBytes {
            data.append(Data(repeating: 0x00, count: targetBytes - data.count))
        }
        return Data(data.prefix(targetBytes))
    }
}