//
//  CorrelationAnalyzer.swift
//  Journal de trading 2025
//
//  Crypto correlation engine using ETH/BTC ratio, BTC dominance,
//  and relative strength analysis to detect the best trading candidate.
//

import Foundation

struct CorrelationAnalyzerResult {
    let score: Int // 0-100
    let result: CorrelationResult?

    func summary(isEN: Bool) -> String {
        guard let result = result else {
            return isEN
                ? "Correlation analysis unavailable."
                : "Analyse de corrélation indisponible."
        }

        var lines: [String] = []

        // ETH/BTC trend
        switch result.ethBtcTrend {
        case .rising:
            lines.append(isEN
                ? "ETH/BTC ratio rising: ETH showing relative strength vs BTC. Altcoin rotation possible."
                : "Ratio ETH/BTC en hausse : ETH montre une force relative vs BTC. Rotation altcoins possible.")
        case .falling:
            lines.append(isEN
                ? "ETH/BTC ratio falling: BTC dominant. Capital flowing into BTC."
                : "Ratio ETH/BTC en baisse : BTC dominant. Capital se concentre sur BTC.")
        case .flat:
            lines.append(isEN
                ? "ETH/BTC ratio stable: No clear relative strength shift."
                : "Ratio ETH/BTC stable : Pas de changement de force relative.")
        }

        // BTC Dominance
        switch result.btcDominanceTrend {
        case .rising:
            lines.append(isEN
                ? "BTC dominance rising: Risk-off mode. Altcoin weakness expected."
                : "Dominance BTC en hausse : Mode risk-off. Faiblesse altcoins attendue.")
        case .falling:
            lines.append(isEN
                ? "BTC dominance falling: Risk-on mode. Altcoin strength expected."
                : "Dominance BTC en baisse : Mode risk-on. Force altcoins attendue.")
        case .flat:
            lines.append(isEN
                ? "BTC dominance stable: Mixed conditions."
                : "Dominance BTC stable : Conditions mixtes.")
        }

        lines.append(isEN
            ? "Best trading candidate: \(result.bestCandidate)"
            : "Meilleur candidat de trading : \(result.bestCandidate)")

        lines.append(isEN
            ? "Correlation score: \(score)/100"
            : "Score corrélation : \(score)/100")

        return lines.joined(separator: "\n")
    }
}

final class CorrelationAnalyzer {

    func computeScore(
        symbol: String,
        mtfSnapshot: MTFSnapshot?
    ) -> CorrelationAnalyzerResult {

        guard let mtf = mtfSnapshot else {
            return CorrelationAnalyzerResult(score: 50, result: nil)
        }

        // Determine relative strength using MTF data
        let score = mtf.globalCombinedScore // -100 to +100
        let isBTC = symbol.uppercased().hasPrefix("BTC")
        let isETH = symbol.uppercased().hasPrefix("ETH")

        // Infer ETH/BTC trend from the analyzed symbol's strength
        let ethBtcTrend: CorrelationResult.TrendDirection
        let btcDominanceTrend: CorrelationResult.TrendDirection

        if isBTC {
            // If analyzing BTC, assume BTC dominance is relevant
            ethBtcTrend = score > 20 ? .falling : score < -20 ? .rising : .flat
            btcDominanceTrend = score > 0 ? .rising : score < 0 ? .falling : .flat
        } else if isETH {
            ethBtcTrend = score > 0 ? .rising : score < 0 ? .falling : .flat
            btcDominanceTrend = score > 20 ? .falling : score < -20 ? .rising : .flat
        } else {
            // Altcoin: strong altcoin = ETH/BTC rising, dominance falling
            ethBtcTrend = score > 20 ? .rising : score < -20 ? .falling : .flat
            btcDominanceTrend = score > 20 ? .falling : score < -20 ? .rising : .flat
        }

        // Determine best candidate
        let bestCandidate: String
        if isBTC && score > 20 {
            bestCandidate = "BTC"
        } else if isETH && score > 20 {
            bestCandidate = "ETH"
        } else if score > 20 {
            // Extract symbol name
            let cleaned = symbol.replacingOccurrences(of: "USDT", with: "")
                .replacingOccurrences(of: "USD", with: "")
            bestCandidate = cleaned
        } else {
            bestCandidate = "BTC" // Default to BTC in uncertain conditions
        }

        let relativeStrength = score // already -100 to 100

        let correlationResult = CorrelationResult(
            ethBtcTrend: ethBtcTrend,
            btcDominanceTrend: btcDominanceTrend,
            bestCandidate: bestCandidate,
            relativeStrength: relativeStrength
        )

        // Convert relative strength to 0-100 score
        let normalizedScore = Int((relativeStrength + 100) / 2)
        let clampedScore = max(0, min(100, normalizedScore))

        return CorrelationAnalyzerResult(
            score: clampedScore,
            result: correlationResult
        )
    }
}
