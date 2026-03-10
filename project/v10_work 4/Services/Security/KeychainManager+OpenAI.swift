//
//  KeychainManager+OpenAI.swift
//  Journal de trading 2025
//

import Foundation

extension KeychainManager {
    private var openAIIdentifier: String { "openai.api" }
    
    func saveOpenAIKey(_ token: String) -> Bool {
        // We reuse the (apiKey, secret) storage with an empty secret
        return save(apiKey: token, secret: "", for: openAIIdentifier)
    }
    
    func retrieveOpenAIKey() -> String? {
        guard let creds = retrieve(for: openAIIdentifier) else {
            print("❌ [Keychain] No credentials found for OpenAI")
            return nil
        }
        if creds.apiKey.isEmpty {
            print("⚠️ [Keychain] OpenAI API key is empty")
            return nil
        }
        print("✅ [Keychain] OpenAI API key retrieved successfully (length: \(creds.apiKey.count))")
        return creds.apiKey
    }
    
    func deleteOpenAIKey() {
        _ = save(apiKey: "", secret: "", for: openAIIdentifier)
    }
}


