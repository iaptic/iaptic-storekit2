import Foundation
import StoreKit

/// A validator for StoreKit 2 transactions using the iaptic validation service.
/// This class provides methods to validate in-app purchases and subscriptions with iaptic.
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
public class IapticValidator {
    
    // MARK: - Properties
    
    /// The base URL for the iaptic API.
    private let baseURL: String
    
    /// The app name registered with iaptic.
    private let appName: String
    
    /// The public key for authentication with iaptic.
    private let publicKey: String
    
    // MARK: - Initialization
    
    /// Initializes a new iaptic validator.
    /// - Parameters:
    ///   - baseURL: The base URL for the iaptic API. Defaults to the production URL.
    ///   - appName: The app name registered with iaptic.
    ///   - publicKey: The public key for authentication with iaptic.
    public init(
        baseURL: String = "https://validator.iaptic.com",
        appName: String,
        publicKey: String
    ) {
        self.baseURL = baseURL
        self.appName = appName
        self.publicKey = publicKey
    }
    
    // MARK: - Validation Methods
    
    /// Validates a StoreKit 2 transaction with iaptic.
    /// - Parameters:
    ///   - productId: The product identifier.
    ///   - verificationResult: The verification result from StoreKit 2.
    /// - Returns: A boolean indicating whether the validation was successful.
    @MainActor
    public func validate(productId: String, verificationResult: StoreKit.VerificationResult<StoreKit.Transaction>) async -> Bool {
        let jwsRepresentation = verificationResult.jwsRepresentation
        return await validateWithJWS(productId: productId, jwsRepresentation: jwsRepresentation)
    }
    
    /// Validates a StoreKit 2 purchase result with iaptic.
    /// - Parameters:
    ///   - productId: The product identifier.
    ///   - purchaseResult: The purchase result from StoreKit 2.
    /// - Returns: A boolean indicating whether the validation was successful.
    @MainActor
    public func validate(productId: String, purchaseResult: Product.PurchaseResult) async -> Bool {
        switch purchaseResult {
        case .success(let verificationResult):
            let jwsRepresentation = verificationResult.jwsRepresentation
            return await validateWithJWS(productId: productId, jwsRepresentation: jwsRepresentation)
        default:
            return false
        }
    }
    
    /// Validates a transaction using its JWS representation with iaptic.
    /// - Parameters:
    ///   - productId: The product identifier.
    ///   - jwsRepresentation: The JWS representation of the transaction.
    /// - Returns: A boolean indicating whether the validation was successful.
    public func validateWithJWS(productId: String, jwsRepresentation: String) async -> Bool {
        // Create the URL for the iaptic API
        guard let url = URL(string: "\(baseURL)/v1/validate") else {
            print("Invalid URL")
            return false
        }
        
        // Create the request body according to iaptic documentation
        let requestBody: [String: Any] = [
            "id": productId,
            "type": "ios-appstore-sk2",
            "transaction": [
                "id": productId,
                "type": "ios-appstore-sk2",
                "jwsRepresentation": jwsRepresentation
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
                    if let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let ok = responseJSON["ok"] as? Bool {
                        if ok {
                            print("Validation successful: \(responseJSON)")
                            return true
                        } else {
                            print("Validation failed: \(responseJSON)")
                            return false
                        }
                    }
                } else {
                    print("HTTP Error: \(httpResponse.statusCode)")
                    return false
                }
            }
            
            return false
        } catch {
            print("Error validating with iaptic: \(error)")
            return false
        }
    }
    
    // MARK: - Advanced Validation Methods
    
    /// Validates a StoreKit 2 transaction with iaptic and returns the detailed response.
    /// - Parameters:
    ///   - productId: The product identifier.
    ///   - jwsRepresentation: The JWS representation of the transaction.
    /// - Returns: The validation response as a dictionary, or nil if validation failed.
    public func validateWithDetails(productId: String, jwsRepresentation: String) async -> [String: Any]? {
        // Create the URL for the iaptic API
        guard let url = URL(string: "\(baseURL)/v1/validate") else {
            print("Invalid URL")
            return nil
        }
        
        // Create the request body according to iaptic documentation
        let requestBody: [String: Any] = [
            "id": productId,
            "type": "ios-appstore-sk2",
            "transaction": [
                "id": productId,
                "type": "ios-appstore-sk2",
                "jwsRepresentation": jwsRepresentation
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
                    // Parse and return the response
                    if let responseJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        return responseJSON
                    }
                } else {
                    print("HTTP Error: \(httpResponse.statusCode)")
                }
            }
            
            return nil
        } catch {
            print("Error validating with iaptic: \(error)")
            return nil
        }
    }
} 