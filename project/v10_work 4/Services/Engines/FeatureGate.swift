import Foundation

final class FeatureGate {
    private let prestigeEngine: PrestigeEngine
    private let isProUser: Bool
    
    init(prestigeEngine: PrestigeEngine, isProUser: Bool = false) {
        self.prestigeEngine = prestigeEngine
        self.isProUser = isProUser
    }
    
    // MARK: - Feature Rules
    
    private let defaultRules: [String: GateRule] = [
        "alertsAdvanced": GateRule(
            minLevel: 12,
            minPrestige: nil,
            requiresBadgeIds: nil,
            requiresEntitlement: nil
        ),
        "analyticsAdvanced": GateRule(
            minLevel: 18,
            minPrestige: nil,
            requiresBadgeIds: ["process_master"],
            requiresEntitlement: nil
        ),
        "playbooksPublic": GateRule(
            minLevel: 20,
            minPrestige: nil,
            requiresBadgeIds: nil,
            requiresEntitlement: nil
        ),
        "squads": GateRule(
            minLevel: 24,
            minPrestige: nil,
            requiresBadgeIds: nil,
            requiresEntitlement: nil
        ),
        "themesPrestige": GateRule(
            minLevel: nil,
            minPrestige: 1,
            requiresBadgeIds: nil,
            requiresEntitlement: nil
        ),
        "multiImport": GateRule(
            minLevel: 16,
            minPrestige: nil,
            requiresBadgeIds: nil,
            requiresEntitlement: nil
        ),
        "exportsAdvanced": GateRule(
            minLevel: 14,
            minPrestige: nil,
            requiresBadgeIds: nil,
            requiresEntitlement: nil
        ),
        "challengeRerolls": GateRule(
            minLevel: nil,
            minPrestige: nil,
            requiresBadgeIds: nil,
            requiresEntitlement: "pro"
        ),
        "xpBoost": GateRule(
            minLevel: nil,
            minPrestige: nil,
            requiresBadgeIds: nil,
            requiresEntitlement: "pro"
        )
    ]
    
    // MARK: - Public Methods
    
    func isFeatureUnlocked(_ featureId: String) async -> Bool {
        // Pro users have instant access to all features
        if isProUser {
            return true
        }
        
        guard let rule = defaultRules[featureId] else {
            // Si pas de règle définie, la fonctionnalité est débloquée par défaut
            return true
        }
        
        do {
            let progression = try await prestigeEngine.getProgression()
            return evaluateRule(rule, with: progression)
        } catch {
            print("Erreur lors de la vérification de la fonctionnalité \(featureId): \(error)")
            return false
        }
    }
    
    func getUnlockRequirement(for featureId: String) async -> UnlockRequirement? {
        guard let rule = defaultRules[featureId] else { return nil }
        
        do {
            let progression = try await prestigeEngine.getProgression()
            return calculateRequirement(rule, currentProgression: progression)
        } catch {
            return nil
        }
    }
    
    func getTimeToUnlock(for featureId: String) async -> String {
        guard let requirement = await getUnlockRequirement(for: featureId) else {
            return "Débloqué"
        }
        
        if requirement.isUnlocked {
            return "Débloqué"
        }
        
        if requirement.canUnlockWithPro {
            return "Débloqué avec Pro"
        }
        
        // Calculer le temps estimé
        if let levelRequirement = requirement.levelRequirement {
            let xpNeeded = calculateXPForLevels(from: requirement.currentLevel, to: levelRequirement)
            
            // Estimation basée sur 50 XP par jour
            let daysToUnlock = max(1, xpNeeded / 50)
            
            if daysToUnlock == 1 {
                return "~1 jour"
            } else if daysToUnlock < 7 {
                return "~\(daysToUnlock) jours"
            } else {
                let weeks = daysToUnlock / 7
                return "~\(weeks) semaine\(weeks > 1 ? "s" : "")"
            }
        }
        
        if let prestigeRequirement = requirement.prestigeRequirement {
            let prestigeToGo = prestigeRequirement - requirement.currentPrestige
            return "Prestige \(prestigeToGo) niveau\(prestigeToGo > 1 ? "x" : "")"
        }
        
        if let badgeRequirement = requirement.badgeRequirement {
            let badgesToGo = badgeRequirement.count
            return "\(badgesToGo) badge\(badgesToGo > 1 ? "s" : "") requis"
        }
        
        return "Non débloqué"
    }
    
    // MARK: - Private Methods
    
    private func evaluateRule(_ rule: GateRule, with progression: Progression) -> Bool {
        // Vérifier le niveau minimum
        if let minLevel = rule.minLevel, progression.level < minLevel {
            return false
        }
        
        // Vérifier le prestige minimum
        if let minPrestige = rule.minPrestige, progression.prestige < minPrestige {
            return false
        }
        
        // Vérifier les badges requis
        if let requiredBadges = rule.requiresBadgeIds, !requiredBadges.isEmpty {
            // TODO: Vérifier si l'utilisateur a les badges requis
            // Pour l'instant, on simule avec des badges factices
            return false
        }
        
        // Vérifier l'entitlement Pro
        if let entitlement = rule.requiresEntitlement, entitlement == "pro" {
            return isProUser
        }
        
        return true
    }
    
    private func calculateRequirement(_ rule: GateRule, currentProgression: Progression) -> UnlockRequirement {
        var requirement = UnlockRequirement(
            isUnlocked: true,
            canUnlockWithPro: rule.requiresEntitlement == "pro",
            currentLevel: currentProgression.level,
            currentPrestige: currentProgression.prestige,
            levelRequirement: nil,
            prestigeRequirement: nil,
            badgeRequirement: nil
        )
        
        // Vérifier le niveau
        if let minLevel = rule.minLevel, currentProgression.level < minLevel {
            requirement.isUnlocked = false
            requirement.levelRequirement = minLevel
        }
        
        // Vérifier le prestige
        if let minPrestige = rule.minPrestige, currentProgression.prestige < minPrestige {
            requirement.isUnlocked = false
            requirement.prestigeRequirement = minPrestige
        }
        
        // Vérifier les badges
        if let requiredBadges = rule.requiresBadgeIds, !requiredBadges.isEmpty {
            requirement.isUnlocked = false
            requirement.badgeRequirement = requiredBadges
        }
        
        // Vérifier l'entitlement Pro
        if let entitlement = rule.requiresEntitlement, entitlement == "pro" && !isProUser {
            requirement.isUnlocked = false
        }
        
        return requirement
    }
    
    private func calculateXPForLevels(from startLevel: Int, to endLevel: Int) -> Int {
        var totalXP = 0
        for level in startLevel..<endLevel {
            totalXP += max(100, 100 + (level - 1) * 20)
        }
        return totalXP
    }
}

// MARK: - Models

struct GateRule {
    let minLevel: Int?
    let minPrestige: Int?
    let requiresBadgeIds: [String]?
    let requiresEntitlement: String?
}

struct UnlockRequirement {
    var isUnlocked: Bool
    let canUnlockWithPro: Bool
    let currentLevel: Int
    let currentPrestige: Int
    var levelRequirement: Int?
    var prestigeRequirement: Int?
    var badgeRequirement: [String]?
}

// MARK: - Feature IDs

enum FeatureID: String, CaseIterable {
    case alertsAdvanced = "alertsAdvanced"
    case analyticsAdvanced = "analyticsAdvanced"
    case playbooksPublic = "playbooksPublic"
    case squads = "squads"
    case themesPrestige = "themesPrestige"
    case multiImport = "multiImport"
    case exportsAdvanced = "exportsAdvanced"
    case challengeRerolls = "challengeRerolls"
    case xpBoost = "xpBoost"
    
    var displayName: String {
        switch self {
        case .alertsAdvanced: return "Alertes avancées"
        case .analyticsAdvanced: return "Analyses avancées"
        case .playbooksPublic: return "Playbooks publics"
        case .squads: return "Équipes"
        case .themesPrestige: return "Thèmes prestige"
        case .multiImport: return "Import multiple"
        case .exportsAdvanced: return "Exports avancés"
        case .challengeRerolls: return "Rerolls de défis"
        case .xpBoost: return "Boost XP"
        }
    }
    
    var description: String {
        switch self {
        case .alertsAdvanced: return "Filtres avancés et alertes personnalisées"
        case .analyticsAdvanced: return "Statistiques détaillées et insights"
        case .playbooksPublic: return "Partager vos playbooks avec la communauté"
        case .squads: return "Créer et rejoindre des équipes de traders"
        case .themesPrestige: return "Thèmes exclusifs pour utilisateurs prestige"
        case .multiImport: return "Importer depuis plusieurs exchanges simultanément"
        case .exportsAdvanced: return "Exports personnalisés et rapports PDF"
        case .challengeRerolls: return "Plus de rerolls pour personnaliser vos défis"
        case .xpBoost: return "Bonus XP sur tous les événements de processus"
        }
    }
}
