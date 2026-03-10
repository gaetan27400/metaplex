//
//  SharedImageService.swift
//  Journal de trading 2025
//
//  Service pour gérer le partage d'images entre Share Extension et app principale
//

import Foundation
import UIKit

final class SharedImageService {
    static let shared = SharedImageService()
    
    private let appGroupIdentifier = "group.FOUGERAY.Journal-de-trading-2025"
    private let sharedImageKey = "sharedImageData"
    private let sharedImageTimestampKey = "sharedImageTimestamp"
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }
    
    private init() {}
    
    // MARK: - Save Image
    
    func saveSharedImage(_ imageData: Data) {
        guard let defaults = userDefaults else {
            print("❌ [SharedImageService] Failed to access App Group UserDefaults")
            return
        }
        
        defaults.set(imageData, forKey: sharedImageKey)
        defaults.set(Date().timeIntervalSince1970, forKey: sharedImageTimestampKey)
        defaults.synchronize()
        
        print("✅ [SharedImageService] Image saved to App Group (\(imageData.count) bytes)")
    }
    
    // MARK: - Retrieve Image
    
    func retrieveSharedImage() -> Data? {
        guard let defaults = userDefaults else {
            print("❌ [SharedImageService] Failed to access App Group UserDefaults")
            return nil
        }
        
        guard let imageData = defaults.data(forKey: sharedImageKey) else {
            return nil
        }
        
        // Nettoyer après récupération
        clearSharedImage()
        
        print("✅ [SharedImageService] Image retrieved from App Group (\(imageData.count) bytes)")
        return imageData
    }
    
    func retrieveSharedImageAsUIImage() -> UIImage? {
        guard let imageData = retrieveSharedImage() else {
            return nil
        }
        return UIImage(data: imageData)
    }
    
    // MARK: - Check Pending
    
    func hasPendingSharedImage() -> Bool {
        guard let defaults = userDefaults else {
            return false
        }
        
        guard defaults.data(forKey: sharedImageKey) != nil else {
            return false
        }
        
        // Vérifier que l'image n'est pas trop ancienne (max 5 minutes)
        if let timestamp = defaults.double(forKey: sharedImageTimestampKey) as Double? {
            let imageDate = Date(timeIntervalSince1970: timestamp)
            let age = Date().timeIntervalSince(imageDate)
            if age > 300 { // 5 minutes
                clearSharedImage()
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Clear
    
    func clearSharedImage() {
        guard let defaults = userDefaults else {
            return
        }
        
        defaults.removeObject(forKey: sharedImageKey)
        defaults.removeObject(forKey: sharedImageTimestampKey)
        defaults.synchronize()
        
        print("🧹 [SharedImageService] Shared image cleared")
    }
}
