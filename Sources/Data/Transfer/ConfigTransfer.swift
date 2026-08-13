import Foundation
import SalaryDomain

/// Moves a whole configuration between two machines through a link.
///
/// The Mac draws the link as a QR code; the phone opens it. Both are the same operation,
/// which is deliberate — a camera cannot be exercised in a simulator and a URL can, so the
/// path that actually decodes the settings is testable end to end whatever delivers it.
///
/// The payload is the same JSON the settings are stored in, so the format has one owner and
/// the tolerant decoding already written for upgrades covers arriving links too.
public enum ConfigTransfer {

    public static let scheme = "salaryticker"
    static let host = "config"

    /// Bumped only if the payload stops being readable by the current decoder. A version
    /// this build does not know is refused rather than guessed at: a half-applied
    /// configuration would leave the user reading a number built out of two machines.
    static let version = 1

    public static func url(for config: SalaryConfig) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "v", value: String(version)),
            URLQueryItem(name: "d", value: encode(config)),
        ]
        // The pieces are all built here, so the only way this fails is a programming error.
        return components.url ?? URL(string: "\(scheme)://\(host)")!
    }

    public static func config(from url: URL) -> SalaryConfig? {
        guard url.scheme == scheme, url.host == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              let version = items.first(where: { $0.name == "v" })?.value,
              Int(version) == Self.version,
              let payload = items.first(where: { $0.name == "d" })?.value,
              let data = decode(payload)
        else { return nil }

        return try? JSONDecoder().decode(SalaryConfigDTO.self, from: data).toDomain()
    }

    // MARK: - Base64, in the spelling a query string will carry

    /// Standard base64 uses `+` and `/`, which mean other things in a URL, and pads with
    /// `=`. The URL-safe alphabet avoids the escaping entirely, which keeps the QR code
    /// smaller and stops a link surviving one round of encoding but not two.
    private static func encode(_ config: SalaryConfig) -> String {
        guard let json = try? JSONEncoder().encode(SalaryConfigDTO(config)) else { return "" }
        // Deflated first, which halves it. That is not housekeeping: the payload becomes a
        // QR code, and every character is more modules crammed into the same square. A
        // realistic configuration goes from about 1,200 characters to about 640, which is
        // several QR versions coarser and the difference between scanning at arm's length
        // and hunting for the angle that works.
        let data = (try? (json as NSData).compressed(using: .zlib) as Data) ?? json
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func decode(_ payload: String) -> Data? {
        var text = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // The padding was dropped on the way out; base64 decoding wants it back.
        let remainder = text.count % 4
        if remainder > 0 { text += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: text) else { return nil }

        // Deflated on the way out, but a link that predates that is still readable: if the
        // bytes are not a zlib stream they are the JSON itself.
        return (try? (data as NSData).decompressed(using: .zlib) as Data) ?? data
    }
}

/// Instance form, for anything holding the port rather than calling the type directly.
public struct ConfigLinkCoder: ConfigLinkCoding {
    public init() {}
    public func url(for config: SalaryConfig) -> URL { ConfigTransfer.url(for: config) }
    public func config(from url: URL) -> SalaryConfig? { ConfigTransfer.config(from: url) }
}
