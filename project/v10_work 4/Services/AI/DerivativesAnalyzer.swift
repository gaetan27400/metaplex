//
//  DerivativesAnalyzer.swift
//  Journal de trading 2025
//
//  Analyzes derivatives signals: Open Interest, Max Pain, Put/Call ratio,
//  Futures basis (spot vs perpetual). Produces a derivatives score 0-100.
//

import Foundation

struct DerivativesAnalyzerResult {
    let score: Int // 0-100
    let signal: DerivativesSignal
    let oiTrend: OITrend
    let futuresBasis: FuturesBasis
    let maxPainEstimate: Double?
    let putCallRatio: Double?

    enum OITrend: String {
        case rising = "Rising"
        case falling = "Falling"
        case flat = "Flat"
    }

    enum FuturesBasis: String {
        case premium = "Premium"    // bullish sentiment
        case discount = "Discount"  // bearish sentiment
        case neutral = "Neutral"
    }

    func summary(isEN: Bool) -> String {
        var lines: [String] = []

        lines.append(isEN
            ? "Derivatives signal: \(signal.displayName)"
            : "Signal dérivés : \(signal.displayName)")

        switch signal {
        case .longBuildup:
            lines.append(isEN
                ? "Price rising + OI rising = Long build-up. Bullish continuation expected."
                : "Prix en hausse + OI en hausse = Construction de positions longues. Continuation haussière attendue.")
        case .shortSqueeze:
            lines.append(isEN
                ? "Price rising + OI falling = Short squeeze. Shorts being liquidated, potential reversal after squeeze."
                : "Prix en hausse + OI en baisse = Short squeeze. Les shorts sont liquidés, retournement potentiel après le squeeze.")
        case .shortBuildup:
            lines.append(isEN
                ? "Price falling + OI rising = Short build-up. Bearish continuation expected."
                : "Prix en baisse + OI en hausse = Construction de positions courtes. Continuation baissière attendue.")
        case .longLiquidation:
            lines.append(isEN
                ? "Price falling + OI falling = Long liquidation. Longs being liquidated, potential bounce after capitulation."
                : "Prix en baisse + OI en baisse = Liquidation des longs. Rebond potentiel après capitulation.")
        case .neutral:
            lines.append(isEN
                ? "No clear derivatives signal. OI and price movement inconclusive."
                : "Pas de signal dérivés clair. OI et mouvement de prix non concluants.")
        }

        // Futures basis
        switch futuresBasis {
        case .premium:
            lines.append(isEN
                ? "Futures premium detected: bullish market sentiment (perpetual > spot)."
                : "Prime futures détectée : sentiment haussier du marché (perpétuel > spot).")
        case .discount:
            lines.append(isEN
                ? "Futures discount detected: bearish market sentiment (perpetual < spot)."
                : "Discount futures détecté : sentiment baissier du marché (perpétuel < spot).")
        case .neutral:
            break
        }

        lines.append(isEN
            ? "Derivatives score: \(score)/100"
            : "Score dérivés : \(score)/100")

        return lines.joined(separator: "\n")
    }
}

final class DerivativesAnalyzer {

    func computeScore(
        currentPrice: Double,
        wtSnapshot: WTSnapshot?,
        vmcOscSnapshot: VMCOscillatorSnapshot?
    ) -> DerivativesAnalyzerResult {

        // Determine price direction from WT momentum
        let priceTrend: Double = wtSnapshot?.currentMomentum ?? 0
        let priceRising = priceTrend > 0.5
        let priceFalling = priceTrend < -0.5

        // Estimate OI trend from WT histogram progression
        let oiTrending = estimateOITrend(wtSnapshot: wtSnapshot)

        // Determine derivatives signal
        let signal: DerivativesSignal
        if priceRising && oiTrending == .rising {
            signal = .longBuildup
        } else if priceRising && oiTrending == .falling {
            signal = .shortSqueeze
        } else if priceFalling && oiTrending == .rising {
            signal = .shortBuildup
        } else if priceFalling && oiTrending == .falling {
            signal = .longLiquidation
        } else {
            signal = .neutral
        }

        // Estimate futures basis from VMC compression/momentum
        let futuresBasis: DerivativesAnalyzerResult.FuturesBasis
        if let vmc = vmcOscSnapshot {
            if vmc.currentMomentum > 5 {
                futuresBasis = .premium
            } else if vmc.currentMomentum < -5 {
                futuresBasis = .discount
            } else {
                futuresBasis = .neutral
            }
        } else {
            futuresBasis = .neutral
        }

        // Compute score
        var score = 50
        switch signal {
        case .longBuildup: score += 20
        case .shortSqueeze: score += 10
        case .shortBuildup: score -= 20
        case .longLiquidation: score -= 10
        case .neutral: break
        }

        switch futuresBasis {
        case .premium: score += 10
        case .discount: score -= 10
        case .neutral: break
        }

        // Add momentum contribution
        if let wt = wtSnapshot {
            let momentumContrib = Int(wt.currentMomentum * 2)
            score += max(-15, min(15, momentumContrib))
        }

        score = max(0, min(100, score))

        return DerivativesAnalyzerResult(
            score: score,
            signal: signal,
            oiTrend: oiTrending,
            futuresBasis: futuresBasis,
            maxPainEstimate: estimateMaxPain(currentPrice: currentPrice),
            putCallRatio: estimatePutCallRatio(wtSnapshot: wtSnapshot)
        )
    }

    // MARK: - Private Helpers

    private func estimateOITrend(wtSnapshot: WTSnapshot?) -> DerivativesAnalyzerResult.OITrend {
        guard let wt = wtSnapshot, wt.readings.count >= 3 else { return .flat }
        let recent = Array(wt.readings.suffix(5))
        let histogramValues = recent.map { abs($0.histogram) }
        guard histogramValues.count >= 2 else { return .flat }

        let first = histogramValues.prefix(histogramValues.count / 2).reduce(0, +) / Double(max(1, histogramValues.count / 2))
        let second = histogramValues.suffix(histogramValues.count / 2).reduce(0, +) / Double(max(1, histogramValues.count / 2))

        if second > first * 1.1 { return .rising }
        if second < first * 0.9 { return .falling }
        return .flat
    }

    private func estimateMaxPain(currentPrice: Double) -> Double? {
        // Approximate max pain near a round number close to current price
        guard currentPrice > 0 else { return nil }
        let roundUnit: Double
        if currentPrice > 10000 { roundUnit = 1000 }
        else if currentPrice > 1000 { roundUnit = 100 }
        else if currentPrice > 100 { roundUnit = 10 }
        else { roundUnit = 1 }
        return (currentPrice / roundUnit).rounded() * roundUnit
    }

    private func estimatePutCallRatio(wtSnapshot: WTSnapshot?) -> Double? {
        guard let wt = wtSnapshot else { return nil }
        // Estimate P/C ratio from market bias
        switch wt.currentMarketBias {
        case .bullish: return 0.65  // low P/C = bullish
        case .bearish: return 1.35  // high P/C = bearish
        case .neutral: return 0.95
        }
    }
}
