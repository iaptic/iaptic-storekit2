import XCTest
@testable import Iaptic

final class IapticTests: XCTestCase {
    func testInitialization() {
        // This is a simple test to ensure the validator can be initialized
        let validator = Iaptic(
            appName: "test-app", 
            publicKey: "test-key"
        )
        XCTAssertNotNil(validator)
    }

    // Sample tokens from Apple's "Receiving and decoding external purchase tokens".
    func testDecodeExternalPurchaseToken() {
        let services = "eyJhcHBBcHBsZUlkIjoxMjM0NTY3ODkwLCJidW5kbGVJZCI6ImNvbS5leGFtcGxlIiwidG9rZW5DcmVhdGlvbkRhdGUiOjE3NTA4OTYwMDAwMDAsImV4dGVybmFsUHVyY2hhc2VJZCI6IjAwMDAwMDAwLTAwMDAtMDAwMC0wMDAwLTAwMDAwMDAwMDAwMCIsInRva2VuVHlwZSI6IlNFUlZJQ0VTIiwidG9rZW5FeHBpcmF0aW9uRGF0ZSI6MTc4MjQzMjAwMDAwMH0K"
        let info = ExternalPurchaseTokenInfo.decode(services)
        XCTAssertEqual(info?.appAppleId, 1234567890)
        XCTAssertEqual(info?.bundleId, "com.example")
        XCTAssertEqual(info?.tokenType, "SERVICES")
        XCTAssertEqual(info?.tokenExpirationDate, 1782432000000)
        XCTAssertEqual(info?.isSandbox, false)

        let sandbox = "eyJhcHBBcHBsZUlkIjoxMjM0NTY3ODkwLCJidW5kbGVJZCI6ImNvbS5leGFtcGxlIiwidG9rZW5DcmVhdGlvbkRhdGUiOjE3MzA0NDg3MjAwMDAsImV4dGVybmFsUHVyY2hhc2VJZCI6IlNBTkRCT1hfMDAwMDAwMDAtMDAwMC0wMDAwLTAwMDAtMDAwMDAwMDAwMDAwIiwidG9rZW5UeXBlIjoiU0VSVklDRVMiLCJ0b2tlbkV4cGlyYXRpb25EYXRlIjoxNzMwNDUyMzIwMDAwfQ=="
        XCTAssertEqual(ExternalPurchaseTokenInfo.decode(sandbox)?.isSandbox, true)
        XCTAssertNil(ExternalPurchaseTokenInfo.decode("not-a-token"))
    }
} 