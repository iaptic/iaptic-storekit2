import Foundation
import StoreKit

public class ValidationResult {
    /// Indicates whether the validation was successful
    public let isValid: Bool
    
    /// Indicates whether the subscription or purchase has expired
    public let isExpired: Bool
    
    /// Indicates whether the subscription or purchase is currently active
    public let isActive: Bool
    
    /// The collection of purchases in this receipt
    public let purchases: [Purchase]?
    
    /// List of product IDs for which intro price isn't available anymore
    public let ineligibleForIntroPrice: [String]?
    
    /// ID of the product that has been validated
    public let productId: String?
    
    /// Date and time the receipt validation request was processed
    public let validationDate: Date?
    
    /// A warning message about this validation (if any)
    public let warning: String?
    
    /// Error code if validation failed
    public let errorCode: String?
    
    /// Error message if validation failed
    public let errorMessage: String?
    
    /// Creates a validation result from a successful response
    internal init(isValid: Bool, purchases: [Purchase]? = nil, ineligibleForIntroPrice: [String]? = nil, 
                 productId: String? = nil, validationDate: Date? = nil, warning: String? = nil) {
        self.isValid = isValid
        self.purchases = purchases
        self.ineligibleForIntroPrice = ineligibleForIntroPrice
        self.productId = productId
        self.validationDate = validationDate
        self.warning = warning
        self.errorCode = nil
        self.errorMessage = nil
        
        // Determine if expired and active based on purchases
        if let purchases = purchases, !purchases.isEmpty {
            self.isExpired = purchases.allSatisfy { $0.isExpired == true }
            self.isActive = !self.isExpired && isValid
        } else {
            self.isExpired = false
            self.isActive = isValid
        }
    }
    
    /// Creates a validation result from an error response
    internal init(errorCode: String?, errorMessage: String?) {
        self.isValid = false
        self.isExpired = false
        self.isActive = false
        self.purchases = nil
        self.ineligibleForIntroPrice = nil
        self.productId = nil
        self.validationDate = nil
        self.warning = nil
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
    
    /// Represents a purchase from the validation response
    public struct Purchase {
        /// Product identifier
        public let id: String
        
        /// Date of first purchase
        public let purchaseDate: Date?
        
        /// Date of expiry for a subscription
        public let expiryDate: Date?
        
        /// True when a subscription is expired
        public let isExpired: Bool?
        
        /// Renewal intent (Lapse, Renew)
        public let renewalIntent: String?
        
        /// Date the renewal intent was updated by the user
        public let renewalIntentChangeDate: Date?
        
        /// The reason a subscription or purchase was cancelled
        public let cancelationReason: String?
        
        /// True when a subscription is in the grace period after a failed payment
        public let isBillingRetryPeriod: Bool?
        
        /// True when a subscription is in trial period
        public let isTrialPeriod: Bool?
        
        /// True when a subscription is in introductory pricing period
        public let isIntroPeriod: Bool?
        
        /// True when a purchase is acknowledged
        public let isAcknowledged: Bool?
        
        /// Identifier of the discount currently applied to a purchase
        public let discountId: String?
        
        /// Whether the user agreed or has been notified of a price change
        public let priceConsentStatus: String?
        
        /// Last time a subscription was renewed
        public let lastRenewalDate: Date?
    }
}

/// A validator for StoreKit 2 transactions using the iaptic validation service.
/// This class provides methods to validate in-app purchases and subscriptions with iaptic.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
public class Iaptic {
    
    static let version = "1.0.0"
    
    // MARK: - Properties
    
    /// The base URL for the iaptic API.
    private let baseURL: String
    
    /// The app name registered with iaptic.
    private let appName: String
    
    /// The public key for authentication with iaptic.
    private let publicKey: String
    
    /// The bundle ID of the app.
    private let bundleId: String
    
    // MARK: - Initialization
    
    /// Initializes a new iaptic validator.
    /// - Parameters:
    ///   - baseURL: The base URL for the iaptic API. Defaults to the production URL.
    ///   - appName: The app name registered with iaptic.
    ///   - publicKey: The public key for authentication with iaptic.
    public init(
        baseURL: String = "https://validator.iaptic.com",
        appName: String,
        publicKey: String,
        bundleId: String
    ) {
        self.baseURL = baseURL
        self.appName = appName
        self.publicKey = publicKey
        self.bundleId = bundleId
    }
    
    // MARK: - Validation Methods
    
    /// Validates a StoreKit 2 transaction with iaptic.
    /// - Parameters:
    ///   - productId: The product identifier.
    ///   - verificationResult: The verification result from StoreKit 2.
    ///   - applicationUsername: The username associated with the purchase.
    /// - Returns: A validation result containing details about the validation.
    @MainActor
    public func validate(productId: String, verificationResult: StoreKit.VerificationResult<StoreKit.Transaction>, applicationUsername: String = "") async -> ValidationResult {
        let jwsRepresentation = verificationResult.jwsRepresentation
        return await validateWithJWS(productId: productId, jwsRepresentation: jwsRepresentation, applicationUsername: applicationUsername)
    }
    
    /// Validates a StoreKit 2 purchase result with iaptic.
    /// - Parameters:
    ///   - productId: The product identifier.
    ///   - purchaseResult: The purchase result from StoreKit 2.
    ///   - applicationUsername: The username associated with the purchase.
    /// - Returns: A validation result containing details about the validation.
    @MainActor
    public func validate(productId: String, purchaseResult: Product.PurchaseResult, applicationUsername: String = "") async -> ValidationResult {
        switch purchaseResult {
        case .success(let verificationResult):
            let jwsRepresentation = verificationResult.jwsRepresentation
            return await validateWithJWS(productId: productId, jwsRepresentation: jwsRepresentation, applicationUsername: applicationUsername)
        default:
            return ValidationResult(errorCode: "PurchaseFailed", errorMessage: "The purchase was not successful")
        }
    }
    
    /// Validates a transaction using its JWS representation with iaptic.
    /// - Parameters:
    ///   - productId: The product identifier.
    ///   - jwsRepresentation: The JWS representation of the transaction.
    ///   - applicationUsername: The username associated with the purchase.
    /// - Returns: A validation result containing details about the validation.
    public func validateWithJWS(productId: String, jwsRepresentation: String, applicationUsername: String = "") async -> ValidationResult {
        // Create the URL for the iaptic API
        guard let url = URL(string: "\(baseURL)/v1/validate") else {
            print("Invalid URL")
            return ValidationResult(errorCode: "InvalidURL", errorMessage: "Invalid API URL")
        }
        
        // Create the request body according to iaptic documentation
        let requestBody: [String: Any] = [
            "id": self.bundleId,
            "type": "application",
            "transaction": [
                "id": productId,
                "type": "apple-sk2",
                "jwsRepresentation": jwsRepresentation
            ],
            "additionalData": [
                "applicationUsername": applicationUsername
            ],
            "device": [
                "plugin": "iaptic-storekit2/" + Iaptic.version,
            ]
        ]
        
        do {
            // Convert the request body to JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            // Create the request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Add iaptic authorization header
            let authString = "\(appName):\(publicKey)"
            if let authData = authString.data(using: .utf8) {
                let base64Auth = authData.base64EncodedString()
                request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
            }
            
            request.httpBody = jsonData
            
            // Make the request
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Handle the response
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    // Parse and handle successful response
                    if let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let ok = responseJSON["ok"] as? Bool, ok {
                            // Successful validation
                            print("Validation successful: \(responseJSON)")
                            
                            // Parse the response data
                            var purchases: [ValidationResult.Purchase]? = nil
                            var ineligibleForIntroPrice: [String]? = nil
                            var validationDate: Date? = nil
                            var warning: String? = nil
                            
                            if let dataObj = responseJSON["data"] as? [String: Any] {
                                // Parse purchases collection
                                if let collection = dataObj["collection"] as? [[String: Any]] {
                                    purchases = collection.compactMap { purchaseData in
                                        guard let id = purchaseData["id"] as? String else { return nil }
                                        
                                        // Parse dates from timestamps
                                        let purchaseDate = (purchaseData["purchaseDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0 / 1000) }
                                        let expiryDate = (purchaseData["expiryDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0 / 1000) }
                                        let renewalIntentChangeDate = (purchaseData["renewalIntentChangeDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0 / 1000) }
                                        let lastRenewalDate = (purchaseData["lastRenewalDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0 / 1000) }
                                        
                                        return ValidationResult.Purchase(
                                            id: id,
                                            purchaseDate: purchaseDate,
                                            expiryDate: expiryDate,
                                            isExpired: purchaseData["isExpired"] as? Bool,
                                            renewalIntent: purchaseData["renewalIntent"] as? String,
                                            renewalIntentChangeDate: renewalIntentChangeDate,
                                            cancelationReason: purchaseData["cancelationReason"] as? String,
                                            isBillingRetryPeriod: purchaseData["isBillingRetryPeriod"] as? Bool,
                                            isTrialPeriod: purchaseData["isTrialPeriod"] as? Bool,
                                            isIntroPeriod: purchaseData["isIntroPeriod"] as? Bool,
                                            isAcknowledged: purchaseData["isAcknowledged"] as? Bool,
                                            discountId: purchaseData["discountId"] as? String,
                                            priceConsentStatus: purchaseData["priceConsentStatus"] as? String,
                                            lastRenewalDate: lastRenewalDate
                                        )
                                    }
                                }
                                
                                // Parse ineligible for intro price products
                                ineligibleForIntroPrice = dataObj["ineligible_for_intro_price"] as? [String]
                                
                                // Parse warning
                                warning = dataObj["warning"] as? String
                                
                                // Parse validation date
                                if let dateString = dataObj["date"] as? String {
                                    let formatter = ISO8601DateFormatter()
                                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                    validationDate = formatter.date(from: dateString)
                                }
                            }
                            
                            return ValidationResult(
                                isValid: true,
                                purchases: purchases,
                                ineligibleForIntroPrice: ineligibleForIntroPrice,
                                productId: productId,
                                validationDate: validationDate,
                                warning: warning
                            )
                        } else {
                            // Failed validation
                            print("Validation failed: \(responseJSON)")
                            let errorCode = responseJSON["code"] as? String
                            let errorMessage = responseJSON["message"] as? String
                            return ValidationResult(errorCode: errorCode, errorMessage: errorMessage)
                        }
                    }
                } else {
                    print("HTTP Error: \(httpResponse.statusCode)")
                    return ValidationResult(errorCode: "HTTPError", errorMessage: "HTTP Error: \(httpResponse.statusCode)")
                }
            }
            
            return ValidationResult(errorCode: "UnknownError", errorMessage: "Unknown error occurred during validation")
        } catch {
            print("Error validating with iaptic: \(error)")
            return ValidationResult(errorCode: "RequestError", errorMessage: error.localizedDescription)
        }
    }
} 
