import Foundation
import StoreKit

// SPIKE (FOV-1721) — not released. Requests an Apple external-purchase token
// so it can be handed to an external checkout (iaptic-js / Stripe).

/// Decoded content of an Apple external-purchase token (Base64URL-encoded JSON).
public struct ExternalPurchaseTokenInfo: Decodable, Equatable {
    public let appAppleId: Int64
    public let bundleId: String
    public let tokenCreationDate: Int64
    public let externalPurchaseId: String
    /// Only on custom-link tokens: ACQUISITION, SERVICES, IN_APP, LINK_OUT…
    public let tokenType: String?
    public let tokenExpirationDate: Int64?

    public var isSandbox: Bool { externalPurchaseId.hasPrefix("SANDBOX") }

    /// Decodes a raw token string as returned by StoreKit.
    public static func decode(_ token: String) -> ExternalPurchaseTokenInfo? {
        var b64 = token.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        b64 += String(repeating: "=", count: (4 - b64.count % 4) % 4)
        guard let data = Data(base64Encoded: b64) else { return nil }
        return try? JSONDecoder().decode(ExternalPurchaseTokenInfo.self, from: data)
    }
}

/// A token ready to hand to an external checkout.
public struct ExternalPurchaseToken {
    /// Raw token string — what has to travel to the server / checkout.
    public let value: String
    /// Decoded content, nil if Apple changes the format.
    public let info: ExternalPurchaseTokenInfo?
}

extension Iaptic {

    /// Whether this app can use external purchases on the current storefront.
    @available(iOS 18.1, macOS 15.1, tvOS 18.1, watchOS 11.1, visionOS 2.1, *)
    public static func isExternalPurchaseEligible() async -> Bool {
        await ExternalPurchaseCustomLink.isEligible
    }

    /// Requests an external-purchase token from Apple.
    ///
    /// - Parameter type: `IN_APP` (alternative PSP inside the app) or `LINK_OUT`
    ///   (purchase on a website). `ACQUISITION` / `SERVICES` are the legacy EU types.
    /// - Returns: nil when the app isn't eligible or no active token of that type exists.
    @available(iOS 18.1, macOS 15.1, tvOS 18.1, watchOS 11.1, visionOS 2.1, *)
    public static func externalPurchaseToken(type: String) async throws -> ExternalPurchaseToken? {
        guard await ExternalPurchaseCustomLink.isEligible else { return nil }
        guard let token = try await ExternalPurchaseCustomLink.token(for: type) else { return nil }
        return ExternalPurchaseToken(value: token.value, info: ExternalPurchaseTokenInfo.decode(token.value))
    }
}
