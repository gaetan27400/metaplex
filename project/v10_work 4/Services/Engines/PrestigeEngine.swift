import Foundation

final class PrestigeEngine {
    private let store: PrestigeStore?
    private let dailyCap: Int = 1000
    
    init(store: PrestigeStore?) { self.store = store }
    
    func levelThreshold(_ level: Int) -> Int { max(100, 100 + (level - 1) * 20) }
    
    func apply(event: XPEvent, boosts: [XPBoostEvent] = []) async throws -> Progression {
        guard let store = store else {
            // Si pas de store, retourner une progression par défaut
            return Progression(
                id: 1,
                level: 1,
                xpInLevel: 0,
                prestige: 0,
                dailyXP: 0,
                totalXP: 0,
                xpRequiredForNextLevel: 100,
                lastXPReset: Date(),
                lastPrestigeDate: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        var progression = try await store.getProgression()
        
        // Enregistrer l'événement XP (on ignore la valeur de retour)
        _ = try await store.createXPEvent(event)
        
        // Appliquer les boosts
        var gain = event.amount
        if let bestBoost = boosts.max(by: { $0.multiplier < $1.multiplier }) {
            gain = Int(Double(gain) * bestBoost.multiplier)
        }
        
        // Vérifier le plafond quotidien
        let today = Calendar.current.startOfDay(for: Date())
        if progression.lastXPReset < today {
            progression.dailyXP = 0
            progression.lastXPReset = today
        }
        
        if progression.dailyXP + gain > dailyCap {
            gain = max(0, dailyCap - progression.dailyXP)
        }
        
        if gain <= 0 { return progression }
        
        // Mettre à jour la progression
        progression.dailyXP += gain
        progression.totalXP += gain
        
        let newXP = progression.xpInLevel + gain
        var level = progression.level
        var xp = newXP
        let maxLevel = 50
        
        // Calculer les niveaux
        while xp >= levelThreshold(level) && level < maxLevel {
            xp -= levelThreshold(level)
            level += 1
        }
        
        progression.level = level
        progression.xpInLevel = xp
        progression.xpRequiredForNextLevel = levelThreshold(level)
        progression.updatedAt = Date()
        
        // Sauvegarder
        _ = try await store.updateProgression(progression)
        return progression
    }
    
    func prestige() async throws -> Progression {
        guard let store = store else {
            return Progression(
                id: 1,
                level: 1,
                xpInLevel: 0,
                prestige: 0,
                dailyXP: 0,
                totalXP: 0,
                xpRequiredForNextLevel: 100,
                lastXPReset: Date(),
                lastPrestigeDate: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        var progression = try await store.getProgression()
        
        // Vérifier si l'utilisateur peut faire du prestige (niveau 50)
        if progression.level < 50 {
            throw PrestigeError.insufficientLevel
        }
        
        progression.prestige += 1
        progression.level = 1
        progression.xpInLevel = 0
        progression.xpRequiredForNextLevel = levelThreshold(1)
        progression.lastPrestigeDate = Date()
        progression.updatedAt = Date()
        
        _ = try await store.updateProgression(progression)
        return progression
    }
    
    func getProgression() async throws -> Progression {
        guard let store = store else {
            return Progression(
                id: 1,
                level: 1,
                xpInLevel: 0,
                prestige: 0,
                dailyXP: 0,
                totalXP: 0,
                xpRequiredForNextLevel: 100,
                lastXPReset: Date(),
                lastPrestigeDate: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        
        return try await store.getProgression()
    }
}

enum PrestigeError: Error {
    case insufficientLevel
    case dailyCapReached
    case storeNotAvailable
}

