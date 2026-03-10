//
//  WebhookPayload.swift
//  Journal de trading 2025
//

import Foundation

// MARK: - TradingView Webhook Payload

struct TradingViewWebhookPayload: Codable {
    let symbol: String
    let price: String?
    let message: String
    let severity: String?
    let tags: [String]?
    let payload: [String: AnyCodable]?
    let timestamp: Int64?
    let apiKey: String?
    let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case symbol, price, message, severity, tags, payload, timestamp
        case apiKey = "api_key"
        case userId = "user_id"
    }
}

// MARK: - Webhook Response

struct WebhookResponse: Codable {
    let success: Bool
    let message: String
    let alertId: String?
    let error: String?
    
    init(success: Bool, message: String, alertId: String? = nil, error: String? = nil) {
        self.success = success
        self.message = message
        self.alertId = alertId
        self.error = error
    }
}

// MARK: - Webhook Error

enum WebhookError: Error, LocalizedError {
    case invalidSignature
    case invalidPayload
    case userNotFound
    case storageError(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidSignature:
            return "Signature HMAC invalide"
        case .invalidPayload:
            return "Payload invalide"
        case .userNotFound:
            return "Utilisateur non trouvé"
        case .storageError(let message):
            return "Erreur de stockage: \(message)"
        case .networkError(let message):
            return "Erreur réseau: \(message)"
        }
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = ()
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "AnyCodable value cannot be decoded"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - Webhook Configuration

struct WebhookConfiguration {
    let secretKey: String
    let allowedTimestampSkew: TimeInterval
    let maxPayloadSize: Int
    
    static let `default` = WebhookConfiguration(
        secretKey: "your_webhook_secret_key",
        allowedTimestampSkew: 300, // 5 minutes
        maxPayloadSize: 1024 * 1024 // 1MB
    )
}











