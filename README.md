# Iaptic for StoreKit 2

The `Iaptic` is a Swift class that simplifies the validation of StoreKit 2 in-app purchases and subscriptions with the iaptic validation service.

## Features

- Easy integration with StoreKit 2
- Support for validating transactions and purchase results
- Detailed validation responses with `ValidationResult` class
- Support for application username and device metadata
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

#### Local Installation with SPM

You can also use a local copy of the package by specifying the path to the package directory:

```swift
dependencies: [
    .package(path: "/path/to/local/iaptic-storekit2")
]
```

For Xcode projects, you can add a local package by:
1. In Xcode, go to File > Add Packages...
2. Click on "Add Local..." at the bottom of the dialog
3. Navigate to and select the local iaptic-storekit2 directory
4. Click "Add Package"

### Manual Installation

Simply copy the `Iaptic.swift` file into your project.

## Usage

### Initialization

```swift
import StoreKit
import Iaptic // If using SPM

// Initialize the validator with your iaptic credentials
let iaptic = Iaptic(
    appName: "your-app-name",
    publicKey: "your-public-key"
)
```

### Validating a Purchase

```swift
func buyProduct(_ product: Product) async {
    do {
        let result = try await product.purchase(options: [.appAccountToken(UUID())])
        
        switch result {
        case .success(let verificationResult):
            // Validate with iaptic
            let validationResult = await iaptic.validate(
                productId: product.id, 
                purchaseResult: result,
                applicationUsername: "user123" // Optional
            )
            
            if validationResult.isValid {
                print("Purchase validated successfully with iaptic")
                // Grant temporary entitlements to the user,
                // until iaptic informs your server of the purchase with a webhook call.
                
                // Check if subscription is active
                if validationResult.isActive {
                    // Handle active subscription
                }
            } else {
                print("Purchase validation failed with iaptic: \(validationResult.errorMessage ?? "Unknown error")")
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
        let validationResult = await iaptic.validate(
            productId: transaction.productID,
            verificationResult: verificationResult,
            applicationUsername: "user123" // Optional
        )
        
        if validationResult.isValid && validationResult.isActive {
            // Grant entitlements to the user
        }
    }
}
```

### Working with ValidationResult

```swift
// Access detailed validation information
let validationResult = await iaptic.validate(
    productId: product.id,
    purchaseResult: result
)

// Check if validation was successful
if validationResult.isValid {
    // Check if subscription is active
    if validationResult.isActive {
        // Handle active subscription
    }
    
    // Check if subscription is expired
    if validationResult.isExpired {
        // Handle expired subscription
    }
    
    // Access purchase details
    if let purchases = validationResult.purchases {
        for purchase in purchases {
            // Access purchase information
            print("Product ID: \(purchase.id)")
            
            if let expiryDate = purchase.expiryDate {
                print("Expires on: \(expiryDate)")
            }
            
            if let isTrialPeriod = purchase.isTrialPeriod, isTrialPeriod {
                print("User is in trial period")
            }
        }
    }
} else {
    // Handle validation error
    if let errorCode = validationResult.errorCode, 
       let errorMessage = validationResult.errorMessage {
        print("Validation failed: \(errorCode) - \(errorMessage)")
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

The Iaptic package is available under the MIT license. See the LICENSE file for more info. 
