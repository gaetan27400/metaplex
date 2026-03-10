//
//  MTFAggregator.swift
//  Journal de trading 2025
//
//  Multi-timeframe alignment scoring module.
//  Uses existing timeframe snapshots (M5, M15, H1, H4) to calculate alignment.
//

import Foundation

struct MTFAggregatorResult {
    let score: Int // 0-100
    let bullishCount: Int
    let bearishCount: Int
    let neutralCount: Int
    let totalTF: Int
    let alignmentRatio: Double // -1 to 1

    func summary(isEN: Bool) -> String {
        var lines: [String] = []
        let alignment = Int(alignmentRatio * 100)

        if alignmentRatio > 0.6 {
            lines.append(isEN
                ? "Strong bullish alignment across \(bullishCount)/\(totalTF) timeframes."
                : "Fort alignement haussier sur \(bullishCount)/\(totalTF) timeframes.")
        } else if alignmentRatio > 0.2 {
            lines.append(isEN
                ? "Moderate bullish bias: \(bullishCount) bullish, \(bearishCount) bearish, \(neutralCount) neutral."
                : "Biais haussier modéré : \(bullishCount) haussier, \(bearishCount) baissier, \(neutralCount) neutre.")
        } else if alignmentRatio < -0.6 {
            lines.append(isEN
                ? "Strong bearish alignment across \(bearishCount)/\(totalTF) timeframes."
                : "Fort alignement baissier sur \(bearishCount)/\(totalTF) timeframes.")
        } else if alignmentRatio < -0.2 {
            lines.append(isEN
                ? "Moderate bearish bias: \(bearishCount) bearish, \(bullishCount) bullish, \(neutralCount) neutral."
                : "Biais baissier modéré : \(bearishCount) baissier, \(bullishCount) haussier, \(neutralCount) neutre.")
        } else {
            lines.append(isEN
                ? "Neutral/mixed alignment: \(bullishCount) bullish, \(bearishCount) bearish, \(neutralCount) neutral. No clear direction."
                : "Alignement neutre/mixte : \(bullishCount) haussier, \(bearishCount) baissier, \(neutralCount) neutre. Pas de direction claire.")
        }

        lines.append(isEN
            ? "MTF alignment score: \(score)/100 (alignment ratio: \(alignment)%)"
            : "Score alignement MTF : \(score)/100 (ratio : \(alignment)%)")

        return lines.joined(separator: "\n")
    }
}

final class MTFAggregator {

    func computeScore(
        mtfSnapshot: MTFSnapshot?,
        wtSnapshot: WTSnapshot?,
        vmcOscSnapshot: VMCOscillatorSnapshot?
    ) -> MTFAggregatorResult {

        var bullishCount = 0
        var bearishCount = 0
        var neutralCount = 0

        // Use MTF readings from the snapshot
        if let mtf = mtfSnapshot {
            let tfOrder: [VMCTimeframe] = [.m15, .h1, .h4, .d1]

            for tf in tfOrder {
                guard let reading = mtf.readings[tf] else { continue }
                switch reading.combinedSignal {
                case .buy, .bullish:
                    bullishCount += 1
                case .sell, .bearish:
                    bearishCount += 1
                case .neutral:
                    neutralCount += 1
                }
            }
        }

        // Add WT bias
        if let wt = wtSnapshot {
            switch wt.currentMarketBias {
            case .bullish: bullishCount += 1
            case .bearish: bearishCount += 1
            case .neutral: neutralCount += 1
            }
        }

        // Add VMC bias
        if let vmc = vmcOscSnapshot {
            if vmc.ribbonBull {
                bullishCount += 1
            } else if vmc.ribbonBear {
                bearishCount += 1
            } else {
                neutralCount += 1
            }
        }

        let totalTF = bullishCount + bearishCount + neutralCount
        guard totalTF > 0 else {
            return MTFAggregatorResult(
                score: 50, bullishCount: 0, bearishCount: 0, neutralCount: 0,
                totalTF: 0, alignmentRatio: 0
            )
        }

        // alignmentRatio = (bullish - bearish) / total, range [-1, 1]
        let alignmentRatio = Double(bullishCount - bearishCount) / Double(totalTF)

        // Convert to 0-100 score: -1 maps to 0, 0 maps to 50, +1 maps to 100
        let score = Int((alignmentRatio + 1.0) / 2.0 * 100.0)
        let clampedScore = max(0, min(100, score))

        return MTFAggregatorResult(
            score: clampedScore,
            bullishCount: bullishCount,
            bearishCount: bearishCount,
            neutralCount: neutralCount,
            totalTF: totalTF,
            alignmentRatio: alignmentRatio
        )
    }
}
