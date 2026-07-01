import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    static func image(from string: String, scale: CGFloat = 8) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }

        let size = NSSize(width: scaled.extent.width, height: scaled.extent.height)
        return NSImage(cgImage: cgImage, size: size)
    }
}