//
//  KeychainManager+TwelveData.swift
//  Journal de trading 2025
//

import Foundation

extension KeychainManager {
    private var twelveDataIdentifier: String { "com.jdt.api.twelvedata" }
    
    func saveTwelveDataKey(_ token: String) -> Bool {
        return save(apiKey: token, secret: "", for: twelveDataIdentifier)
    }
    
    func retrieveTwelveDataKey() -> String? {
        guard let creds = retrieve(for: twelveDataIdentifier) else { return nil }
        if creds.apiKey.isEmpty { return nil }
        return creds.apiKey
    }
    
    func deleteTwelveDataKey() {
        _ = save(apiKey: "", secret: "", for: twelveDataIdentifier)
    }
}
