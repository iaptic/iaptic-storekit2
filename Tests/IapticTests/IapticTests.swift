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
} 