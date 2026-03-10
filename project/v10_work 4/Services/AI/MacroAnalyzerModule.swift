//
//  MacroAnalyzerModule.swift
//  Journal de trading 2025
//
//  Macro analysis module that integrates economic calendar data
//  and macro sentiment into the AI scoring engine.
//

import Foundation

struct MacroAnalyzerResult {
    let score: Int // 0-100
    let riskLevel: MacroRiskLevel
    let sentiment: MacroSentiment
    let criticalEventsCount: Int
    let etfFlowSignal: ETFFlowSignal

    enum MacroRiskLevel: String {
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        case critical = "Critical"
    }

    enum MacroSentiment: String {
        case bullish = "Bullish"
        case neutral = "Neutral"
        case bearish = "Bearish"
    }

    enum ETFFlowSignal: String {
        case positive = "Positive"
        case neutral = "Neutral"
        case negative = "Negative"
    }

    func summary(isEN: Bool) -> String {
        var lines: [String] = []

        // Risk level
        switch riskLevel {
        case .low:
            lines.append(isEN
                ? "Macro risk: LOW. No critical events. Favorable for trading."
                : "Risque macro : BAS. Pas d'événements critiques. Favorable au trading.")
        case .moderate:
            lines.append(isEN
                ? "Macro risk: MODERATE. Some events to watch. Normal position sizing."
                : "Risque macro : MODÉRÉ. Quelques événements à surveiller. Taille de position normale.")
        case .high:
            lines.append(isEN
                ? "Macro risk: HIGH. \(criticalEventsCount) critical event(s). Reduce exposure."
                : "Risque macro : ÉLEVÉ. \(criticalEventsCount) événement(s) critique(s). Réduire l'exposition.")
        case .critical:
            lines.append(isEN
                ? "Macro risk: CRITICAL. Major announcements imminent. Minimize trading."
                : "Risque macro : CRITIQUE. Annonces majeures imminentes. Minimiser le trading.")
        }

        // Sentiment
        switch sentiment {
        case .bullish:
            lines.append(isEN
                ? "Macro sentiment: Bullish. Economic data supports risk-on."
                : "Sentiment macro : Haussier. Données économiques favorables au risk-on.")
        case .bearish:
            lines.append(isEN
                ? "Macro sentiment: Bearish. Economic headwinds detected."
                : "Sentiment macro : Baissier. Vents contraires économiques détectés.")
        case .neutral:
            lines.append(isEN
                ? "Macro sentiment: Neutral. Mixed economic signals."
                : "Sentiment macro : Neutre. Signaux économiques mixtes.")
        }

        // ETF flows
        switch etfFlowSignal {
        case .positive:
            lines.append(isEN
                ? "ETF flows: Positive. Institutional inflows supporting BTC price."
                : "Flux ETF : Positifs. Afflux institutionnels soutenant le prix du BTC.")
        case .negative:
            lines.append(isEN
                ? "ETF flows: Negative. Institutional outflows pressuring price."
                : "Flux ETF : Négatifs. Sorties institutionnelles pesant sur le prix.")
        case .neutral:
            break
        }

        lines.append(isEN
            ? "Macro score: \(score)/100"
            : "Score macro : \(score)/100")

        return lines.joined(separator: "\n")
    }
}

final class MacroAnalyzer {

    func computeScore(
        economicRiskAnalysis: MarketRiskAnalysis?
    ) -> MacroAnalyzerResult {

        guard let eco = economicRiskAnalysis else {
            return MacroAnalyzerResult(
                score: 50,
                riskLevel: .moderate,
                sentiment: .neutral,
                criticalEventsCount: 0,
                etfFlowSignal: .neutral
            )
        }

        // Map risk level
        let riskLevel: MacroAnalyzerResult.MacroRiskLevel
        switch eco.riskLevel {
        case .critical, .veryHigh:
            riskLevel = .critical
        case .high:
            riskLevel = .high
        case .moderate, .elevated:
            riskLevel = .moderate
        default:
            riskLevel = .low
        }

        // Map sentiment
        let sentiment: MacroAnalyzerResult.MacroSentiment
        switch eco.marketSentiment {
        case .bullish:
            sentiment = .bullish
        case .bearish:
            sentiment = .bearish
        default:
            sentiment = .neutral
        }

        // Count critical events
        let criticalEvents = eco.events.filter {
            ($0.category ?? .other) == .interestRate ||
            ($0.category ?? .other) == .inflation ||
            ($0.category ?? .other) == .employment
        }

        // ETF flow signal from crypto recommendations
        let etfFlowSignal: MacroAnalyzerResult.ETFFlowSignal
        if let cryptoRec = eco.marketRecommendations.first(where: { $0.market == "Crypto" }) {
            switch cryptoRec.sentiment {
            case .bullish: etfFlowSignal = .positive
            case .bearish: etfFlowSignal = .negative
            default: etfFlowSignal = .neutral
            }
        } else {
            etfFlowSignal = .neutral
        }

        // Compute score
        var score = 50

        switch sentiment {
        case .bullish: score += 20
        case .bearish: score -= 20
        case .neutral: break
        }

        switch riskLevel {
        case .low: score += 10
        case .moderate: break
        case .high: score -= 10
        case .critical: score -= 25
        }

        switch etfFlowSignal {
        case .positive: score += 10
        case .negative: score -= 10
        case .neutral: break
        }

        // Critical events penalty
        score -= min(15, criticalEvents.count * 5)

        score = max(0, min(100, score))

        return MacroAnalyzerResult(
            score: score,
            riskLevel: riskLevel,
            sentiment: sentiment,
            criticalEventsCount: criticalEvents.count,
            etfFlowSignal: etfFlowSignal
        )
    }
}
