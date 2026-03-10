import Foundation

/// Calcule une "charge émotionnelle" (0..100) — une pression, pas un jugement.
///
/// Philosophie produit :
/// - **afterTrade** est la source principale (poids 1.0) car elle reflète l'impact réel.
/// - Les autres contextes sont des **modulateurs secondaires** (ils n'écrasent jamais afterTrade).
/// - Aucune notion "positif/négatif" : toutes les émotions contribuent à une charge.
final class EmotionalLoadService {
    // MARK: - Cache (anti-latence)
    actor Cache {
        struct Signature: Equatable {
            let tradesCount: Int
            let moodsCount: Int
            let maxTradeDate: TimeInterval
            let maxMoodDate: TimeInterval
        }
        
        private var lastSignature: Signature? = nil
        private var lastDailyScores: [Date: Double] = [:] // startOfDay -> 0..100
        
        func getIfValid(_ sig: Signature) -> [Date: Double]? {
            guard lastSignature == sig else { return nil }
            return lastDailyScores
        }
        
        func set(_ sig: Signature, scores: [Date: Double]) {
            lastSignature = sig
            lastDailyScores = scores
        }
    }
    
    private let cache = Cache()
    
    // MARK: - API
    func dailyLoadByDay(trades: [Trade], moods: [MoodEntry], calendar: Calendar = .current) async -> [Date: Double] {
        let sig = Cache.Signature(
            tradesCount: trades.count,
            moodsCount: moods.count,
            maxTradeDate: trades.map(\.date.timeIntervalSince1970).max() ?? 0,
            maxMoodDate: moods.map(\.timestamp.timeIntervalSince1970).max() ?? 0
        )
        
        if let cached = await cache.getIfValid(sig) {
            return cached
        }
        
        // Index rapide tradeId -> trade (pour l'exposition via leverage)
        let tradesById: [UUID: Trade] = Dictionary(uniqueKeysWithValues: trades.map { ($0.id, $0) })
        
        // Grouper les moods par jour
        let moodsByDay = Dictionary(grouping: moods) { calendar.startOfDay(for: $0.timestamp) }
        
        var out: [Date: Double] = [:]
        out.reserveCapacity(moodsByDay.count)
        
        for (day, dayMoods) in moodsByDay {
            let score = dayScore(dayMoods: dayMoods, tradesById: tradesById)
            if score > 0 {
                out[day] = score
            }
        }
        
        await cache.set(sig, scores: out)
        return out
    }
    
    // MARK: - Core (0..100)
    private func dayScore(dayMoods: [MoodEntry], tradesById: [UUID: Trade]) -> Double {
        // Weighted mean: afterTrade domine (poids 1.0), autres contextes faibles.
        var weightedSum = 0.0
        var weightSum = 0.0
        
        for mood in dayMoods {
            let wContext = contextWeight(mood.context)
            let load = entryLoad(mood: mood, tradesById: tradesById) // ~0..rawMax
            weightedSum += load * wContext
            weightSum += wContext
        }
        
        guard weightSum > 0 else { return 0 }
        let raw = weightedSum / weightSum
        
        // Normalisation stable -> 0..100 (borné)
        let normalized = (raw / rawMax) * 100.0
        return max(0, min(100, normalized))
    }
    
    /// Load brute d'une entrée (sans poids de contexte). Toujours positive.
    private func entryLoad(mood: MoodEntry, tradesById: [UUID: Trade]) -> Double {
        let base = max(emotionWeight(mood.emotionalState), triggerWeight(mood.trigger))
        let intensityFactor = max(0.1, min(1.0, Double(mood.intensity) / 10.0))
        let exposureFactor = exposureFactor(for: mood.tradeId.flatMap { tradesById[$0] })
        let executionFactor = executionFactor(for: mood)
        
        let raw = base * intensityFactor * exposureFactor * executionFactor
        return max(0, raw)
    }
    
    // MARK: - Weights / factors
    private func contextWeight(_ context: MoodContext) -> Double {
        switch context {
        case .afterTrade: return 1.0
        case .beforeTrade: return 0.4
        default: return 0.2 // duringMarket / endOfDay / afterLoss / afterWin -> modulateur
        }
    }
    
    /// Coefficients de "pression émotionnelle" (toujours positifs).
    /// Ajustables sans casser la logique métier des trades.
    private func emotionWeight(_ state: EmotionalState) -> Double {
        switch state {
        case .calm: return 0.2
        case .focused: return 0.3
        case .confident: return 0.5
        case .excited: return 0.8
        case .stressed: return 1.0
        case .fearful: return 1.1
        case .impatient: return 1.2
        case .frustrated: return 1.4
        // mapping pragmatique pour états existants non listés dans ton exemple
        case .greedy: return 1.0
        case .distracted: return 0.7
        }
    }
    
    private func triggerWeight(_ trigger: MoodTrigger?) -> Double {
        guard let trigger else { return 0 }
        switch trigger {
        case .fomo: return 1.6
        case .revenge: return 1.8
        case .loss: return 1.2
        case .overconfidence: return 1.0
        case .news: return 0.9
        case .fatigue: return 1.1
        case .externalStress: return 1.0
        default: return 0.8
        }
    }
    
    /// Proxy "exposition": on utilise le leverage du trade lié quand dispo (sans toucher au modèle).
    private func exposureFactor(for trade: Trade?) -> Double {
        let lev = max(1.0, trade?.leverage ?? 1.0)
        // 1.0 (spot) -> jusqu'à ~2.5 (lev très élevé), borné
        return min(2.5, 1.0 + (lev - 1.0) / 10.0)
    }
    
    /// Proxy "exécution": plus le contrôle est bas, plus la charge est élevée.
    /// (checklists => micro-modulations, sans jugement)
    private func executionFactor(for mood: MoodEntry) -> Double {
        var factor = 1.0
        
        if let control = mood.controlLevel {
            let c = max(0.0, min(10.0, Double(control)))
            // 10/10 -> ~1.0, 0/10 -> ~1.4
            factor *= (1.0 + (1.0 - (c / 10.0)) * 0.4)
        }
        
        // Checklist (avant trade) — modulateur léger
        if let checklist = mood.checklistBeforeTrade {
            let flags: [Bool] = [
                checklist.planClear,
                checklist.stopDefined,
                checklist.riskAccepted,
                checklist.noRevenge,
                checklist.noUrgency
            ]
            let missing = flags.filter { !$0 }.count
            factor *= (1.0 + min(0.25, Double(missing) * 0.05))
        }
        
        // Trigger "exceptionnel" -> légère surcouche (pression)
        if mood.isExceptional {
            factor *= 1.08
        }
        
        return min(1.8, max(0.8, factor))
    }
    
    /// Plafond brut "théorique" pour normaliser de manière stable.
    /// (On préfère un max fixe à un max dynamique pour éviter un graphique qui "bouge" trop visuellement.)
    private var rawMax: Double {
        // base (1.8 revenge) * intensity(1) * exposure(2.5) * execution(1.8) ~= 8.1
        8.1
    }
}


