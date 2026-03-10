import Foundation

final class ChallengeEngine {
    private let store: ChallengeStore?
    private let calendar = Calendar(identifier: .gregorian)
    
    init(store: ChallengeStore?) { self.store = store }
    
    func paris06(of date: Date) -> Date {
        var comps = calendar.dateComponents(in: TimeZone(identifier: "Europe/Paris")!, from: date)
        comps.hour = 6; comps.minute = 0; comps.second = 0
        return calendar.date(from: comps) ?? date
    }
    
    func rollDaily(for date: Date = Date()) async throws -> [Challenge] {
        guard let store = store else { return [] }
        
        let expires = calendar.date(byAdding: .day, value: 1, to: paris06(of: date)) ?? date
        
        // Générer 3 défis quotidiens
        let challenges = [
            Challenge(
                id: UUID().uuidString,
                title: "Discipline Trading",
                description: "Compléter 3 étapes de votre processus",
                type: .daily,
                targetValue: 3,
                currentValue: 0,
                rewardXP: 50,
                isCompleted: false,
                completedAt: nil,
                expiresAt: expires,
                mutators: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            Challenge(
                id: UUID().uuidString,
                title: "Analyse Post-Trade",
                description: "Analyser un trade dans les 24h",
                type: .daily,
                targetValue: 1,
                currentValue: 0,
                rewardXP: 75,
                isCompleted: false,
                completedAt: nil,
                expiresAt: expires,
                mutators: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            Challenge(
                id: UUID().uuidString,
                title: "Streak de Consistance",
                description: "Maintenir votre routine 3 jours consécutifs",
                type: .daily,
                targetValue: 3,
                currentValue: 0,
                rewardXP: 100,
                isCompleted: false,
                completedAt: nil,
                expiresAt: expires,
                mutators: [],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        // Sauvegarder les défis
        for challenge in challenges {
            _ = try await store.createChallenge(challenge)
        }
        
        return challenges
    }
    
    func rollWeekly(for date: Date = Date()) async throws -> [Challenge] {
        guard let store = store else { return [] }
        
        // Lundi 06:00 Europe/Paris (weekday=2)
        let components = DateComponents(hour: 6, weekday: 2)
        let expires = calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents, direction: .forward) ?? date
        
        // Générer 4-6 défis hebdomadaires
        let challenges = [
            Challenge(
                id: UUID().uuidString,
                title: "Playbook Master",
                description: "Rédiger 2 post-mortems détaillés",
                type: .weekly,
                targetValue: 2,
                currentValue: 0,
                rewardXP: 200,
                isCompleted: false,
                completedAt: nil,
                expiresAt: expires,
                mutators: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            Challenge(
                id: UUID().uuidString,
                title: "Focus Symbol",
                description: "Trader uniquement BTC cette semaine",
                type: .weekly,
                targetValue: 5,
                currentValue: 0,
                rewardXP: 150,
                isCompleted: false,
                completedAt: nil,
                expiresAt: expires,
                mutators: [.focusSymbol],
                createdAt: Date(),
                updatedAt: Date()
            ),
            Challenge(
                id: UUID().uuidString,
                title: "Risk Management",
                description: "Respecter le sizing sur 10 trades",
                type: .weekly,
                targetValue: 10,
                currentValue: 0,
                rewardXP: 300,
                isCompleted: false,
                completedAt: nil,
                expiresAt: expires,
                mutators: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            Challenge(
                id: UUID().uuidString,
                title: "Learning Week",
                description: "Consulter 5 analyses de marché",
                type: .weekly,
                targetValue: 5,
                currentValue: 0,
                rewardXP: 100,
                isCompleted: false,
                completedAt: nil,
                expiresAt: expires,
                mutators: [],
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
        
        // Sauvegarder les défis
        for challenge in challenges {
            _ = try await store.createChallenge(challenge)
        }
        
        return challenges
    }
    
    func apply(event: String, to challengeId: String) async throws -> Challenge? {
        guard let store = store else { return nil }
        
        let challenges = try await store.getAllChallenges()
        guard let challenge = challenges.first(where: { $0.id == challengeId }) else {
            return nil
        }
        
        var updatedChallenge = challenge
        updatedChallenge.currentValue = min(updatedChallenge.currentValue + 1, updatedChallenge.targetValue)
        
        // Vérifier si le défi est complété
        if updatedChallenge.currentValue >= updatedChallenge.targetValue && !updatedChallenge.isCompleted {
            updatedChallenge.isCompleted = true
            updatedChallenge.completedAt = Date()
        }
        
        updatedChallenge.updatedAt = Date()
        
        _ = try await store.updateChallenge(updatedChallenge)
        return updatedChallenge
    }
    
    func complete(challengeId: String) async throws -> Challenge? {
        guard let store = store else { return nil }
        
        let challenges = try await store.getAllChallenges()
        guard let challenge = challenges.first(where: { $0.id == challengeId }) else {
            return nil
        }
        
        var updatedChallenge = challenge
        updatedChallenge.isCompleted = true
        updatedChallenge.completedAt = Date()
        updatedChallenge.updatedAt = Date()
        
        _ = try await store.updateChallenge(updatedChallenge)
        return updatedChallenge
    }
    
    func reroll(challengeId: String) async throws -> Challenge? {
        guard let store = store else { return nil }
        
        // Vérifier le nombre de rerolls aujourd'hui
        let today = Calendar.current.startOfDay(for: Date())
        let rerollCount = try await store.getRerollCount(for: today)
        
        // Limite de 1 reroll gratuit par jour (3 si Pro)
        let maxRerolls = 1 // TODO: Ajouter la logique Pro
        
        if rerollCount >= maxRerolls {
            throw ChallengeError.rerollLimitExceeded
        }
        
        // Enregistrer le reroll
        try await store.recordReroll(for: challengeId)
        
        // Supprimer l'ancien défi
        try await store.deleteChallenge(challengeId)
        
        // Créer un nouveau défi (simplifié)
        let newChallenge = Challenge(
            id: UUID().uuidString,
            title: "Nouveau Défi",
            description: "Défi rerollé",
            type: .daily,
            targetValue: 3,
            currentValue: 0,
            rewardXP: 50,
            isCompleted: false,
            completedAt: nil,
            expiresAt: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            mutators: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        _ = try await store.createChallenge(newChallenge)
        return newChallenge
    }
    
    func getDailyChallenges() async throws -> [Challenge] {
        guard let store = store else { return [] }
        return try await store.getDailyChallenges()
    }
    
    func getWeeklyChallenges() async throws -> [Challenge] {
        guard let store = store else { return [] }
        return try await store.getWeeklyChallenges()
    }
}

enum ChallengeError: Error {
    case rerollLimitExceeded
    case challengeNotFound
    case storeNotAvailable
}

