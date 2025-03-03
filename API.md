# Iaptic StoreKit 2 API Reference

This document provides a comprehensive reference for the Iaptic StoreKit 2 package API.

## Table of Contents

- [Initialization](#initialization)
- [Core Methods](#core-methods)
- [ValidationResult](#validationresult)
- [Purchase Object](#purchase-object)
- [Error Handling](#error-handling)
- [Configuration Options](#configuration-options)
- [Advanced Usage](#advanced-usage)

## Initialization

### Basic Initialization

```swift
let iaptic = Iaptic(
    appName: "your-app-name",
    publicKey: "your-public-key"
)
```

### Advanced Initialization

```swift
let iaptic = Iaptic(
    baseURL: "https://validator.iaptic.com", // Optional: Custom API endpoint
    appName: "your-app-name",
    publicKey: "your-public-key",
    verbose: true // Optional: Enable detailed logging
)
```

## Core Methods

### Validate Purchase Result

Validates a purchase result from StoreKit 2.

```swift
@MainActor
func validate(
    productId: String,
    purchaseResult: Product.PurchaseResult,
    applicationUsername: String = ""
) async -> ValidationResult
```

**Parameters:**
- `productId`: The product identifier
- `purchaseResult`: The purchase result from StoreKit 2
- `applicationUsername`: Optional user identifier for tracking purchases (defaults to empty string)

**Returns:** A `ValidationResult` object containing validation details

### Validate Verification Result

Validates a transaction verification result from StoreKit 2.

```swift
@MainActor
func validate(
    productId: String,
    verificationResult: VerificationResult<Transaction>,
    applicationUsername: String = ""
) async -> ValidationResult
```

**Parameters:**
- `productId`: The product identifier
- `verificationResult`: The verification result from StoreKit 2
- `applicationUsername`: Optional user identifier for tracking purchases (defaults to empty string)

**Returns:** A `ValidationResult` object containing validation details

### Validate with JWS

Validates a transaction using its JWS representation.

```swift
func validateWithJWS(
    productId: String? = nil,
    jwsRepresentation: String,
    applicationUsername: String = "",
    transactionId: String = UUID().uuidString,
    originalTransactionId: String? = nil,
    retryCount: Int = 8,
    retryDelay: TimeInterval = 5.0
) async -> ValidationResult
```

**Parameters:**
- `productId`: The product identifier (optional)
- `jwsRepresentation`: The JWS representation of the transaction
- `applicationUsername`: Optional user identifier for tracking purchases (defaults to empty string)
- `transactionId`: The transaction ID (defaults to a new UUID string)
- `originalTransactionId`: The original transaction ID (optional)
- `retryCount`: Number of retry attempts for network failures (defaults to 8)
- `retryDelay`: Delay in seconds between retry attempts (defaults to 5.0)

**Returns:** A `ValidationResult` object containing validation details

### Get Verified Purchases

Retrieves the most recent verified purchases from the last validation.

```swift
func getVerifiedPurchases() -> [ValidationResult.Purchase]?
```

**Returns:** An array of `Purchase` objects if available, or `nil` if no verified purchases exist

## ValidationResult

The `ValidationResult` class provides detailed information about the validation result.

### Properties

```swift
// Core validation status
var isValid: Bool
var isExpired: Bool
var isActive: Bool

// Error information
var errorCode: String?
var errorMessage: String?

// Purchase details
var purchases: [Purchase]?

// Additional information
var ineligibleForIntroPrice: [String]?
var productId: String?
var validationDate: Date?
var warning: String?
```

## Purchase Object

The `Purchase` struct represents a validated purchase with standardized properties.

### Properties

```swift
// Core purchase information
var id: String

// Dates
var purchaseDate: Date?
var expiryDate: Date?
var renewalIntentChangeDate: Date?
var lastRenewalDate: Date?

// Subscription details
var isExpired: Bool?
var renewalIntent: String?
var cancelationReason: String?
var isBillingRetryPeriod: Bool?
var isTrialPeriod: Bool?
var isIntroPeriod: Bool?
var isAcknowledged: Bool?
var discountId: String?
var priceConsentStatus: String?
```

## Error Handling

### Error Codes

The `errorCode` in `ValidationResult` is a string value that can contain the following:

- `"PurchaseFailed"`: The purchase operation was not successful
- `"InvalidURL"`: Invalid API URL
- `"SerializationError"`: Error serializing request body
- `"HTTPError"`: HTTP error with server communication
- `"UnknownError"`: Unknown error occurred during validation
- `"RequestError"`: Network request failed after multiple attempts

### Error Handling Example

```swift
let validationResult = await iaptic.validate(
    productId: product.id,
    purchaseResult: result
)

if validationResult.isValid {
    // Handle valid purchase
} else {
    if let errorCode = validationResult.errorCode,
       let errorMessage = validationResult.errorMessage {
        switch errorCode {
        case "InvalidURL":
            print("Invalid URL: \(errorMessage)")
        case "HTTPError":
            print("HTTP Error: \(errorMessage)")
        case "RequestError":
            print("Network error: \(errorMessage)")
        default:
            print("Validation error: \(errorCode) - \(errorMessage)")
        }
    } else {
        print("Unknown validation error")
    }
}
```

## Configuration Options

### Logging

Control the verbosity of logging:

```swift
// Enable verbose logging
let iaptic = Iaptic(
    appName: "your-app-name",
    publicKey: "your-public-key",
    verbose: true
)

// Disable verbose logging (default)
let iaptic = Iaptic(
    appName: "your-app-name",
    publicKey: "your-public-key",
    verbose: false
)
```

### Custom API Endpoint

Use a custom API endpoint:

```swift
let iaptic = Iaptic(
    baseURL: "https://custom-api.example.com",
    appName: "your-app-name",
    publicKey: "your-public-key"
)
```

## Advanced Usage

### Check the user entitlement

```swift
func updateEntitlements() {
    if let verifiedPurchases = self.iaptic.getVerifiedPurchases() {
        self.entitlementManager?.hasPro = verifiedPurchases.contains { !($0.isExpired ?? false) && ($0.id == "my.pro.product") }
    } else {
        self.entitlementManager?.hasPro = false
    }
}
```

### Verify a receipt

```swift
func verifyWithIaptic(jwsRepresentation: String, productID: String) async {
    let response = await iaptic.validateWithJWS(
        productId: productID,
        jwsRepresentation: jwsRepresentation,
        applicationUsername: userID
    )
            
    if response.isValid {
        print("✅ Transaction validated successfully with iaptic")
        // Process the verified transaction
        self.updateEntitlements()
    } else {
        print("❌ Transaction validation failed with iaptic: \(response)")
    }
}
```

### Refreshing purchases at startup

```swift
func refreshPurchases() {
    Task {
        print("🔍 Checking transactions")
        for await result in Transaction.currentEntitlements {
            print("⚙️ Processing entitlement")
            switch result {
            case .verified(let transaction):
                print("✅ Entitlement verified for product: \(transaction.productID)")
                await self.verifyWithIaptic(jwsRepresentation: result.jwsRepresentation, productID: transaction.productID)
            case .unverified(let transaction, let error):
                print("❌ Entitlement local verification failed: \(error.localizedDescription)")
                print("⚠️ Unverified product ID: \(transaction.productID)")
                await self.verifyWithIaptic(jwsRepresentation: result.jwsRepresentation, productID: transaction.productID)
            }
        }
        
        print("✨ Finished checking transactions")
    }
}
```

### Handling Transaction Updates

Set up an observer for transaction updates:

```swift
func observeTransactionUpdates() -> Task<Void, Never> {
    return Task(priority: .background) {
        for await verificationResult in Transaction.updates {
            switch verificationResult {
            case .verified(let transaction):
                await self.verifyWithIaptic(jwsRepresentation: verificationResult.jwsRepresentation, productID: transaction.productID)
                await transaction.finish()
                
            case .unverified(let transaction, let error):
                // Even with local verification failure, validate with iaptic
                await self.verifyWithIaptic(jwsRepresentation: verificationResult.jwsRepresentation, productID: transaction.productID)
                await transaction.finish()
            }
        }
    }
}
```

### Restoring Purchases

Implement a restore purchases function:

```swift
func restorePurchases() async {
    do {
        // Sync with the App Store
        try await AppStore.sync()
        self.refreshPurchases()
    } catch {
        print("Error restoring purchases: \(error.localizedDescription)")
    }
}
```

### Checking Subscription Status

Check if a user has an active subscription:

```swift
func checkSubscriptionStatus() {
    if let purchases = iaptic.getVerifiedPurchases() {
        let hasActiveSubscription = purchases.contains { purchase in
            // Check if it's not expired
            if let isExpired = purchase.isExpired, isExpired {
                return false
            }
            
            // Check if it has an expiry date in the future
            if let expiryDate = purchase.expiryDate, expiryDate < Date() {
                return false
            }
            
            return true
        }
        
        if hasActiveSubscription {
            // User has an active subscription
            unlockPremiumFeatures()
        } else {
            // No active subscription
            showSubscriptionOptions()
        }
    } else {
        // No verified purchases
        showSubscriptionOptions()
    }
}
```

### Complete Integration Example

For a complete integration example, refer to our [demo project](https://github.com/iaptic/iaptic-storekit2-demo). 