//
//  APICredentials.swift
//  Journal de trading 2025
//

import Foundation

struct APICredentials: Identifiable, Codable {
    let id: UUID
    let exchange: String
    let apiKey: String
    let apiSecret: String
    let isActive: Bool
    let createdAt: Date
    let lastUsed: Date?
    
    init(id: UUID = UUID(),
         exchange: String,
         apiKey: String,
         apiSecret: String,
         isActive: Bool = true,
         createdAt: Date = Date(),
         lastUsed: Date? = nil) {
        self.id = id
        self.exchange = exchange
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastUsed = lastUsed
    }
}









