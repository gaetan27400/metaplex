import Foundation

struct Progression: Codable, Equatable {
    let id: Int
    var level: Int        // 1..50
    var xpInLevel: Int    // 0..levelThreshold(level)-1
    var prestige: Int     // 0..10
    var dailyXP: Int      // XP gagné aujourd'hui
    var totalXP: Int      // XP total gagné
    var xpRequiredForNextLevel: Int
    var lastXPReset: Date
    var lastPrestigeDate: Date?
    var createdAt: Date
    var updatedAt: Date
    
    static let maxLevel = 50
}

struct Badge: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let rarity: BadgeRarity
    let unlockedAt: Date?
    let createdAt: Date
    let updatedAt: Date
}

enum BadgeRarity: String, Codable, CaseIterable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
}

struct Challenge: Identifiable, Codable, Hashable {
    enum ChallengeType: String, Codable { 
        case daily = "daily"
        case weekly = "weekly"
    }
    
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    let targetValue: Int
    var currentValue: Int
    let rewardXP: Int
    var isCompleted: Bool
    var completedAt: Date?
    let expiresAt: Date
    let mutators: [ChallengeMutator]
    let createdAt: Date
    var updatedAt: Date
}

enum ChallengeMutator: String, Codable, CaseIterable {
    case focusSymbol = "focusSymbol"
    case riskManagement = "riskManagement"
    case discipline = "discipline"
    case learning = "learning"
}

struct XPEvent: Identifiable, Codable {
    let id: String
    let type: XPEventType
    let amount: Int
    let description: String
    let metadata: [String: String]
    let createdAt: Date
}

enum XPEventType: String, Codable, CaseIterable {
    case checklist = "checklist"
    case postMortem = "postMortem"
    case discipline = "discipline"
    case playbook = "playbook"
    case referral = "referral"
    case social = "social" // Nouveau: Pour les clics sur liens sociaux
}

