# IapticValidator for StoreKit 2

The `IapticValidator` is a Swift class that simplifies the validation of StoreKit 2 in-app purchases and subscriptions with the iaptic validation service.

## Features

- Easy integration with StoreKit 2
- Support for validating transactions and purchase results
- Detailed validation responses
- Comprehensive error handling

## Requirements

- iOS 15.0+, macOS 12.0+, watchOS 8.0+, tvOS 15.0+
- Swift 5.5+
- StoreKit 2

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/iaptic/iaptic-storekit2.git", from: "1.0.0")
]
```

### Manual Installation

Simply copy the `IapticValidator.swift` file into your project.

## Usage

### Initialization

```swift
import StoreKit
import IapticValidator // If using SPM

// Initialize the validator with your iaptic credentials
let validator = IapticValidator(
    appName: "your-app-name",
    publicKey: "your-public-key"
)
```

### Validating a Purchase

```swift
func buyProduct(_ product: Product) async {
    do {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verificationResult):
            // Validate with iaptic
            let isValid = await validator.validate(productId: product.id, purchaseResult: result)
            
            if isValid {
                print("Purchase validated successfully with iaptic")
                // Grant temporary entitlements to the user,
                // until iaptic informs your server of the purchase with a webhook call.
            } else {
                print("Purchase validation failed with iaptic")
                // Handle validation failure
            }
            
            // Finish the transaction if verified
            if case .verified(let transaction) = verificationResult {
                await transaction.finish()
                // Update your purchased products list
            }
        case .pending:
            // Handle pending transaction
            break
        case .userCancelled:
            // Handle user cancellation
            break
        @unknown default:
            // Handle unknown cases
            break
        }
    } catch {
        print("Failed to purchase the product: \(error)")
    }
}
```

### Validating a Transaction

```swift
// When handling transaction updates
for await verificationResult in Transaction.updates {
    if case .verified(let transaction) = verificationResult {
        let isValid = await validator.validate(
            productId: transaction.productID,
            verificationResult: verificationResult
        )
        
        if isValid {
            // Grant entitlements to the user
        }
    }
}
```

### Getting Detailed Validation Results

```swift
// For more detailed validation results
if let jwsRepresentation = verificationResult.jwsRepresentation {
    if let validationDetails = await validator.validateWithDetails(
        productId: product.id,
        jwsRepresentation: jwsRepresentation
    ) {
        // Access detailed validation information
        print("Validation details: \(validationDetails)")
        
        // Example: Check if the subscription is active
        if let isActive = validationDetails["is_active"] as? Bool, isActive {
            // Handle active subscription
        }
        
        // Example: Get expiration date
        if let expiresDate = validationDetails["expires_date"] as? String {
            // Handle expiration date
        }
    }
}
```

## Error Handling

The validator includes comprehensive error handling:

- Network errors
- Invalid responses
- Authentication failures
- Validation failures

## Support

For support or questions about the iaptic validation service, please contact support@iaptic.com or visit [iaptic.com](https://iaptic.com).

## License

The IapticValidator is available under the MIT license. See the LICENSE file for more info. 