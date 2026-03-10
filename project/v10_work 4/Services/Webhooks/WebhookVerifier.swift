//
//  WebhookVerifier.swift
//  Journal de trading 2025
//

import Foundation
import CryptoKit

class WebhookVerifier {
    private let configuration: WebhookConfiguration
    
    init(configuration: WebhookConfiguration = .default) {
        self.configuration = configuration
    }
    
    // MARK: - HMAC Verification
    
    func verify(payload: Data, secret: String, signature: String, timestamp: Int64) -> Bool {
        // Check timestamp to prevent replay attacks
        guard isTimestampValid(timestamp) else {
            print("❌ [WebhookVerifier] Invalid timestamp: \(timestamp)")
            return false
        }
        
        // Verify HMAC signature
        let expectedSignature = generateHMACSignature(payload: payload, secret: secret, timestamp: timestamp)
        
        // Use constant time comparison to prevent timing attacks
        let isValid = constantTimeCompare(signature, expectedSignature)
        
        if !isValid {
            print("❌ [WebhookVerifier] Invalid HMAC signature")
            print("Expected: \(expectedSignature)")
            print("Received: \(signature)")
        }
        
        return isValid
    }
    
    func verify(payload: Data, secret: String, signature: String) -> Bool {
        let currentTimestamp = Int64(Date().timeIntervalSince1970)
        return verify(payload: payload, secret: secret, signature: signature, timestamp: currentTimestamp)
    }
    
    // MARK: - Helper Methods
    
    private func isTimestampValid(_ timestamp: Int64) -> Bool {
        let currentTime = Int64(Date().timeIntervalSince1970)
        let timeDifference = abs(currentTime - timestamp)
        
        return timeDifference <= Int64(configuration.allowedTimestampSkew)
    }
    
    private func generateHMACSignature(payload: Data, secret: String, timestamp: Int64) -> String {
        let timestampString = String(timestamp)
        let message = timestampString + String(data: payload, encoding: .utf8)!
        
        let key = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        
        return signature.map { String(format: "%02x", $0) }.joined()
    }
    
    private func constantTimeCompare(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs.count == rhs.count else { return false }
        
        var result: UInt8 = 0
        for (lhsByte, rhsByte) in zip(lhs.utf8, rhs.utf8) {
            result |= lhsByte ^ rhsByte
        }
        
        return result == 0
    }
    
    // MARK: - Payload Validation
    
    func validatePayloadSize(_ data: Data) -> Bool {
        return data.count <= configuration.maxPayloadSize
    }
    
    func validateTradingViewPayload(_ payload: TradingViewWebhookPayload) -> Bool {
        // Validate required fields
        guard !payload.symbol.isEmpty,
              !payload.message.isEmpty else {
            print("❌ [WebhookVerifier] Missing required fields")
            return false
        }
        
        // Validate symbol format (basic check)
        guard payload.symbol.count >= 3,
              payload.symbol.count <= 20 else {
            print("❌ [WebhookVerifier] Invalid symbol format")
            return false
        }
        
        // Validate message length
        guard payload.message.count <= 500 else {
            print("❌ [WebhookVerifier] Message too long")
            return false
        }
        
        // Validate price format if provided
        if let priceString = payload.price,
           !priceString.isEmpty {
            guard let _ = Decimal(string: priceString) else {
                print("❌ [WebhookVerifier] Invalid price format")
                return false
            }
        }
        
        return true
    }
}

// MARK: - Webhook Request Parser

extension WebhookVerifier {
    func parseWebhookRequest(_ requestData: Data) -> (payload: TradingViewWebhookPayload?, signature: String?, timestamp: Int64?) {
        do {
            // Try to parse as JSON
            let json = try JSONSerialization.jsonObject(with: requestData) as? [String: Any]
            
            // Extract signature and timestamp from headers or payload
            let signature = json?["signature"] as? String
            let timestamp = json?["timestamp"] as? Int64 ?? Int64(Date().timeIntervalSince1970)
            
            // Parse payload
            let payload = try? JSONDecoder().decode(TradingViewWebhookPayload.self, from: requestData)
            
            return (payload: payload, signature: signature, timestamp: timestamp)
            
        } catch {
            print("❌ [WebhookVerifier] Error parsing webhook request: \(error)")
            return (payload: nil, signature: nil, timestamp: nil)
        }
    }
}











