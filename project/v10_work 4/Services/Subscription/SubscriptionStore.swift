//
//  SubscriptionStore.swift
//  Journal de trading 2025
//
//  Store pour persister le statut d'abonnement localement
//

import Foundation

final class SubscriptionStore {
    static let shared = SubscriptionStore()
    
    private let userDefaults = UserDefaults.standard
    private let premiumStatusKey = "isPremiumUser"
    private let lastCheckKey = "subscriptionLastCheck"
    
    private init() {}
    
    /// Sauvegarde le statut premium localement
    func savePremiumStatus(_ isPremium: Bool) {
        userDefaults.set(isPremium, forKey: premiumStatusKey)
        userDefaults.set(Date(), forKey: lastCheckKey)
    }
    
    /// Charge le statut premium depuis le stockage local
    func loadPremiumStatus() -> Bool {
        return userDefaults.bool(forKey: premiumStatusKey)
    }
    
    /// Retourne la date de la dernière vérification
    func lastCheckDate() -> Date? {
        return userDefaults.object(forKey: lastCheckKey) as? Date
    }
    
    /// Vérifie si une nouvelle vérification est nécessaire (toutes les 24h)
    func shouldCheckAgain() -> Bool {
        guard let lastCheck = lastCheckDate() else {
            return true
        }
        
        let hoursSinceLastCheck = Date().timeIntervalSince(lastCheck) / 3600
        return hoursSinceLastCheck >= 24
    }
    
    /// Réinitialise le statut (pour les tests)
    func reset() {
        userDefaults.removeObject(forKey: premiumStatusKey)
        userDefaults.removeObject(forKey: lastCheckKey)
    }
}


