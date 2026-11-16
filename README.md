# Iaptic for StoreKit 2

A lightweight, production-ready Swift package for validating StoreKit 2 in-app purchases and subscriptions. Built on top of [iaptic](https://iaptic.com)'s enterprise-grade validation service.

## Why Iaptic?

- **Robust Receipt Validation**: Server-side validation with real-time fraud detection and automated receipt refresh
- **Zero Maintenance**: Focus on your app while iaptic handles subscription states, edge cases, and server infrastructure
- **Production Ready**: Powers millions of transactions with 99.99% uptime
- **Cross-Platform Support**: One solution for iOS, macOS, watchOS, and tvOS
- **Real-time Insights**: Monitor transactions, subscription health, and revenue in real-time

## Requirements

- iOS 15.0+, macOS 12.0+, watchOS 8.0+, tvOS 15.0+
- Swift 5.5+
- StoreKit 2

## Installation

### Swift Package Manager

#### Using Xcode

1. In Xcode, select **File** > **Add Packages...**
2. Enter the repository URL: `https://github.com/iaptic/iaptic-storekit2.git`
3. Select **Up to Next Major Version** with **1.0.0** as the minimum version
4. Click **Add Package**
5. Select the target where you want to use the package

#### Using Package.swift

If you're developing a Swift package that depends on Iaptic, add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/iaptic/iaptic-storekit2.git", from: "1.0.0")
]
```

> **Note:** All `1.x.x` versions of Iaptic StoreKit 2 will maintain backward compatibility. You can safely use `from: "1.0.0"` to always get the latest compatible version in the 1.x series.

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Iaptic", package: "iaptic-storekit2")
    ]
)
```

### Quick Start

1. Initialize the validator:
```swift
import StoreKit
import Iaptic

let iaptic = Iaptic(
    appName: "your-app-name",
    publicKey: "your-public-key"
)
```

2. Validate purchases:
```swift
// During purchase
let result = try await product.purchase()
switch result {
case .success(let verificationResult):
    let validationResult = await iaptic.validate(
        productId: product.id, 
        purchaseResult: result
    )
    
    if validationResult.isValid {
        // Grant entitlements
    }
    
// During app launch
for await verificationResult in Transaction.updates {
    if case .verified(let transaction) = verificationResult {
        let validationResult = await iaptic.validate(
            productId: transaction.productID,
            verificationResult: verificationResult
        )
        
        if validationResult.isValid {
            // Update entitlements
        }
    }
}
```

## Features

### Enterprise-Grade Security
- Real-time fraud detection
- Server-side validation with multiple security layers
- Automated receipt refresh and validation

### Smart Performance
- Intelligent caching system
- Automatic retry with exponential backoff
- Thread-safe implementation

### Subscription Management
- Real-time subscription state tracking
- Automatic renewal handling
- Built-in grace period support

### Detailed Purchase Information
```swift
if let purchases = validationResult.purchases {
    for purchase in purchases {
        // Access standardized purchase data
        print("Product ID: \(purchase.id)")
        print("Expires: \(purchase.expiryDate ?? "Never")")
        print("Is Trial: \(purchase.isTrialPeriod ?? false)")
    }
}
```

## Offer Code Redemption

No change required. A transaction produced by Apple's offer-code redemption sheet is an ordinary StoreKit 2 transaction: send its `jwsRepresentation` to iaptic and it validates like any purchase. The offer-code reference lands in `discountId`, and `offerType` is `3`.

The redemption sheet itself is a client concern — on iOS 27+ it is `AppStore.presentOfferCodeRedeemSheet(from:options:)`, which returns a `VerificationResult<Transaction>` (below iOS 27 it is the deprecated fire-and-forget sheet). Hand that result to the existing call, exactly as you do for a purchase:

```swift
// Xcode 27.2 SDK: @available(iOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
do {
    let result = try await AppStore.presentOfferCodeRedeemSheet(from: viewController)
    if case .verified(let transaction) = result {
        let validation = await iaptic.validate(
            productId: transaction.productID,
            verificationResult: result
        )
        // Grant entitlements from validation.
    }
} catch {
    // StoreKitError: .userCancelled, .networkError, .invalidPresentationContext, ...
}
```

Offer codes work with consumable, non-consumable, auto-renewable and non-renewing-subscription products; redeeming one for a subscription behaves like a purchase of that subscription.

## Example Project

Check out our [demo project](https://github.com/iaptic/iaptic-storekit2-demo) for a complete implementation example.

## Documentation

For detailed API documentation and implementation guides:

- Visit [iaptic.com/documentation](https://iaptic.com/documentation/iaptic-storekit2).
- Check the [API Documentation](https://www.iaptic.com/documentation/iaptic-storekit2-api)

## Support

- Email: support@iaptic.com
- Documentation: [iaptic.com/docs](https://iaptic.com/documentation/iaptic-storekit2)

## License

MIT License. See [LICENSE](LICENSE) file for details.
