import XCTest
@testable import IapticValidator

final class IapticValidatorTests: XCTestCase {
    func testInitialization() {
        // This is a simple test to ensure the validator can be initialized
        let validator = IapticValidator(appName: "test-app", publicKey: "test-key")
        XCTAssertNotNil(validator)
    }
} 