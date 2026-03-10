//
//  BadgeService.swift
//  Journal de trading 2025
//
//  Service de gestion des badges - Récompense les bonnes pratiques de trading
//

import Foundation

final class BadgeService {
    private let store: PrestigeStore?
    
    init(store: PrestigeStore?) {
        self.store = store
    }
    
    // MARK: - Vérification des badges
    
    /// Vérifie et débloque les badges pertinents après un événement
    func checkAndUnlockBadges(
        trades: [Trade],
        moodEntries: [MoodEntry],
        progression: Progression,
        xpEvents: [XPEvent],
        challenges: [Challenge],
        appState: AppState? = nil
    ) async throws -> [Badge] {
        guard let store = store else { return [] }
        
        let existingBadges = try await store.getBadges()
        var newlyUnlocked: [Badge] = []
        
        // Vérifier chaque badge potentiel
        for badgeDefinition in BadgeDefinitions.all {
            // Ignorer si déjà débloqué
            if existingBadges.contains(where: { $0.id == badgeDefinition.id && $0.unlockedAt != nil }) {
                continue
            }
            
            // Vérifier si le critère est rempli
            if await evaluateBadgeCriteria(
                badgeDefinition,
                trades: trades,
                moodEntries: moodEntries,
                progression: progression,
                xpEvents: xpEvents,
                challenges: challenges,
                appState: appState
            ) {
                // Créer ou mettre à jour le badge
                let badge = Badge(
                    id: badgeDefinition.id,
                    name: badgeDefinition.name,
                    description: badgeDefinition.description,
                    icon: badgeDefinition.icon,
                    rarity: badgeDefinition.rarity,
                    unlockedAt: Date(),
                    createdAt: existingBadges.first(where: { $0.id == badgeDefinition.id })?.createdAt ?? Date(),
                    updatedAt: Date()
                )
                
                _ = try await store.updateBadge(badge)
                newlyUnlocked.append(badge)
            } else {
                // Créer le badge verrouillé s'il n'existe pas
                if !existingBadges.contains(where: { $0.id == badgeDefinition.id }) {
                    let lockedBadge = Badge(
                        id: badgeDefinition.id,
                        name: badgeDefinition.name,
                        description: badgeDefinition.description,
                        icon: badgeDefinition.icon,
                        rarity: badgeDefinition.rarity,
                        unlockedAt: nil,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                    _ = try await store.createBadge(lockedBadge)
                }
            }
        }
        
        return newlyUnlocked
    }
    
    // MARK: - Évaluation des critères
    
    private func evaluateBadgeCriteria(
        _ definition: BadgeDefinition,
        trades: [Trade],
        moodEntries: [MoodEntry],
        progression: Progression,
        xpEvents: [XPEvent],
        challenges: [Challenge],
        appState: AppState?
    ) async -> Bool {
        
        // Helper pour obtenir le PnL d'un trade
        func getTradePnL(_ trade: Trade) -> Double {
            if let flashPnL = trade.flashPnLNet {
                return flashPnL
            } else if let appState = appState, let pnl = appState.netPnL(for: trade) {
                return pnl
            } else {
                return trade.pnl // Utilise la computed property
            }
        }
        switch definition.criteria {
        // MARK: - Milestones & Progression
        case .firstTrade:
            return trades.count >= 1
            
        case .firstWin:
            return trades.contains { getTradePnL($0) > 0 }
            
        case .firstLoss:
            return trades.contains { getTradePnL($0) < 0 }
            
        case .levelReached(let level):
            return progression.level >= level
            
        case .prestigeReached(let prestige):
            return progression.prestige >= prestige
            
        case .totalXP(let xp):
            return progression.totalXP >= xp
            
        case .totalTrades(let count):
            return trades.count >= count
            
        // MARK: - Discipline & Risk Management
        case .stopLossRespected(let count):
            // Pour ce badge, on considère qu'un trade a respecté le stop-loss si :
            // - Il a un PnL positif OU
            // - Il a un PnL négatif mais raisonnable (pas de perte excessive)
            // Note: Comme Trade n'a pas de stopLoss/takeProfit, on utilise une heuristique
            let tradesWithSL = trades.filter { trade in
                let pnl = getTradePnL(trade)
                // Si le trade est gagnant, le stop-loss a été respecté
                if pnl >= 0 { return true }
                // Si le trade est perdant mais avec une perte raisonnable (< 10% de la valeur)
                if let entry = trade.entryPrice, let qty = trade.quantity {
                    let tradeValue = entry * qty
                    let lossPercentage = abs(pnl) / tradeValue * 100
                    return lossPercentage <= 10 // Perte max de 10% = stop-loss implicite respecté
                }
                return false
            }
            return tradesWithSL.count >= count
            
        case .riskRewardRatio(let ratio, let count):
            // Pour ce badge, on vérifie que les trades gagnants ont un meilleur ratio que les perdants
            // Heuristique: si le PnL positif moyen est >= ratio * PnL négatif moyen
            let winningTrades = trades.filter { getTradePnL($0) > 0 }
            let losingTrades = trades.filter { getTradePnL($0) < 0 }
            
            guard !winningTrades.isEmpty && !losingTrades.isEmpty else { return false }
            
            _ = winningTrades.reduce(0.0) { $0 + getTradePnL($1) } / Double(winningTrades.count)
            let avgLoss = abs(losingTrades.reduce(0.0) { $0 + getTradePnL($1) } / Double(losingTrades.count))
            
            guard avgLoss > 0 else { return false }
            
            // On compte les trades qui respectent individuellement le ratio
            let validTrades = trades.filter { trade in
                let pnl = getTradePnL(trade)
                if pnl > 0 {
                    // Pour un trade gagnant, on vérifie qu'il est au moins ratio fois meilleur que la perte moyenne
                    return pnl >= avgLoss * ratio
                }
                return true // Les trades perdants sont acceptés
            }
            return validTrades.count >= count
            
        case .positionSizing(let count):
            // Trades avec sizing cohérent (quantité * prix d'entrée raisonnable)
            // On considère qu'un sizing est cohérent si la valeur du trade est > 0
            let validTrades = trades.filter { trade in
                guard let qty = trade.quantity, let entry = trade.entryPrice else { return false }
                let tradeValue = qty * entry
                return tradeValue > 0 && tradeValue < 1_000_000 // Limite raisonnable
            }
            return validTrades.count >= count
            
        case .maxDrawdown(let maxPercent):
            // Calculer le drawdown maximum
            guard !trades.isEmpty else { return false }
            let sortedTrades = trades.sorted(by: { $0.date < $1.date })
            var peak = 0.0
            var maxDrawdown = 0.0
            var cumulativePnL = 0.0
            
            for trade in sortedTrades {
                cumulativePnL += getTradePnL(trade)
                if cumulativePnL > peak {
                    peak = cumulativePnL
                }
                let drawdown = peak > 0 ? (peak - cumulativePnL) / peak * 100 : 0
                maxDrawdown = max(maxDrawdown, drawdown)
            }
            return maxDrawdown <= maxPercent
            
        // MARK: - Consistance & Routine
        case .tradesInRow(let days):
            // Trader consécutivement pendant X jours
            let calendar = Calendar.current
            var consecutiveDays = 0
            var currentDate = Date()
            
            for _ in 0..<365 { // Max 1 an en arrière
                let dayStart = calendar.startOfDay(for: currentDate)
                let hasTrade = trades.contains { trade in
                    calendar.isDate(trade.date, inSameDayAs: dayStart)
                }
                
                if hasTrade {
                    consecutiveDays += 1
                    if consecutiveDays >= days { return true }
                } else {
                    consecutiveDays = 0
                }
                
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            }
            return false
            
        case .journalEntries(let count):
            return moodEntries.count >= count
            
        case .weeklyConsistency(let weeks):
            // Trader au moins 1 fois par semaine pendant X semaines
            let calendar = Calendar.current
            var consecutiveWeeks = 0
            var currentDate = Date()
            
            for _ in 0..<52 { // Max 1 an
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                
                let hasTrade = trades.contains { trade in
                    trade.date >= weekStart && trade.date < weekEnd
                }
                
                if hasTrade {
                    consecutiveWeeks += 1
                    if consecutiveWeeks >= weeks { return true }
                } else {
                    consecutiveWeeks = 0
                }
                
                guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) else { break }
                currentDate = previousWeek
            }
            return false
            
        case .monthlyConsistency(let months, let minTradesPerMonth):
            // Trader au moins X fois par mois pendant Y mois
            let calendar = Calendar.current
            var consecutiveMonths = 0
            var currentDate = Date()
            
            for _ in 0..<12 { // Max 1 an
                let monthStart = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                
                let monthTrades = trades.filter { trade in
                    trade.date >= monthStart && trade.date < monthEnd
                }
                
                if monthTrades.count >= minTradesPerMonth {
                    consecutiveMonths += 1
                    if consecutiveMonths >= months { return true }
                } else {
                    consecutiveMonths = 0
                }
                
                guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentDate) else { break }
                currentDate = previousMonth
            }
            return false
            
        // MARK: - Apprentissage & Analyse
        case .postMortems(let count):
            let postMortemEvents = xpEvents.filter { $0.type == .postMortem }
            return postMortemEvents.count >= count
            
        case .checklists(let count):
            let checklistEvents = xpEvents.filter { $0.type == .checklist }
            return checklistEvents.count >= count
            
        case .playbooks(let count):
            let playbookEvents = xpEvents.filter { $0.type == .playbook }
            return playbookEvents.count >= count
            
        // MARK: - Performance & Maîtrise
        case .winRate(let rate, let minTrades):
            guard trades.count >= minTrades else { return false }
            let wins = trades.filter { getTradePnL($0) > 0 }.count
            let winRate = Double(wins) / Double(trades.count) * 100
            return winRate >= rate
            
        case .totalProfit(let amount):
            let totalPnL = trades.reduce(0.0) { $0 + getTradePnL($1) }
            return totalPnL >= amount
            
        case .bestStreak(let wins):
            var currentStreak = 0
            var maxStreak = 0
            
            for trade in trades.sorted(by: { $0.date < $1.date }) {
                if getTradePnL(trade) > 0 {
                    currentStreak += 1
                    maxStreak = max(maxStreak, currentStreak)
                } else {
                    currentStreak = 0
                }
            }
            return maxStreak >= wins
            
        case .systemMastery(let systemName, let requiredTrades):
            // Trouver le système par nom dans appState
            guard let appState = appState else { return false }
            guard let system = appState.systems.first(where: { $0.name == systemName }) else { return false }
            let systemTrades = trades.filter { $0.systemId == system.id }
            return systemTrades.count >= requiredTrades
            
        case .averageWin(let minAmount, let minTrades):
            let winningTrades = trades.filter { getTradePnL($0) > 0 }
            guard winningTrades.count >= minTrades else { return false }
            let avgWin = winningTrades.reduce(0.0) { $0 + getTradePnL($1) } / Double(winningTrades.count)
            return avgWin >= minAmount
            
        case .singleTradeProfit(let amount):
            return trades.contains { getTradePnL($0) >= amount }
            
        case .perfectDay(let minTrades):
            let calendar = Calendar.current
            let groupedByDay = Dictionary(grouping: trades) { trade in
                calendar.startOfDay(for: trade.date)
            }
            return groupedByDay.values.contains { dayTrades in
                dayTrades.count >= minTrades && dayTrades.allSatisfy { getTradePnL($0) > 0 }
            }
            
        case .perfectWeek(let minTrades):
            let calendar = Calendar.current
            let groupedByWeek = Dictionary(grouping: trades) { trade in
                calendar.dateInterval(of: .weekOfYear, for: trade.date)?.start ?? trade.date
            }
            return groupedByWeek.values.contains { weekTrades in
                weekTrades.count >= minTrades && weekTrades.allSatisfy { getTradePnL($0) > 0 }
            }
            
        case .zeroLossDay(let minTrades):
            let calendar = Calendar.current
            let groupedByDay = Dictionary(grouping: trades) { trade in
                calendar.startOfDay(for: trade.date)
            }
            return groupedByDay.values.contains { dayTrades in
                dayTrades.count >= minTrades && !dayTrades.contains { getTradePnL($0) < 0 }
            }
            
        case .zeroLossWeek(let minTrades):
            let calendar = Calendar.current
            let groupedByWeek = Dictionary(grouping: trades) { trade in
                calendar.dateInterval(of: .weekOfYear, for: trade.date)?.start ?? trade.date
            }
            return groupedByWeek.values.contains { weekTrades in
                weekTrades.count >= minTrades && !weekTrades.contains { getTradePnL($0) < 0 }
            }
            
        // MARK: - Résilience & Émotions
        case .comeback(let losses, let wins):
            // Perdre X trades puis gagner Y trades consécutifs
            var lossCount = 0
            var winCount = 0
            var foundLosses = false
            
            for trade in trades.sorted(by: { $0.date < $1.date }) {
                let pnl = getTradePnL(trade)
                if pnl < 0 {
                    if !foundLosses {
                        lossCount += 1
                        if lossCount >= losses {
                            foundLosses = true
                        }
                    } else {
                        // Après les pertes, on compte les gains
                        if pnl > 0 {
                            winCount += 1
                            if winCount >= wins { return true }
                        } else {
                            winCount = 0
                        }
                    }
                } else if foundLosses {
                    winCount += 1
                    if winCount >= wins { return true }
                } else {
                    lossCount = 0
                }
            }
            return false
            
        case .emotionalStability(let days):
            // Entrées d'humeur consécutives pendant X jours
            let calendar = Calendar.current
            var consecutiveDays = 0
            var currentDate = Date()
            
            for _ in 0..<365 {
                let dayStart = calendar.startOfDay(for: currentDate)
            let hasEntry = moodEntries.contains { entry in
                calendar.isDate(entry.timestamp, inSameDayAs: dayStart)
            }
                
                if hasEntry {
                    consecutiveDays += 1
                    if consecutiveDays >= days { return true }
                } else {
                    consecutiveDays = 0
                }
                
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            }
            return false
            
        // MARK: - Défis
        case .challengesCompleted(let count):
            let completed = challenges.filter { $0.isCompleted }
            return completed.count >= count
            
        case .dailyChallengesStreak(let days):
            // Compléter un défi quotidien consécutivement
            let calendar = Calendar.current
            var consecutiveDays = 0
            var currentDate = Date()
            
            for _ in 0..<365 {
                let dayStart = calendar.startOfDay(for: currentDate)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                
                let dayChallenges = challenges.filter { challenge in
                    challenge.type == .daily &&
                    challenge.isCompleted &&
                    challenge.completedAt != nil &&
                    challenge.completedAt! >= dayStart &&
                    challenge.completedAt! < dayEnd
                }
                
                if !dayChallenges.isEmpty {
                    consecutiveDays += 1
                    if consecutiveDays >= days { return true }
                } else {
                    consecutiveDays = 0
                }
                
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            }
            return false
            
        case .recovery(let losses):
            // Récupérer après N pertes consécutives (gagner au moins 1 trade après)
            var lossCount = 0
            var foundRecovery = false
            
            for trade in trades.sorted(by: { $0.date < $1.date }) {
                let pnl = getTradePnL(trade)
                if pnl < 0 {
                    lossCount += 1
                    if lossCount >= losses {
                        foundRecovery = true
                    }
                } else if pnl > 0 && foundRecovery {
                    return true
                } else {
                    lossCount = 0
                }
            }
            return false
            
        case .weeklyChallengesStreak(let weeks):
            let calendar = Calendar.current
            var consecutiveWeeks = 0
            var currentDate = Date()
            
            for _ in 0..<52 {
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: currentDate)?.start ?? currentDate
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                
                let weekChallenges = challenges.filter { challenge in
                    challenge.type == .weekly &&
                    challenge.isCompleted &&
                    challenge.completedAt != nil &&
                    challenge.completedAt! >= weekStart &&
                    challenge.completedAt! < weekEnd
                }
                
                if !weekChallenges.isEmpty {
                    consecutiveWeeks += 1
                    if consecutiveWeeks >= weeks { return true }
                } else {
                    consecutiveWeeks = 0
                }
                
                guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) else { break }
                currentDate = previousWeek
            }
            return false
            
        // MARK: - Spécialités
        case .multipleSystems(let count):
            guard let appState = appState else { return false }
            let uniqueSystems = Set<String>(trades.compactMap { trade in
                guard let system = appState.systems.first(where: { $0.id == trade.systemId }) else { return nil }
                return system.name
            })
            return uniqueSystems.count >= count
            
        case .symbolMastery(let symbol, let count):
            let symbolTrades = trades.filter { $0.symbol.uppercased() == symbol.uppercased() }
            return symbolTrades.count >= count
            
        case .multipleSymbols(let count):
            let uniqueSymbols = Set(trades.map { $0.symbol.uppercased() })
            return uniqueSymbols.count >= count
            
        // MARK: - Réseaux sociaux
        case .socialLinkClicked(let platform):
            // Vérifier si l'utilisateur a cliqué sur le lien de cette plateforme
            // Stocké dans UserDefaults ou un store simple
            let key = "social_link_clicked_\(platform.rawValue)"
            return UserDefaults.standard.bool(forKey: key)
            
        case .multipleSocialLinks(let count):
            // Compter le nombre de liens sociaux cliqués
            var clickedCount = 0
            for platform in SocialPlatform.allCases {
                let key = "social_link_clicked_\(platform.rawValue)"
                if UserDefaults.standard.bool(forKey: key) {
                    clickedCount += 1
                }
            }
            return clickedCount >= count
            
        case .referralCount(let count):
            // Compter les événements de type referral
            let referralEvents = xpEvents.filter { $0.type == .referral }
            return referralEvents.count >= count
            
        case .communityContribution(let count):
            // Compter les contributions (posts, commentaires, etc.)
            // Nécessite un système de tracking des contributions
            // Pour l'instant, on peut utiliser les événements XP avec metadata
            let contributionEvents = xpEvents.filter { event in
                event.metadata["type"] == "community_contribution"
            }
            return contributionEvents.count >= count
        }
    }
}

// MARK: - Définitions des badges

struct BadgeDefinition {
    let id: String
    let name: String
    let description: String
    let icon: String
    let rarity: BadgeRarity
    let criteria: BadgeCriteria
}

enum BadgeCriteria {
    // Milestones
    case firstTrade
    case firstWin
    case firstLoss
    case levelReached(Int)
    case prestigeReached(Int)
    case totalXP(Int)
    case totalTrades(Int) // Nouveau
    
    // Discipline & Risk Management
    case stopLossRespected(Int) // Nombre de trades avec stop-loss respecté
    case riskRewardRatio(Double, Int) // Ratio minimum, nombre de trades
    case positionSizing(Int) // Nombre de trades avec sizing cohérent
    case maxDrawdown(Double) // Nouveau: Drawdown maximum en pourcentage
    
    // Consistance
    case tradesInRow(Int) // Jours consécutifs
    case journalEntries(Int) // Nombre d'entrées
    case weeklyConsistency(Int) // Semaines consécutives
    case monthlyConsistency(Int, Int) // Nouveau: Mois consécutifs, minimum de trades par mois
    
    // Apprentissage
    case postMortems(Int)
    case checklists(Int)
    case playbooks(Int)
    
    // Performance
    case winRate(Double, Int) // Pourcentage, minimum de trades
    case totalProfit(Double)
    case bestStreak(Int) // Victoires consécutives
    case systemMastery(String, Int) // Nom de système, nombre de trades
    case averageWin(Double, Int) // Nouveau: Gain moyen minimum, nombre de trades
    case singleTradeProfit(Double) // Nouveau: Profit d'un seul trade
    case perfectDay(Int) // Nouveau: Tous les trades gagnants dans une journée
    case perfectWeek(Int) // Nouveau: Tous les trades gagnants dans une semaine
    case zeroLossDay(Int) // Nouveau: Aucune perte dans une journée
    case zeroLossWeek(Int) // Nouveau: Aucune perte dans une semaine
    
    // Résilience
    case comeback(Int, Int) // Pertes puis victoires consécutives
    case emotionalStability(Int) // Jours consécutifs d'entrées d'humeur
    case recovery(Int) // Nouveau: Récupérer après N pertes consécutives
    
    // Défis
    case challengesCompleted(Int)
    case dailyChallengesStreak(Int) // Jours consécutifs
    case weeklyChallengesStreak(Int) // Nouveau: Semaines consécutives
    
    // Spécialités
    case multipleSystems(Int) // Nouveau: Nombre de systèmes différents utilisés
    case symbolMastery(String, Int) // Nouveau: Nom du symbole, nombre de trades
    case multipleSymbols(Int) // Nouveau: Nombre de symboles différents tradés
    
    // Réseaux sociaux
    case socialLinkClicked(SocialPlatform) // Nouveau: Clic sur un lien social
    case multipleSocialLinks(Int) // Nouveau: Nombre de liens sociaux cliqués
    case referralCount(Int) // Nouveau: Nombre de parrainages réussis
    case communityContribution(Int) // Nouveau: Contributions à la communauté
}

// SocialPlatform est défini dans Models/Domain/SocialVerification.swift

struct BadgeDefinitions {
    static let all: [BadgeDefinition] = [
        // MARK: - Milestones (Common)
        BadgeDefinition(
            id: "first_trade",
            name: "Premier Pas",
            description: "Effectuer votre premier trade",
            icon: "1.circle.fill",
            rarity: .common,
            criteria: .firstTrade
        ),
        BadgeDefinition(
            id: "first_win",
            name: "Première Victoire",
            description: "Réaliser votre premier trade gagnant",
            icon: "checkmark.circle.fill",
            rarity: .common,
            criteria: .firstWin
        ),
        BadgeDefinition(
            id: "first_loss",
            name: "Leçon Apprise",
            description: "Vivre votre première perte (c'est normal !)",
            icon: "xmark.circle.fill",
            rarity: .common,
            criteria: .firstLoss
        ),
        BadgeDefinition(
            id: "level_5",
            name: "Apprenti Trader",
            description: "Atteindre le niveau 5",
            icon: "5.circle.fill",
            rarity: .common,
            criteria: .levelReached(5)
        ),
        BadgeDefinition(
            id: "level_10",
            name: "Trader Confirmé",
            description: "Atteindre le niveau 10",
            icon: "10.circle.fill",
            rarity: .common,
            criteria: .levelReached(10)
        ),
        BadgeDefinition(
            id: "level_25",
            name: "Trader Expérimenté",
            description: "Atteindre le niveau 25",
            icon: "25.circle.fill",
            rarity: .rare,
            criteria: .levelReached(25)
        ),
        BadgeDefinition(
            id: "level_50",
            name: "Maître Trader",
            description: "Atteindre le niveau 50",
            icon: "50.circle.fill",
            rarity: .epic,
            criteria: .levelReached(50)
        ),
        BadgeDefinition(
            id: "prestige_1",
            name: "Prestige I",
            description: "Atteindre le premier prestige",
            icon: "star.fill",
            rarity: .epic,
            criteria: .prestigeReached(1)
        ),
        BadgeDefinition(
            id: "prestige_5",
            name: "Prestige V",
            description: "Atteindre le prestige 5",
            icon: "star.circle.fill",
            rarity: .legendary,
            criteria: .prestigeReached(5)
        ),
        BadgeDefinition(
            id: "xp_1000",
            name: "Mille Points",
            description: "Gagner 1000 XP au total",
            icon: "star.fill",
            rarity: .common,
            criteria: .totalXP(1000)
        ),
        BadgeDefinition(
            id: "xp_10000",
            name: "Dix Mille Points",
            description: "Gagner 10000 XP au total",
            icon: "star.circle.fill",
            rarity: .rare,
            criteria: .totalXP(10000)
        ),
        
        // MARK: - Discipline & Risk Management (Rare/Epic)
        BadgeDefinition(
            id: "stop_loss_10",
            name: "Protection Active",
            description: "Respecter un stop-loss sur 10 trades",
            icon: "shield.fill",
            rarity: .rare,
            criteria: .stopLossRespected(10)
        ),
        BadgeDefinition(
            id: "stop_loss_50",
            name: "Bouclier Infaillible",
            description: "Respecter un stop-loss sur 50 trades",
            icon: "shield.circle.fill",
            rarity: .epic,
            criteria: .stopLossRespected(50)
        ),
        BadgeDefinition(
            id: "risk_reward_2",
            name: "Ratio Optimal",
            description: "10 trades avec un ratio risk/reward ≥ 2:1",
            icon: "arrow.up.arrow.down.circle.fill",
            rarity: .rare,
            criteria: .riskRewardRatio(2.0, 10)
        ),
        BadgeDefinition(
            id: "risk_reward_3",
            name: "Maître du Ratio",
            description: "20 trades avec un ratio risk/reward ≥ 3:1",
            icon: "arrow.up.arrow.down.square.fill",
            rarity: .epic,
            criteria: .riskRewardRatio(3.0, 20)
        ),
        BadgeDefinition(
            id: "position_sizing_25",
            name: "Gestion de Capital",
            description: "25 trades avec un sizing cohérent",
            icon: "dollarsign.circle.fill",
            rarity: .rare,
            criteria: .positionSizing(25)
        ),
        BadgeDefinition(
            id: "position_sizing_100",
            name: "Expert en Sizing",
            description: "100 trades avec un sizing cohérent",
            icon: "dollarsign.square.fill",
            rarity: .epic,
            criteria: .positionSizing(100)
        ),
        
        // MARK: - Consistance (Rare/Epic)
        BadgeDefinition(
            id: "streak_7",
            name: "Semaine Active",
            description: "Trader 7 jours consécutifs",
            icon: "calendar.circle.fill",
            rarity: .rare,
            criteria: .tradesInRow(7)
        ),
        BadgeDefinition(
            id: "streak_30",
            name: "Mois de Discipline",
            description: "Trader 30 jours consécutifs",
            icon: "calendar.badge.clock",
            rarity: .epic,
            criteria: .tradesInRow(30)
        ),
        BadgeDefinition(
            id: "journal_10",
            name: "Journalier",
            description: "10 entrées dans le journal émotionnel",
            icon: "book.fill",
            rarity: .common,
            criteria: .journalEntries(10)
        ),
        BadgeDefinition(
            id: "journal_50",
            name: "Chroniqueur",
            description: "50 entrées dans le journal émotionnel",
            icon: "book.circle.fill",
            rarity: .rare,
            criteria: .journalEntries(50)
        ),
        BadgeDefinition(
            id: "weekly_4",
            name: "Mois Régulier",
            description: "Trader au moins 1 fois par semaine pendant 4 semaines",
            icon: "calendar",
            rarity: .rare,
            criteria: .weeklyConsistency(4)
        ),
        BadgeDefinition(
            id: "weekly_12",
            name: "Trimestre Constant",
            description: "Trader au moins 1 fois par semaine pendant 12 semaines",
            icon: "calendar.badge.plus",
            rarity: .epic,
            criteria: .weeklyConsistency(12)
        ),
        
        // MARK: - Apprentissage (Rare/Epic)
        BadgeDefinition(
            id: "postmortem_5",
            name: "Analyste",
            description: "Effectuer 5 analyses post-mortem",
            icon: "doc.text.magnifyingglass",
            rarity: .rare,
            criteria: .postMortems(5)
        ),
        BadgeDefinition(
            id: "postmortem_20",
            name: "Maître Analyste",
            description: "Effectuer 20 analyses post-mortem",
            icon: "doc.text.fill",
            rarity: .epic,
            criteria: .postMortems(20)
        ),
        BadgeDefinition(
            id: "checklist_10",
            name: "Méthodique",
            description: "Compléter 10 checklists",
            icon: "checklist",
            rarity: .common,
            criteria: .checklists(10)
        ),
        BadgeDefinition(
            id: "checklist_50",
            name: "Routine Parfaite",
            description: "Compléter 50 checklists",
            icon: "checklist.checked",
            rarity: .rare,
            criteria: .checklists(50)
        ),
        BadgeDefinition(
            id: "playbook_3",
            name: "Stratège",
            description: "Créer 3 playbooks",
            icon: "book.closed.fill",
            rarity: .rare,
            criteria: .playbooks(3)
        ),
        BadgeDefinition(
            id: "playbook_10",
            name: "Architecte de Stratégies",
            description: "Créer 10 playbooks",
            icon: "books.vertical.fill",
            rarity: .epic,
            criteria: .playbooks(10)
        ),
        
        // MARK: - Performance (Epic/Legendary)
        BadgeDefinition(
            id: "winrate_60",
            name: "Gagnant",
            description: "Win rate ≥ 60% sur 20 trades minimum",
            icon: "trophy.fill",
            rarity: .epic,
            criteria: .winRate(60, 20)
        ),
        BadgeDefinition(
            id: "winrate_70",
            name: "Champion",
            description: "Win rate ≥ 70% sur 30 trades minimum",
            icon: "trophy.circle.fill",
            rarity: .legendary,
            criteria: .winRate(70, 30)
        ),
        BadgeDefinition(
            id: "profit_1000",
            name: "Mille Dollars",
            description: "Atteindre 1000$ de profit total",
            icon: "dollarsign.circle.fill",
            rarity: .epic,
            criteria: .totalProfit(1000)
        ),
        BadgeDefinition(
            id: "profit_10000",
            name: "Dix Mille Dollars",
            description: "Atteindre 10000$ de profit total",
            icon: "dollarsign.square.fill",
            rarity: .legendary,
            criteria: .totalProfit(10000)
        ),
        BadgeDefinition(
            id: "streak_5",
            name: "Série de 5",
            description: "5 victoires consécutives",
            icon: "flame.fill",
            rarity: .rare,
            criteria: .bestStreak(5)
        ),
        BadgeDefinition(
            id: "streak_10",
            name: "Série de 10",
            description: "10 victoires consécutives",
            icon: "flame.circle.fill",
            rarity: .epic,
            criteria: .bestStreak(10)
        ),
        BadgeDefinition(
            id: "system_vmc_50",
            name: "Maître VMC",
            description: "50 trades avec le système VMC",
            icon: "chart.line.uptrend.xyaxis",
            rarity: .epic,
            criteria: .systemMastery("VMC", 50)
        ),
        BadgeDefinition(
            id: "system_breakout_50",
            name: "Maître Breakout",
            description: "50 trades avec le système Breakout",
            icon: "arrow.up.right.circle.fill",
            rarity: .epic,
            criteria: .systemMastery("Breakout", 50)
        ),
        
        // MARK: - Résilience (Epic/Legendary)
        BadgeDefinition(
            id: "comeback_3_5",
            name: "Résilient",
            description: "Perdre 3 trades puis gagner 5 consécutifs",
            icon: "arrow.clockwise.circle.fill",
            rarity: .epic,
            criteria: .comeback(3, 5)
        ),
        BadgeDefinition(
            id: "comeback_5_10",
            name: "Phoenix",
            description: "Perdre 5 trades puis gagner 10 consécutifs",
            icon: "arrow.clockwise",
            rarity: .legendary,
            criteria: .comeback(5, 10)
        ),
        BadgeDefinition(
            id: "emotional_7",
            name: "Équilibre Mental",
            description: "7 jours consécutifs d'entrées dans le journal",
            icon: "heart.fill",
            rarity: .rare,
            criteria: .emotionalStability(7)
        ),
        BadgeDefinition(
            id: "emotional_30",
            name: "Zen Master",
            description: "30 jours consécutifs d'entrées dans le journal",
            icon: "heart.circle.fill",
            rarity: .epic,
            criteria: .emotionalStability(30)
        ),
        
        // MARK: - Défis (Rare/Epic)
        BadgeDefinition(
            id: "challenges_10",
            name: "Défieur",
            description: "Compléter 10 défis",
            icon: "target",
            rarity: .rare,
            criteria: .challengesCompleted(10)
        ),
        BadgeDefinition(
            id: "challenges_50",
            name: "Maître des Défis",
            description: "Compléter 50 défis",
            icon: "target.circle.fill",
            rarity: .epic,
            criteria: .challengesCompleted(50)
        ),
        BadgeDefinition(
            id: "daily_challenge_7",
            name: "Défi Quotidien",
            description: "Compléter un défi quotidien 7 jours consécutifs",
            icon: "sun.max.fill",
            rarity: .rare,
            criteria: .dailyChallengesStreak(7)
        ),
        BadgeDefinition(
            id: "daily_challenge_30",
            name: "Routine de Défis",
            description: "Compléter un défi quotidien 30 jours consécutifs",
            icon: "sun.max.circle.fill",
            rarity: .epic,
            criteria: .dailyChallengesStreak(30)
        ),
        
        // MARK: - Nouvelles catégories de badges
        
        // MARK: - Milestones Avancés
        BadgeDefinition(
            id: "trades_100",
            name: "Centenaire",
            description: "Effectuer 100 trades au total",
            icon: "100.circle.fill",
            rarity: .rare,
            criteria: .totalTrades(100)
        ),
        BadgeDefinition(
            id: "trades_500",
            name: "Vétéran",
            description: "Effectuer 500 trades au total",
            icon: "500.circle.fill",
            rarity: .epic,
            criteria: .totalTrades(500)
        ),
        BadgeDefinition(
            id: "trades_1000",
            name: "Légende",
            description: "Effectuer 1000 trades au total",
            icon: "1000.circle.fill",
            rarity: .legendary,
            criteria: .totalTrades(1000)
        ),
        BadgeDefinition(
            id: "level_15",
            name: "Trader Avancé",
            description: "Atteindre le niveau 15",
            icon: "15.circle.fill",
            rarity: .common,
            criteria: .levelReached(15)
        ),
        BadgeDefinition(
            id: "level_30",
            name: "Expert Trader",
            description: "Atteindre le niveau 30",
            icon: "30.circle.fill",
            rarity: .rare,
            criteria: .levelReached(30)
        ),
        BadgeDefinition(
            id: "level_40",
            name: "Maître Expert",
            description: "Atteindre le niveau 40",
            icon: "40.circle.fill",
            rarity: .epic,
            criteria: .levelReached(40)
        ),
        BadgeDefinition(
            id: "prestige_2",
            name: "Prestige II",
            description: "Atteindre le deuxième prestige",
            icon: "star.fill",
            rarity: .epic,
            criteria: .prestigeReached(2)
        ),
        BadgeDefinition(
            id: "prestige_10",
            name: "Prestige X",
            description: "Atteindre le prestige 10",
            icon: "star.circle.fill",
            rarity: .legendary,
            criteria: .prestigeReached(10)
        ),
        BadgeDefinition(
            id: "xp_50000",
            name: "Cinquante Mille Points",
            description: "Gagner 50000 XP au total",
            icon: "star.fill",
            rarity: .epic,
            criteria: .totalXP(50000)
        ),
        BadgeDefinition(
            id: "xp_100000",
            name: "Cent Mille Points",
            description: "Gagner 100000 XP au total",
            icon: "star.circle.fill",
            rarity: .legendary,
            criteria: .totalXP(100000)
        ),
        
        // MARK: - Performance Avancée
        BadgeDefinition(
            id: "winrate_50",
            name: "Équilibre",
            description: "Win rate ≥ 50% sur 15 trades minimum",
            icon: "equal.circle.fill",
            rarity: .common,
            criteria: .winRate(50, 15)
        ),
        BadgeDefinition(
            id: "winrate_80",
            name: "Légende Vivante",
            description: "Win rate ≥ 80% sur 25 trades minimum",
            icon: "trophy.fill",
            rarity: .legendary,
            criteria: .winRate(80, 25)
        ),
        BadgeDefinition(
            id: "profit_500",
            name: "Cinq Cent Dollars",
            description: "Atteindre 500$ de profit total",
            icon: "dollarsign.circle.fill",
            rarity: .rare,
            criteria: .totalProfit(500)
        ),
        BadgeDefinition(
            id: "profit_5000",
            name: "Cinq Mille Dollars",
            description: "Atteindre 5000$ de profit total",
            icon: "dollarsign.square.fill",
            rarity: .epic,
            criteria: .totalProfit(5000)
        ),
        BadgeDefinition(
            id: "profit_50000",
            name: "Cinquante Mille Dollars",
            description: "Atteindre 50000$ de profit total",
            icon: "dollarsign.circle.fill",
            rarity: .legendary,
            criteria: .totalProfit(50000)
        ),
        BadgeDefinition(
            id: "streak_3",
            name: "Série de 3",
            description: "3 victoires consécutives",
            icon: "flame.fill",
            rarity: .common,
            criteria: .bestStreak(3)
        ),
        BadgeDefinition(
            id: "streak_15",
            name: "Série de 15",
            description: "15 victoires consécutives",
            icon: "flame.circle.fill",
            rarity: .legendary,
            criteria: .bestStreak(15)
        ),
        BadgeDefinition(
            id: "avg_win_100",
            name: "Gains Solides",
            description: "Gain moyen ≥ 100$ sur 10 trades gagnants",
            icon: "arrow.up.circle.fill",
            rarity: .rare,
            criteria: .averageWin(100, 10)
        ),
        BadgeDefinition(
            id: "avg_win_500",
            name: "Gains Exceptionnels",
            description: "Gain moyen ≥ 500$ sur 15 trades gagnants",
            icon: "arrow.up.square.fill",
            rarity: .epic,
            criteria: .averageWin(500, 15)
        ),
        
        // MARK: - Discipline & Risk Management Avancé
        BadgeDefinition(
            id: "stop_loss_25",
            name: "Protection Renforcée",
            description: "Respecter un stop-loss sur 25 trades",
            icon: "shield.fill",
            rarity: .rare,
            criteria: .stopLossRespected(25)
        ),
        BadgeDefinition(
            id: "stop_loss_100",
            name: "Bouclier Absolu",
            description: "Respecter un stop-loss sur 100 trades",
            icon: "shield.circle.fill",
            rarity: .legendary,
            criteria: .stopLossRespected(100)
        ),
        BadgeDefinition(
            id: "risk_reward_1.5",
            name: "Ratio Positif",
            description: "5 trades avec un ratio risk/reward ≥ 1.5:1",
            icon: "arrow.up.arrow.down",
            rarity: .common,
            criteria: .riskRewardRatio(1.5, 5)
        ),
        BadgeDefinition(
            id: "risk_reward_4",
            name: "Ratio Exceptionnel",
            description: "15 trades avec un ratio risk/reward ≥ 4:1",
            icon: "arrow.up.arrow.down.circle.fill",
            rarity: .epic,
            criteria: .riskRewardRatio(4.0, 15)
        ),
        BadgeDefinition(
            id: "risk_reward_5",
            name: "Ratio Légendaire",
            description: "20 trades avec un ratio risk/reward ≥ 5:1",
            icon: "arrow.up.arrow.down.square.fill",
            rarity: .legendary,
            criteria: .riskRewardRatio(5.0, 20)
        ),
        BadgeDefinition(
            id: "position_sizing_10",
            name: "Sizing Débutant",
            description: "10 trades avec un sizing cohérent",
            icon: "dollarsign.circle",
            rarity: .common,
            criteria: .positionSizing(10)
        ),
        BadgeDefinition(
            id: "position_sizing_50",
            name: "Sizing Confirmé",
            description: "50 trades avec un sizing cohérent",
            icon: "dollarsign.circle.fill",
            rarity: .rare,
            criteria: .positionSizing(50)
        ),
        BadgeDefinition(
            id: "position_sizing_200",
            name: "Maître du Sizing",
            description: "200 trades avec un sizing cohérent",
            icon: "dollarsign.square.fill",
            rarity: .legendary,
            criteria: .positionSizing(200)
        ),
        BadgeDefinition(
            id: "max_drawdown_10",
            name: "Contrôle du Risque",
            description: "Drawdown maximum ≤ 10%",
            icon: "chart.line.downtrend.xyaxis",
            rarity: .rare,
            criteria: .maxDrawdown(10)
        ),
        BadgeDefinition(
            id: "max_drawdown_5",
            name: "Maîtrise du Risque",
            description: "Drawdown maximum ≤ 5%",
            icon: "chart.line.downtrend.xyaxis.circle.fill",
            rarity: .epic,
            criteria: .maxDrawdown(5)
        ),
        
        // MARK: - Consistance Avancée
        BadgeDefinition(
            id: "streak_14",
            name: "Deux Semaines Actives",
            description: "Trader 14 jours consécutifs",
            icon: "calendar.circle.fill",
            rarity: .rare,
            criteria: .tradesInRow(14)
        ),
        BadgeDefinition(
            id: "streak_60",
            name: "Deux Mois de Discipline",
            description: "Trader 60 jours consécutifs",
            icon: "calendar.badge.clock",
            rarity: .epic,
            criteria: .tradesInRow(60)
        ),
        BadgeDefinition(
            id: "streak_90",
            name: "Trimestre Parfait",
            description: "Trader 90 jours consécutifs",
            icon: "calendar.badge.exclamationmark",
            rarity: .legendary,
            criteria: .tradesInRow(90)
        ),
        BadgeDefinition(
            id: "journal_25",
            name: "Journalier Confirmé",
            description: "25 entrées dans le journal émotionnel",
            icon: "book.fill",
            rarity: .common,
            criteria: .journalEntries(25)
        ),
        BadgeDefinition(
            id: "journal_100",
            name: "Historien",
            description: "100 entrées dans le journal émotionnel",
            icon: "book.circle.fill",
            rarity: .epic,
            criteria: .journalEntries(100)
        ),
        BadgeDefinition(
            id: "journal_200",
            name: "Archiviste",
            description: "200 entrées dans le journal émotionnel",
            icon: "books.vertical.fill",
            rarity: .legendary,
            criteria: .journalEntries(200)
        ),
        BadgeDefinition(
            id: "weekly_8",
            name: "Deux Mois Réguliers",
            description: "Trader au moins 1 fois par semaine pendant 8 semaines",
            icon: "calendar",
            rarity: .rare,
            criteria: .weeklyConsistency(8)
        ),
        BadgeDefinition(
            id: "weekly_24",
            name: "Six Mois Constants",
            description: "Trader au moins 1 fois par semaine pendant 24 semaines",
            icon: "calendar.badge.plus",
            rarity: .legendary,
            criteria: .weeklyConsistency(24)
        ),
        BadgeDefinition(
            id: "monthly_3",
            name: "Trimestre Actif",
            description: "Trader au moins 5 fois par mois pendant 3 mois",
            icon: "calendar.badge.clock",
            rarity: .rare,
            criteria: .monthlyConsistency(3, 5)
        ),
        BadgeDefinition(
            id: "monthly_6",
            name: "Semestre Actif",
            description: "Trader au moins 5 fois par mois pendant 6 mois",
            icon: "calendar.badge.exclamationmark",
            rarity: .epic,
            criteria: .monthlyConsistency(6, 5)
        ),
        
        // MARK: - Apprentissage Avancé
        BadgeDefinition(
            id: "postmortem_10",
            name: "Analyste Confirmé",
            description: "Effectuer 10 analyses post-mortem",
            icon: "doc.text.magnifyingglass",
            rarity: .rare,
            criteria: .postMortems(10)
        ),
        BadgeDefinition(
            id: "postmortem_50",
            name: "Maître Analyste Légendaire",
            description: "Effectuer 50 analyses post-mortem",
            icon: "doc.text.fill",
            rarity: .legendary,
            criteria: .postMortems(50)
        ),
        BadgeDefinition(
            id: "checklist_25",
            name: "Méthodique Confirmé",
            description: "Compléter 25 checklists",
            icon: "checklist",
            rarity: .common,
            criteria: .checklists(25)
        ),
        BadgeDefinition(
            id: "checklist_100",
            name: "Routine Parfaite Légendaire",
            description: "Compléter 100 checklists",
            icon: "checklist.checked",
            rarity: .epic,
            criteria: .checklists(100)
        ),
        BadgeDefinition(
            id: "playbook_5",
            name: "Stratège Confirmé",
            description: "Créer 5 playbooks",
            icon: "book.closed.fill",
            rarity: .rare,
            criteria: .playbooks(5)
        ),
        BadgeDefinition(
            id: "playbook_20",
            name: "Architecte Légendaire",
            description: "Créer 20 playbooks",
            icon: "books.vertical.fill",
            rarity: .legendary,
            criteria: .playbooks(20)
        ),
        
        // MARK: - Spécialités & Systèmes
        BadgeDefinition(
            id: "system_scalping_25",
            name: "Scalpeur",
            description: "25 trades avec le système Scalping",
            icon: "bolt.fill",
            rarity: .rare,
            criteria: .systemMastery("Scalping", 25)
        ),
        BadgeDefinition(
            id: "system_scalping_100",
            name: "Maître Scalpeur",
            description: "100 trades avec le système Scalping",
            icon: "bolt.circle.fill",
            rarity: .epic,
            criteria: .systemMastery("Scalping", 100)
        ),
        BadgeDefinition(
            id: "system_mean_reversion_25",
            name: "Mean Reversion",
            description: "25 trades avec le système Mean Reversion",
            icon: "arrow.triangle.2.circlepath",
            rarity: .rare,
            criteria: .systemMastery("Mean Reversion", 25)
        ),
        BadgeDefinition(
            id: "system_trend_following_25",
            name: "Trend Follower",
            description: "25 trades avec le système Trend Following",
            icon: "chart.line.uptrend.xyaxis.circle.fill",
            rarity: .rare,
            criteria: .systemMastery("Trend Following", 25)
        ),
        BadgeDefinition(
            id: "system_multi_3",
            name: "Polyvalent",
            description: "Utiliser au moins 3 systèmes différents avec succès",
            icon: "square.grid.3x3.fill",
            rarity: .epic,
            criteria: .multipleSystems(3)
        ),
        BadgeDefinition(
            id: "system_multi_5",
            name: "Maître Polyvalent",
            description: "Utiliser au moins 5 systèmes différents avec succès",
            icon: "square.grid.3x3.circle.fill",
            rarity: .legendary,
            criteria: .multipleSystems(5)
        ),
        
        // MARK: - Symboles & Marchés
        BadgeDefinition(
            id: "symbol_btc_50",
            name: "Bitcoinien",
            description: "50 trades sur BTC",
            icon: "bitcoinsign.circle.fill",
            rarity: .rare,
            criteria: .symbolMastery("BTC", 50)
        ),
        BadgeDefinition(
            id: "symbol_eth_50",
            name: "Ethereumien",
            description: "50 trades sur ETH",
            icon: "e.circle.fill",
            rarity: .rare,
            criteria: .symbolMastery("ETH", 50)
        ),
        BadgeDefinition(
            id: "symbol_multi_5",
            name: "Diversifié",
            description: "Trader au moins 5 symboles différents",
            icon: "square.grid.2x2.fill",
            rarity: .rare,
            criteria: .multipleSymbols(5)
        ),
        BadgeDefinition(
            id: "symbol_multi_10",
            name: "Portfolio Diversifié",
            description: "Trader au moins 10 symboles différents",
            icon: "square.grid.2x2.circle.fill",
            rarity: .epic,
            criteria: .multipleSymbols(10)
        ),
        
        // MARK: - Résilience Avancée
        BadgeDefinition(
            id: "comeback_2_3",
            name: "Résilient Débutant",
            description: "Perdre 2 trades puis gagner 3 consécutifs",
            icon: "arrow.clockwise.circle",
            rarity: .rare,
            criteria: .comeback(2, 3)
        ),
        BadgeDefinition(
            id: "comeback_10_15",
            name: "Résurrection",
            description: "Perdre 10 trades puis gagner 15 consécutifs",
            icon: "arrow.clockwise",
            rarity: .legendary,
            criteria: .comeback(10, 15)
        ),
        BadgeDefinition(
            id: "emotional_14",
            name: "Équilibre Mental Confirmé",
            description: "14 jours consécutifs d'entrées dans le journal",
            icon: "heart.fill",
            rarity: .rare,
            criteria: .emotionalStability(14)
        ),
        BadgeDefinition(
            id: "emotional_60",
            name: "Zen Master Légendaire",
            description: "60 jours consécutifs d'entrées dans le journal",
            icon: "heart.circle.fill",
            rarity: .legendary,
            criteria: .emotionalStability(60)
        ),
        BadgeDefinition(
            id: "recovery_3",
            name: "Rebond",
            description: "Récupérer après 3 pertes consécutives",
            icon: "arrow.up.circle.fill",
            rarity: .rare,
            criteria: .recovery(3)
        ),
        BadgeDefinition(
            id: "recovery_5",
            name: "Grand Rebond",
            description: "Récupérer après 5 pertes consécutives",
            icon: "arrow.up.square.fill",
            rarity: .epic,
            criteria: .recovery(5)
        ),
        
        // MARK: - Défis Avancés
        BadgeDefinition(
            id: "challenges_25",
            name: "Défieur Confirmé",
            description: "Compléter 25 défis",
            icon: "target",
            rarity: .rare,
            criteria: .challengesCompleted(25)
        ),
        BadgeDefinition(
            id: "challenges_100",
            name: "Maître des Défis Légendaire",
            description: "Compléter 100 défis",
            icon: "target.circle.fill",
            rarity: .legendary,
            criteria: .challengesCompleted(100)
        ),
        BadgeDefinition(
            id: "daily_challenge_14",
            name: "Défi Quotidien Confirmé",
            description: "Compléter un défi quotidien 14 jours consécutifs",
            icon: "sun.max.fill",
            rarity: .rare,
            criteria: .dailyChallengesStreak(14)
        ),
        BadgeDefinition(
            id: "daily_challenge_60",
            name: "Routine de Défis Légendaire",
            description: "Compléter un défi quotidien 60 jours consécutifs",
            icon: "sun.max.circle.fill",
            rarity: .legendary,
            criteria: .dailyChallengesStreak(60)
        ),
        BadgeDefinition(
            id: "weekly_challenge_4",
            name: "Défi Hebdomadaire",
            description: "Compléter 4 défis hebdomadaires consécutifs",
            icon: "moon.fill",
            rarity: .rare,
            criteria: .weeklyChallengesStreak(4)
        ),
        BadgeDefinition(
            id: "weekly_challenge_12",
            name: "Défi Hebdomadaire Légendaire",
            description: "Compléter 12 défis hebdomadaires consécutifs",
            icon: "moon.circle.fill",
            rarity: .legendary,
            criteria: .weeklyChallengesStreak(12)
        ),
        
        // MARK: - Records & Exploits
        BadgeDefinition(
            id: "single_trade_1000",
            name: "Trade Exceptionnel",
            description: "Un seul trade avec profit ≥ 1000$",
            icon: "star.fill",
            rarity: .epic,
            criteria: .singleTradeProfit(1000)
        ),
        BadgeDefinition(
            id: "single_trade_5000",
            name: "Trade Légendaire",
            description: "Un seul trade avec profit ≥ 5000$",
            icon: "star.circle.fill",
            rarity: .legendary,
            criteria: .singleTradeProfit(5000)
        ),
        BadgeDefinition(
            id: "perfect_day",
            name: "Jour Parfait",
            description: "Gagner sur tous les trades d'une journée (min 3 trades)",
            icon: "sun.max.fill",
            rarity: .epic,
            criteria: .perfectDay(3)
        ),
        BadgeDefinition(
            id: "perfect_week",
            name: "Semaine Parfaite",
            description: "Gagner sur tous les trades d'une semaine (min 5 trades)",
            icon: "calendar.badge.plus",
            rarity: .legendary,
            criteria: .perfectWeek(5)
        ),
        BadgeDefinition(
            id: "zero_loss_day",
            name: "Jour Sans Perte",
            description: "Aucune perte sur une journée (min 3 trades)",
            icon: "checkmark.shield.fill",
            rarity: .rare,
            criteria: .zeroLossDay(3)
        ),
        BadgeDefinition(
            id: "zero_loss_week",
            name: "Semaine Sans Perte",
            description: "Aucune perte sur une semaine (min 5 trades)",
            icon: "checkmark.shield",
            rarity: .epic,
            criteria: .zeroLossWeek(5)
        ),
        
        // MARK: - Réseaux Sociaux & Communauté
        BadgeDefinition(
            id: "social_discord",
            name: "Discordien",
            description: "Rejoindre notre communauté Discord",
            icon: "message.fill",
            rarity: .common,
            criteria: .socialLinkClicked(.discord)
        ),
        BadgeDefinition(
            id: "social_twitter",
            name: "Tweet Trader",
            description: "Suivre notre compte Twitter/X",
            icon: "at",
            rarity: .common,
            criteria: .socialLinkClicked(.twitter)
        ),
        BadgeDefinition(
            id: "social_telegram",
            name: "Telegram Trader",
            description: "Rejoindre notre groupe Telegram",
            icon: "paperplane.fill",
            rarity: .common,
            criteria: .socialLinkClicked(.telegram)
        ),
        BadgeDefinition(
            id: "social_reddit",
            name: "Redditeur",
            description: "Rejoindre notre communauté Reddit",
            icon: "r.circle.fill",
            rarity: .common,
            criteria: .socialLinkClicked(.reddit)
        ),
        BadgeDefinition(
            id: "social_youtube",
            name: "Abonné YouTube",
            description: "S'abonner à notre chaîne YouTube",
            icon: "play.circle.fill",
            rarity: .common,
            criteria: .socialLinkClicked(.youtube)
        ),
        BadgeDefinition(
            id: "social_instagram",
            name: "Instagrammer",
            description: "Suivre notre compte Instagram",
            icon: "camera.fill",
            rarity: .common,
            criteria: .socialLinkClicked(.instagram)
        ),
        BadgeDefinition(
            id: "social_tiktok",
            name: "TikToker",
            description: "Suivre notre compte TikTok",
            icon: "music.note",
            rarity: .common,
            criteria: .socialLinkClicked(.tiktok)
        ),
        BadgeDefinition(
            id: "social_twitch",
            name: "Twitcher",
            description: "Suivre notre chaîne Twitch",
            icon: "gamecontroller.fill",
            rarity: .common,
            criteria: .socialLinkClicked(.twitch)
        ),
        BadgeDefinition(
            id: "social_all_3",
            name: "Social Butterfly",
            description: "Rejoindre 3 communautés sociales",
            icon: "person.2.fill",
            rarity: .rare,
            criteria: .multipleSocialLinks(3)
        ),
        BadgeDefinition(
            id: "social_all_5",
            name: "Influenceur",
            description: "Rejoindre 5 communautés sociales",
            icon: "person.3.fill",
            rarity: .epic,
            criteria: .multipleSocialLinks(5)
        ),
        BadgeDefinition(
            id: "social_all_7",
            name: "Légende Sociale",
            description: "Rejoindre 7 communautés sociales",
            icon: "person.crop.circle.badge.plus",
            rarity: .legendary,
            criteria: .multipleSocialLinks(7)
        ),
        BadgeDefinition(
            id: "referral_1",
            name: "Parrain",
            description: "Parrainer 1 utilisateur",
            icon: "person.badge.plus",
            rarity: .common,
            criteria: .referralCount(1)
        ),
        BadgeDefinition(
            id: "referral_5",
            name: "Ambassadeur",
            description: "Parrainer 5 utilisateurs",
            icon: "person.2.badge.plus",
            rarity: .rare,
            criteria: .referralCount(5)
        ),
        BadgeDefinition(
            id: "referral_10",
            name: "Évangéliste",
            description: "Parrainer 10 utilisateurs",
            icon: "person.3.badge.plus",
            rarity: .epic,
            criteria: .referralCount(10)
        ),
        BadgeDefinition(
            id: "referral_25",
            name: "Légende du Parrainage",
            description: "Parrainer 25 utilisateurs",
            icon: "person.crop.circle.badge.plus",
            rarity: .legendary,
            criteria: .referralCount(25)
        ),
        BadgeDefinition(
            id: "community_5",
            name: "Contributeur",
            description: "5 contributions à la communauté",
            icon: "bubble.left.and.bubble.right.fill",
            rarity: .common,
            criteria: .communityContribution(5)
        ),
        BadgeDefinition(
            id: "community_20",
            name: "Membre Actif",
            description: "20 contributions à la communauté",
            icon: "bubble.left.and.bubble.right",
            rarity: .rare,
            criteria: .communityContribution(20)
        ),
        BadgeDefinition(
            id: "community_50",
            name: "Pilier de la Communauté",
            description: "50 contributions à la communauté",
            icon: "person.2.circle.fill",
            rarity: .epic,
            criteria: .communityContribution(50)
        ),
        BadgeDefinition(
            id: "community_100",
            name: "Légende Communautaire",
            description: "100 contributions à la communauté",
            icon: "person.3.circle.fill",
            rarity: .legendary,
            criteria: .communityContribution(100)
        )
    ]
}

