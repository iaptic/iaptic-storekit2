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

/// Represents the state of an iaptic validation request
public enum IapticRequestState: String {
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
}

/// Represents a request made to the iaptic validation service
public class IapticRequest {
    /// The date when the request started
    public let startDate: Date
    
    /// The date when the request completed or failed
    public var endDate: Date?
    
    /// The current state of the request
    public var state: IapticRequestState
    
    /// The product ID being validated
    public let productId: String?
    
    /// The transaction ID being validated
    public let transactionId: String
    
    /// The original transaction ID, if available
    public let originalTransactionId: String?
    
    /// The result of the validation, available when state is completed
    public var validationResult: ValidationResult?
    
    /// Continuations waiting for this request to complete
    internal var continuations: [CheckedContinuation<ValidationResult, Never>] = []
    
    /// Initializes a new iaptic request
    internal init(productId: String?, transactionId: String, originalTransactionId: String? = nil) {
        self.startDate = Date()
        self.state = .inProgress
        self.productId = productId
        self.transactionId = transactionId
        self.originalTransactionId = originalTransactionId
    }
    
    /// Completes the request with a validation result
    internal func complete(with result: ValidationResult) {
        self.endDate = Date()
        self.validationResult = result
        self.state = result.isValid ? .completed : .failed
        
        // Resume all waiting continuations with the result
        for continuation in continuations {
            continuation.resume(returning: result)
        }
        continuations.removeAll()
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
    
    /// The list of requests made to the iaptic service
    private var requests: [IapticRequest] = []
    
    /// Lock for thread-safe access to requests
    private let requestsLock = NSLock()
    
    /// Whether to print verbose logs
    private let verbose: Bool
    
    /// Prints a message only if verbose logging is enabled
    private func log(_ message: String) {
        if verbose {
            print("[Iaptic] \(message)")
        }
    }
    
    // MARK: - Initialization
    
    /// Initializes a new iaptic validator.
    /// - Parameters:
    ///   - baseURL: The base URL for the iaptic API. Defaults to the production URL.
    ///   - appName: The app name registered with iaptic.
    ///   - publicKey: The public key for authentication with iaptic.
    ///   - verbose: Whether to print verbose logs. Defaults to false.
    public init(
        baseURL: String = "https://validator.iaptic.com",
        appName: String,
        publicKey: String,
        verbose: Bool = false
    ) {
        self.baseURL = baseURL
        self.appName = appName
        self.publicKey = publicKey
        self.verbose = verbose
    }
    
    // MARK: - Request Management
    
    /// Finds an existing request for the given transaction ID
    /// - Parameter transactionId: The transaction ID to look for
    /// - Returns: An existing request if found, nil otherwise
    private func findExistingRequest(for transactionId: String) -> IapticRequest? {
        requestsLock.lock()
        defer { requestsLock.unlock() }
        
        return requests.first { $0.transactionId == transactionId }
    }
    
    /// Adds a new request to the list
    /// - Parameter request: The request to add
    private func addRequest(_ request: IapticRequest) {
        requestsLock.lock()
        defer { requestsLock.unlock() }
        
        requests.append(request)
    }
    
    /// Gets all completed requests
    /// - Returns: Array of completed requests
    private func getCompletedRequests() -> [IapticRequest] {
        requestsLock.lock()
        defer { requestsLock.unlock() }
        
        return requests.filter { $0.state == .completed }
    }
    
    /// Gets the most recent completed request
    /// - Returns: The most recent completed request, if any
    private func getMostRecentCompletedRequest() -> IapticRequest? {
        requestsLock.lock()
        defer { requestsLock.unlock() }
        
        return requests
            .filter { $0.state == .completed }
            .sorted { $0.endDate ?? Date.distantPast > $1.endDate ?? Date.distantPast }
            .first
    }
    
    // MARK: - Public Methods
    
    /// Gets all verified purchases from the most recent completed request
    /// - Returns: Array of verified purchases, or nil if no completed requests exist
    public func getVerifiedPurchases() -> [ValidationResult.Purchase]? {
        guard let mostRecentRequest = getMostRecentCompletedRequest(),
              let result = mostRecentRequest.validationResult,
              result.isValid else {
            return nil
        }
        
        return result.purchases
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
        
        // Extract transaction ID from the verification result
        var transactionId = ""
        var originalTransactionId: String? = nil
        
        switch verificationResult {
        case .verified(let transaction):
            transactionId = transaction.id.description
            originalTransactionId = transaction.originalID.description
        case .unverified:
            // For unverified transactions, we'll still validate with iaptic but can't track by ID
            transactionId = UUID().uuidString
        }
        
        return await validateWithJWS(
            productId: productId,
            jwsRepresentation: jwsRepresentation,
            applicationUsername: applicationUsername,
            transactionId: transactionId,
            originalTransactionId: originalTransactionId
        )
    }
    
    /// Validates a StoreKit 2 purchase result with iaptic.
    /// - Parameters:
    ///   - productId: The product identifier.
    ///   - purchaseResult: The purchase result from StoreKit 2.
    ///   - applicationUsername: The username associated with the purchase.
    /// - Returns: A validtion result containing details about the validation.
    @MainActor
    public func validate(productId: String, purchaseResult: Product.PurchaseResult, applicationUsername: String = "") async -> ValidationResult {
        switch purchaseResult {
        case .success(let verificationResult):
            let jwsRepresentation = verificationResult.jwsRepresentation
            
            // Extract transaction ID from the verification result
            var transactionId = ""
            var originalTransactionId: String? = nil
            
            switch verificationResult {
            case .verified(let transaction):
                transactionId = transaction.id.description
                originalTransactionId = transaction.originalID.description
            case .unverified:
                // For unverified transactions, we'll still validate with iaptic but can't track by ID
                transactionId = UUID().uuidString
            }
            
            return await validateWithJWS(
                productId: productId,
                jwsRepresentation: jwsRepresentation,
                applicationUsername: applicationUsername,
                transactionId: transactionId,
                originalTransactionId: originalTransactionId
            )
        default:
            return ValidationResult(errorCode: "PurchaseFailed", errorMessage: "The purchase was not successful")
        }
    }
    
    /// Validates a transaction using its JWS representation with iaptic.
    /// - Parameters:
    ///   - productId: The product identifier.
    ///   - jwsRepresentation: The JWS representation of the transaction.
    ///   - applicationUsername: The username associated with the purchase.
    ///   - transactionId: The ID of the transaction being validated.
    ///   - originalTransactionId: The original transaction ID, if available.
    ///   - retryCount: Number of retry attempts for network failures. Defaults to 3.
    ///   - retryDelay: Delay in seconds between retry attempts. Defaults to 1 second.
    /// - Returns: A validation result containing details about the validation.
    public func validateWithJWS(
        productId: String? = nil,
        jwsRepresentation: String,
        applicationUsername: String = "",
        transactionId: String = UUID().uuidString,
        originalTransactionId: String? = nil,
        retryCount: Int = 8,
        retryDelay: TimeInterval = 5.0
    ) async -> ValidationResult {
        // Check if we already have a request for this transaction
        if let existingRequest = findExistingRequest(for: transactionId) {
            switch existingRequest.state {
            case .completed, .failed:
                // If we have a recent completed or failed request, return its result
                if let result = existingRequest.validationResult,
                   existingRequest.endDate != nil,
                   Date().timeIntervalSince(existingRequest.endDate!) < 300 { // 5 minutes cache
                    log("Using cached validation result for transaction \(transactionId)")
                    return result
                }
                // Otherwise, proceed with a new validation
                
            case .inProgress:
                // If a request is in progress, wait for it to complete
                log("Waiting for in-progress validation of transaction \(transactionId)")
                return await withCheckedContinuation { continuation in
                    existingRequest.continuations.append(continuation)
                }
            }
        }
        
        // Create a new request
        let request = IapticRequest(
            productId: productId,
            transactionId: transactionId,
            originalTransactionId: originalTransactionId
        )
        addRequest(request)
        log("Starting validation for transaction \(transactionId)")
        
        // Create the URL for the iaptic API
        guard let url = URL(string: "\(baseURL)/v1/validate") else {
            let result = ValidationResult(errorCode: "InvalidURL", errorMessage: "Invalid API URL")
            request.complete(with: result)
            return result
        }
        
        // Create the request body according to iaptic documentation
        let requestBody: [String: Any] = [
            "id": Bundle.main.bundleIdentifier ?? "",
            "type": "application",
            "transaction": [
                "id": productId ?? Bundle.main.bundleIdentifier ?? "",
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
        
        // Prepare the JSON data and URL request outside the retry loop
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error serializing request body: \(error)")
            let result = ValidationResult(errorCode: "SerializationError", errorMessage: error.localizedDescription)
            request.complete(with: result)
            return result
        }
        
        // Create the request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add iaptic authorization header
        let authString = "\(appName):\(publicKey)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            urlRequest.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = jsonData
        
        // Implement retry mechanism for network failures
        var currentRetry = 0
        var lastError: Error? = nil
        
        while currentRetry <= retryCount {
            do {
                // Make the request
                let (data, response) = try await URLSession.shared.data(for: urlRequest)
                
                // Handle the response
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        // Parse and handle successful response
                        if let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let ok = responseJSON["ok"] as? Bool, ok {
                                // Successful validation
                                log("Validation successful for transaction \(transactionId)")
                                
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
                                
                                let result = ValidationResult(
                                    isValid: true,
                                    purchases: purchases,
                                    ineligibleForIntroPrice: ineligibleForIntroPrice,
                                    productId: productId,
                                    validationDate: validationDate,
                                    warning: warning
                                )
                                
                                request.complete(with: result)
                                return result
                            } else {
                                // Failed validation (not a network error, so don't retry)
                                print("[Iaptic] Validation failed: \(responseJSON)") // Always print validation failures
                                let errorCode = responseJSON["code"] as? String
                                let errorMessage = responseJSON["message"] as? String
                                let result = ValidationResult(errorCode: errorCode, errorMessage: errorMessage)
                                
                                request.complete(with: result)
                                return result
                            }
                        }
                    } else if httpResponse.statusCode >= 500 && currentRetry < retryCount {
                        // Server error, retry if we haven't reached the maximum retry count
                        print("[Iaptic] Server error (HTTP \(httpResponse.statusCode)), retrying (\(currentRetry + 1)/\(retryCount))...") // Always print server errors
                        currentRetry += 1
                        // Wait before retrying
                        let backoffDelay = retryDelay * pow(2.0, Double(currentRetry - 1))
                        try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                        continue
                    } else {
                        // Client error or we've reached max retries for server error
                        print("[Iaptic] HTTP Error: \(httpResponse.statusCode)") // Always print HTTP errors
                        let result = ValidationResult(errorCode: "HTTPError", errorMessage: "HTTP Error: \(httpResponse.statusCode)")
                        request.complete(with: result)
                        return result
                    }
                }
                
                // If we get here, something unexpected happened with the response
                print("[Iaptic] Unknown error occurred during validation") // Always print unknown errors
                let result = ValidationResult(errorCode: "UnknownError", errorMessage: "Unknown error occurred during validation")
                request.complete(with: result)
                return result
                
            } catch {
                // Network error or other exception
                lastError = error
                
                if currentRetry < retryCount {
                    // Log and retry
                    print("[Iaptic] Network error: \(error.localizedDescription), retrying (\(currentRetry + 1)/\(retryCount))...") // Always print network errors
                    currentRetry += 1
                    
                    // Use exponential backoff for retries
                    let backoffDelay = retryDelay * pow(2.0, Double(currentRetry - 1))
                    try? await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                } else {
                    // We've exhausted our retries
                    break
                }
            }
        }
        
        // If we get here, we've exhausted our retries with errors
        print("[Iaptic] Error validating with iaptic after \(retryCount) retries: \(lastError?.localizedDescription ?? "Unknown error")") // Always print final errors
        let result = ValidationResult(errorCode: "RequestError", errorMessage: lastError?.localizedDescription ?? "Network request failed after multiple attempts")
        request.complete(with: result)
        return result
    }
} 
