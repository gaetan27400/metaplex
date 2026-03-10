//
//  KeychainManager+Finnhub.swift
//  Journal de trading 2025
//

import Foundation

extension KeychainManager {
    private var finnhubIdentifier: String { "com.jdt.api.finnhub" }
    
    func saveFinnhubKey(_ token: String) -> Bool {
        return save(apiKey: token, secret: "", for: finnhubIdentifier)
    }
    
    func retrieveFinnhubKey() -> String? {
        guard let creds = retrieve(for: finnhubIdentifier) else { return nil }
        if creds.apiKey.isEmpty { return nil }
        return creds.apiKey
    }
    
    func deleteFinnhubKey() {
        _ = save(apiKey: "", secret: "", for: finnhubIdentifier)
    }
}
