import Foundation

// watchOS has no CoreImage, and no reason to want it: a watch neither draws this code nor
// scans one. Fenced rather than dropped, so the Mac and the phone keep it.
#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins

/// Draws a string as a QR code.
///
/// Lives in Shared and returns a `CGImage` rather than an `NSImage` or a `UIImage`, so the
/// Mac and the phone can each wrap it in whatever their own view layer wants without a
/// second implementation.
public enum QRCode {

    /// - Parameter scale: the QR module grid comes out tiny — roughly one pixel per module —
    ///   so it is magnified before anything tries to draw it. Nearest-neighbour, because
    ///   smoothing the squares is what makes a code hard to read.
    public static func image(for text: String, scale: CGFloat = 10) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        // Medium recovery: the payload is close to a kilobyte, and the higher levels grow
        // the grid enough to make the modules small on a screen at arm's length.
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let enlarged = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return CIContext().createCGImage(enlarged, from: enlarged.extent)
    }
}

#endif
