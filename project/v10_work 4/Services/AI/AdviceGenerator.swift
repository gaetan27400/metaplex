//
//  AdviceGenerator.swift
//  Journal de trading 2025
//

import Foundation

struct TradingAdviceSummary {
    let edgeScore: Int
    let status: AdviceStatus
    let primaryAction: String
    let optimalWindow: String?
    let focus: String?
    let positiveFactors: [String]
    let negativeFactors: [String]
    let streakAnalysis: StreakAnalysis?
}

enum AdviceStatus: String {
    case optimal
    case neutral
    case avoid
    
    var emoji: String {
        switch self {
        case .optimal: return "🟢"
        case .neutral: return "🟡"
        case .avoid: return "🔴"
        }
    }
    
    var label: String {
        switch self {
        case .optimal: return "Conditions optimales"
        case .neutral: return "Conditions neutres"
        case .avoid: return "Éviter de trader"
        }
    }
    
    var color: String {
        switch self {
        case .optimal: return "#4CD964"
        case .neutral: return "#FF9F0A"
        case .avoid: return "#FF3B30"
        }
    }
}

struct StreakAnalysis {
    let currentWinStreak: Int
    let currentLossStreak: Int
    let maxWinStreak: Int
    let maxLossStreak: Int
    let revengeTradesDetected: Int
    let winRateAfterWin: Double
    let winRateAfterLoss: Double
    let winRateAfter2Losses: Double
    let avgDelayAfterWin: TimeInterval
    let avgDelayAfterLoss: TimeInterval
    let tiltDetected: Bool
}

class AdviceGenerator {
    
    // MARK: - Generate Main Advice
    
    static func generateAdvice(
        disciplineScore: Int,
        emotionalLoad: Int,
        trades: [Trade],
        appState: AppState,
        language: Localizable.Language = .french
    ) -> TradingAdviceSummary {
        
        let closedTrades = trades.filter { $0.isClosed }.sorted(by: { $0.date < $1.date })
        
        // Calculer les streaks
        let winStreak = calculateCurrentWinStreak(closedTrades, appState: appState)
        let lossStreak = calculateCurrentLossStreak(closedTrades, appState: appState)
        
        // Trades aujourd'hui
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tradesToday = closedTrades.filter { calendar.isDate($0.date, inSameDayAs: today) }.count
        
        // Calcul edgeScore
        var edgeScore: Double = 50.0
        edgeScore += Double(disciplineScore) * 0.3
        edgeScore -= Double(emotionalLoad) * 0.3
        edgeScore += Double(winStreak) * 2.0
        edgeScore -= Double(lossStreak) * 5.0
        
        // Clamp 0-100
        let finalEdgeScore = Int(max(0, min(100, edgeScore)))
        
        // Déterminer le statut
        let status: AdviceStatus
        if finalEdgeScore > 75 {
            status = .optimal
        } else if finalEdgeScore >= 50 {
            status = .neutral
        } else {
            status = .avoid
        }
        
        // Générer l'action prioritaire
        let primaryAction = generatePrimaryAction(
            status: status,
            lossStreak: lossStreak,
            tradesToday: tradesToday,
            disciplineScore: disciplineScore,
            emotionalLoad: emotionalLoad,
            language: language
        )
        
        // Fenêtre optimale
        let optimalWindow = findOptimalWindow(closedTrades, appState: appState)
        
        // Focus du jour
        let focus = generateFocus(
            status: status,
            trades: closedTrades,
            systems: appState.systems,
            appState: appState,
            language: language
        )
        
        // Facteurs positifs et négatifs
        let (positiveFactors, negativeFactors) = analyzeFactors(
            disciplineScore: disciplineScore,
            emotionalLoad: emotionalLoad,
            winStreak: winStreak,
            lossStreak: lossStreak,
            tradesToday: tradesToday,
            trades: closedTrades,
            appState: appState,
            language: language
        )
        
        // Analyse des streaks et tilt
        let streakAnalysis = analyzeStreaksAndTilt(closedTrades, appState: appState)
        
        return TradingAdviceSummary(
            edgeScore: finalEdgeScore,
            status: status,
            primaryAction: primaryAction,
            optimalWindow: optimalWindow,
            focus: focus,
            positiveFactors: positiveFactors,
            negativeFactors: negativeFactors,
            streakAnalysis: streakAnalysis
        )
    }
    
    // MARK: - Streak Calculations
    
    private static func calculateCurrentWinStreak(_ trades: [Trade], appState: AppState) -> Int {
        var streak = 0
        for trade in trades.reversed() {
            guard let pnl = appState.netPnL(for: trade) else { continue }
            if pnl > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
    
    private static func calculateCurrentLossStreak(_ trades: [Trade], appState: AppState) -> Int {
        var streak = 0
        for trade in trades.reversed() {
            guard let pnl = appState.netPnL(for: trade) else { continue }
            if pnl <= 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
    
    // MARK: - Primary Action Generation
    
    private static func generatePrimaryAction(
        status: AdviceStatus,
        lossStreak: Int,
        tradesToday: Int,
        disciplineScore: Int,
        emotionalLoad: Int,
        language: Localizable.Language = .french
    ) -> String {
        let isFR = (language == .french)
        
        // Priorité 1 : Loss streak dangereux
        if lossStreak >= 3 {
            return isFR
                ? "🛑 STOP : \(lossStreak) pertes consécutives. Pause obligatoire de 24h."
                : "🛑 STOP: \(lossStreak) consecutive losses. Mandatory 24h break."
        }
        
        if lossStreak == 2 {
            return isFR
                ? "⚠️ PRUDENCE : 2 pertes d'affilée. Réduis ta taille à 50% ou passe ton tour."
                : "⚠️ CAUTION: 2 losses in a row. Reduce your size to 50% or skip."
        }
        
        // Priorité 2 : Trop de trades aujourd'hui
        if tradesToday >= 5 {
            return isFR
                ? "🚫 LIMITE ATTEINTE : \(tradesToday) trades aujourd'hui. Stop pour la journée."
                : "🚫 LIMIT REACHED: \(tradesToday) trades today. Stop for the day."
        }
        
        // Priorité 3 : Charge émotionnelle élevée
        if emotionalLoad >= 70 {
            return isFR
                ? "🧘 MENTAL FRAGILE : Prends une pause. Médite. Reviens à tête froide."
                : "🧘 FRAGILE MINDSET: Take a break. Meditate. Come back with a clear head."
        }
        
        // Priorité 4 : Discipline faible
        if disciplineScore < 50 {
            return isFR
                ? "📋 RETOUR AUX BASES : Vérifie ton plan avant chaque trade. Note tes émotions."
                : "📋 BACK TO BASICS: Check your plan before each trade. Log your emotions."
        }
        
        // Status normal
        switch status {
        case .optimal:
            return isFR
                ? "✅ CONDITIONS OPTIMALES : Exécute ton plan. Reste discipliné."
                : "✅ OPTIMAL CONDITIONS: Execute your plan. Stay disciplined."
        case .neutral:
            return isFR
                ? "🎯 CONDITIONS NEUTRES : Trade uniquement tes setups A+. Sois sélectif."
                : "🎯 NEUTRAL CONDITIONS: Trade only your A+ setups. Be selective."
        case .avoid:
            return isFR
                ? "⛔ CONDITIONS DÉFAVORABLES : Évite de trader ou limite-toi à 1 trade max."
                : "⛔ UNFAVORABLE CONDITIONS: Avoid trading or limit yourself to 1 trade max."
        }
    }
    
    // MARK: - Optimal Window Finding
    
    private static func findOptimalWindow(_ trades: [Trade], appState: AppState) -> String? {
        guard trades.count >= 20 else { return nil }
        
        let calendar = Calendar.current
        let byHour = Dictionary(grouping: trades, by: { calendar.component(.hour, from: $0.date) })
        
        // Calculer le P&L et winrate par heure
        var hourStats: [(hour: Int, pnl: Double, winRate: Double, count: Int)] = []
        
        for (hour, hourTrades) in byHour {
            guard hourTrades.count >= 5 else { continue }
            let pnl = hourTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            let wins = hourTrades.filter { (appState.netPnL(for: $0) ?? 0) > 0 }.count
            let winRate = Double(wins) / Double(hourTrades.count)
            hourStats.append((hour, pnl, winRate, hourTrades.count))
        }
        
        guard let best = hourStats.max(by: { $0.winRate < $1.winRate }) else { return nil }
        
        if best.winRate >= 0.6 {
            return "\(best.hour)h-\(best.hour+1)h (WR \(Int(best.winRate * 100))% sur \(best.count) trades)"
        }
        
        return nil
    }
    
    // MARK: - Focus Generation
    
    private static func generateFocus(
        status: AdviceStatus,
        trades: [Trade],
        systems: [TradingSystem],
        appState: AppState,
        language: Localizable.Language = .french
    ) -> String? {
        let isFR = (language == .french)
        
        guard trades.count >= 10 else {
            return isFR
                ? "Construire un historique (min. 10 trades)"
                : "Build a track record (min. 10 trades)"
        }
        
        // Trouver le meilleur système
        let systemPnL = Dictionary(grouping: trades, by: { $0.systemId })
            .mapValues { trades in
                (
                    pnl: trades.compactMap { appState.netPnL(for: $0) }.reduce(0, +),
                    count: trades.count,
                    winRate: Double(trades.filter { (appState.netPnL(for: $0) ?? 0) > 0 }.count) / Double(trades.count)
                )
            }
        
        guard let best = systemPnL
            .filter({ $0.value.count >= 5 && $0.value.winRate >= 0.55 })
            .max(by: { $0.value.pnl < $1.value.pnl }) else {
            return isFR ? "Aucun setup A+ identifié. Sois ultra-sélectif." : "No A+ setup identified. Be ultra-selective."
        }
        
        let systemName = systems.first(where: { $0.id == best.key })?.name ?? (isFR ? "Setup principal" : "Main setup")
        
        return isFR
            ? "Focus exclusif sur '\(systemName)' (WR \(Int(best.value.winRate * 100))%)"
            : "Exclusive focus on '\(systemName)' (WR \(Int(best.value.winRate * 100))%)"
    }
    
    // MARK: - Factors Analysis
    
    private static func analyzeFactors(
        disciplineScore: Int,
        emotionalLoad: Int,
        winStreak: Int,
        lossStreak: Int,
        tradesToday: Int,
        trades: [Trade],
        appState: AppState,
        language: Localizable.Language = .french
    ) -> (positive: [String], negative: [String]) {
        let isFR = (language == .french)
        var positive: [String] = []
        var negative: [String] = []
        
        // Discipline
        if disciplineScore >= 70 {
            positive.append(isFR ? "Discipline élevée (\(disciplineScore)%)" : "High discipline (\(disciplineScore)%)")
        } else if disciplineScore < 50 {
            negative.append(isFR ? "Discipline faible (\(disciplineScore)%)" : "Low discipline (\(disciplineScore)%)")
        }
        
        // Charge émotionnelle
        if emotionalLoad <= 30 {
            positive.append(isFR ? "État mental stable" : "Stable mental state")
        } else if emotionalLoad >= 70 {
            negative.append(isFR ? "Charge émotionnelle élevée (\(emotionalLoad)%)" : "High emotional load (\(emotionalLoad)%)")
        }
        
        // Win streak
        if winStreak >= 3 {
            positive.append(isFR ? "Série de \(winStreak) gains" : "\(winStreak)-win streak")
        }
        
        // Loss streak
        if lossStreak >= 2 {
            negative.append(isFR ? "Série de \(lossStreak) pertes — Risque de tilt" : "\(lossStreak)-loss streak — Tilt risk")
        }
        
        // Volume de trades aujourd'hui
        if tradesToday == 0 {
            positive.append(isFR ? "Aucun trade aujourd'hui — Fresh start" : "No trades today — Fresh start")
        } else if tradesToday >= 4 {
            negative.append(isFR ? "Déjà \(tradesToday) trades aujourd'hui — Fatigue" : "Already \(tradesToday) trades today — Fatigue")
        }
        
        // Win rate récent (20 derniers trades)
        let recentTrades = Array(trades.suffix(20))
        if recentTrades.count >= 10 {
            let recentWins = recentTrades.filter { (appState.netPnL(for: $0) ?? 0) > 0 }.count
            let recentWinRate = Double(recentWins) / Double(recentTrades.count)
            if recentWinRate >= 0.6 {
                positive.append(isFR ? "WR récent fort (\(Int(recentWinRate * 100))%)" : "Strong recent WR (\(Int(recentWinRate * 100))%)")
            } else if recentWinRate < 0.4 {
                negative.append(isFR ? "WR récent faible (\(Int(recentWinRate * 100))%)" : "Weak recent WR (\(Int(recentWinRate * 100))%)")
            }
        }
        
        // Cohérence (trades avec système)
        let tradesWithSystem = trades.filter { trade in
            appState.systems.contains(where: { $0.id == trade.systemId })
        }
        let coherence = trades.isEmpty ? 0.0 : Double(tradesWithSystem.count) / Double(trades.count)
        if coherence >= 0.8 {
            positive.append(isFR ? "Cohérence élevée (\(Int(coherence * 100))%)" : "High consistency (\(Int(coherence * 100))%)")
        } else if coherence < 0.5 {
            negative.append(isFR ? "Trop de trades impulsifs (\(Int((1 - coherence) * 100))%)" : "Too many impulsive trades (\(Int((1 - coherence) * 100))%)")
        }
        
        return (positive, negative)
    }
    
    // MARK: - Streak & Tilt Analysis
    
    static func analyzeStreaksAndTilt(_ trades: [Trade], appState: AppState) -> StreakAnalysis {
        let sortedTrades = trades.sorted(by: { $0.date < $1.date })
        
        // Current streaks
        let currentWinStreak = calculateCurrentWinStreak(sortedTrades, appState: appState)
        let currentLossStreak = calculateCurrentLossStreak(sortedTrades, appState: appState)
        
        // Max streaks
        let (maxWin, maxLoss) = calculateMaxStreaks(sortedTrades, appState: appState)
        
        // Analyser le comportement après wins/losses
        var winsAfterWin = 0
        var tradesAfterWin = 0
        var winsAfterLoss = 0
        var tradesAfterLoss = 0
        var winsAfter2Losses = 0
        var tradesAfter2Losses = 0
        
        var delaysAfterWin: [TimeInterval] = []
        var delaysAfterLoss: [TimeInterval] = []
        
        var revengeCount = 0
        
        guard sortedTrades.count > 1 else {
            return StreakAnalysis(
                currentWinStreak: currentWinStreak,
                currentLossStreak: currentLossStreak,
                maxWinStreak: maxWin,
                maxLossStreak: maxLoss,
                revengeTradesDetected: 0,
                winRateAfterWin: 0,
                winRateAfterLoss: 0,
                winRateAfter2Losses: 0,
                avgDelayAfterWin: 0,
                avgDelayAfterLoss: 0,
                tiltDetected: false
            )
        }

        for i in 1..<sortedTrades.count {
            let previousTrade = sortedTrades[i-1]
            let currentTrade = sortedTrades[i]
            
            guard let previousPnL = appState.netPnL(for: previousTrade),
                  let currentPnL = appState.netPnL(for: currentTrade) else { continue }
            
            let isWin = currentPnL > 0
            let previousWasWin = previousPnL > 0
            let delay = currentTrade.date.timeIntervalSince(previousTrade.date)
            
            // Après un win
            if previousWasWin {
                tradesAfterWin += 1
                if isWin { winsAfterWin += 1 }
                delaysAfterWin.append(delay)
            }
            
            // Après une loss
            if !previousWasWin {
                tradesAfterLoss += 1
                if isWin { winsAfterLoss += 1 }
                delaysAfterLoss.append(delay)
                
                // Détecter revenge trade (< 15 min après une perte)
                if delay < 900 { // 15 minutes
                    revengeCount += 1
                }
            }
            
            // Après 2 pertes consécutives
            if i >= 2 {
                let previousPrevious = sortedTrades[i-2]
                if let prevPrevPnL = appState.netPnL(for: previousPrevious),
                   prevPrevPnL <= 0 && previousPnL <= 0 {
                    tradesAfter2Losses += 1
                    if isWin { winsAfter2Losses += 1 }
                }
            }
        }
        
        let winRateAfterWin = tradesAfterWin > 0 ? Double(winsAfterWin) / Double(tradesAfterWin) : 0.0
        let winRateAfterLoss = tradesAfterLoss > 0 ? Double(winsAfterLoss) / Double(tradesAfterLoss) : 0.0
        let winRateAfter2Losses = tradesAfter2Losses > 0 ? Double(winsAfter2Losses) / Double(tradesAfter2Losses) : 0.0
        
        let avgDelayAfterWin = delaysAfterWin.isEmpty ? 0 : delaysAfterWin.reduce(0, +) / Double(delaysAfterWin.count)
        let avgDelayAfterLoss = delaysAfterLoss.isEmpty ? 0 : delaysAfterLoss.reduce(0, +) / Double(delaysAfterLoss.count)
        
        // Détecter le tilt : winRate après 2 pertes < 30% ET > 5 revenge trades
        let tiltDetected = winRateAfter2Losses < 0.30 && tradesAfter2Losses >= 5 && revengeCount >= 5
        
        return StreakAnalysis(
            currentWinStreak: currentWinStreak,
            currentLossStreak: currentLossStreak,
            maxWinStreak: maxWin,
            maxLossStreak: maxLoss,
            revengeTradesDetected: revengeCount,
            winRateAfterWin: winRateAfterWin,
            winRateAfterLoss: winRateAfterLoss,
            winRateAfter2Losses: winRateAfter2Losses,
            avgDelayAfterWin: avgDelayAfterWin,
            avgDelayAfterLoss: avgDelayAfterLoss,
            tiltDetected: tiltDetected
        )
    }
    
    private static func calculateMaxStreaks(_ trades: [Trade], appState: AppState) -> (maxWin: Int, maxLoss: Int) {
        var currentWin = 0
        var currentLoss = 0
        var maxWin = 0
        var maxLoss = 0
        
        for trade in trades {
            guard let pnl = appState.netPnL(for: trade) else { continue }
            
            if pnl > 0 {
                currentWin += 1
                currentLoss = 0
                maxWin = max(maxWin, currentWin)
            } else {
                currentLoss += 1
                currentWin = 0
                maxLoss = max(maxLoss, currentLoss)
            }
        }
        
        return (maxWin, maxLoss)
    }
}
