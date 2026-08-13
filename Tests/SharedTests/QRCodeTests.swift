import CoreImage
import Foundation
import Testing
@testable import SalaryShared

// A QR code that cannot be read back is a picture of a QR code. CoreImage will detect one,
// so the round trip is testable without a camera — which is the only way any of this gets
// checked, since the machine it is drawn on has no way to scan its own screen.

private func readBack(_ image: CGImage) -> String? {
    let detector = CIDetector(
        ofType: CIDetectorTypeQRCode,
        context: nil,
        options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
    )
    let features = detector?.features(in: CIImage(cgImage: image)) ?? []
    return (features.first as? CIQRCodeFeature)?.messageString
}

@Test func aCodeCanBeReadBackAsTheStringItWasDrawnFrom() throws {
    let link = "salaryticker://config?v=1&d=eyJtb250aGx5U2FsYXJ5Ijo0NTAwfQ"
    let image = try #require(QRCode.image(for: link))
    #expect(readBack(image) == link)
}

@Test func aRealisticPayloadStillScans() throws {
    // Close to what a filled-in configuration actually weighs. The interesting failure is
    // a payload that pushes the code past what the chosen recovery level can carry.
    let payload = String(repeating: "aB3-_", count: 170)          // 850 characters
    let link = "salaryticker://config?v=1&d=\(payload)"
    let image = try #require(QRCode.image(for: link))
    #expect(readBack(image) == link)
}

@Test func theCodeIsBigEnoughToPointACameraAt() throws {
    // Magnified from the module grid; unscaled it comes out around 30 pixels square, which
    // is a picture of a QR code rather than a scannable one.
    let image = try #require(QRCode.image(for: "salaryticker://config?v=1&d=abcdefgh"))
    #expect(image.width > 200)
    #expect(image.width == image.height)
}

@Test func anEmptyStringDoesNotProduceSomethingThatLooksScannable() {
    // Not a crash, and not a code that reads back as nothing useful either.
    let image = QRCode.image(for: "")
    #expect(image == nil || readBack(image!) == nil || readBack(image!) == "")
}
