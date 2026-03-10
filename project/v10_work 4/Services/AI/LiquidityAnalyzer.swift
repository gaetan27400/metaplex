//
//  LiquidityAnalyzer.swift
//  Journal de trading 2025
//
//  Liquidation cluster detection and liquidity pressure scoring.
//  Detects major liquidation clusters and cascade potential zones.
//

import Foundation

struct LiquidityAnalyzerResult {
    let score: Int // 0-100
    let clusters: [LiquidationCluster]
    let dominantSide: LiquiditySide
    let cascadeRiskLevel: CascadeRisk
    let nearestClusterAbove: LiquidationCluster?
    let nearestClusterBelow: LiquidationCluster?

    enum LiquiditySide: String {
        case longHeavy = "Long Heavy"   // more liquidity below = price magnet down
        case shortHeavy = "Short Heavy" // more liquidity above = price magnet up
        case balanced = "Balanced"
    }

    enum CascadeRisk: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }

    func summary(isEN: Bool, currentPrice: Double) -> String {
        var lines: [String] = []

        if clusters.isEmpty {
            return isEN
                ? "No significant liquidation clusters detected."
                : "Aucun cluster de liquidation significatif détecté."
        }

        lines.append(isEN
            ? "Liquidation clusters detected: \(clusters.count)"
            : "Clusters de liquidation détectés : \(clusters.count)")

        // Report top clusters
        for cluster in clusters.prefix(4) {
            let direction = cluster.price > currentPrice
                ? (isEN ? "above" : "au-dessus")
                : (isEN ? "below" : "en-dessous")
            let cascadeStr = cluster.cascadeRisk
                ? (isEN ? " [CASCADE RISK]" : " [RISQUE CASCADE]")
                : ""
            lines.append("  \(String(format: "%.0f", cluster.price)) — \(cluster.formattedVolume) (\(direction))\(cascadeStr)")
        }

        // Cascade risk
        switch cascadeRiskLevel {
        case .high:
            lines.append(isEN
                ? "CASCADE RISK HIGH: Large cluster near price. If broken, chain liquidation likely."
                : "RISQUE CASCADE ÉLEVÉ : Gros cluster proche du prix. Si cassé, liquidation en chaîne probable.")
        case .medium:
            lines.append(isEN
                ? "Moderate cascade risk: Significant clusters within range."
                : "Risque cascade modéré : Clusters significatifs dans la zone.")
        case .low:
            break
        }

        lines.append(isEN
            ? "Liquidity pressure score: \(score)/100 (\(dominantSide.rawValue))"
            : "Score pression liquidité : \(score)/100 (\(dominantSide.rawValue))")

        return lines.joined(separator: "\n")
    }
}

final class LiquidityAnalyzer {

    func computeScore(
        currentPrice: Double,
        liquidityZones: [(price: Double, volume: Double, side: String)]?
    ) -> LiquidityAnalyzerResult {

        guard let zones = liquidityZones, !zones.isEmpty, currentPrice > 0 else {
            return LiquidityAnalyzerResult(
                score: 50,
                clusters: [],
                dominantSide: .balanced,
                cascadeRiskLevel: .low,
                nearestClusterAbove: nil,
                nearestClusterBelow: nil
            )
        }

        // Build clusters from zones
        var clusters: [LiquidationCluster] = []
        var volumeAbove: Double = 0
        var volumeBelow: Double = 0

        for zone in zones {
            let distancePercent = abs(zone.price - currentPrice) / currentPrice * 100
            let cascadeRisk = distancePercent < 2.0 && zone.volume > 1_000_000
            let side = zone.price > currentPrice ? "short" : "long"

            let cluster = LiquidationCluster(
                price: zone.price,
                volume: zone.volume,
                side: side,
                cascadeRisk: cascadeRisk
            )
            clusters.append(cluster)

            if zone.price > currentPrice {
                volumeAbove += zone.volume
            } else {
                volumeBelow += zone.volume
            }
        }

        // Sort by volume descending
        clusters.sort { $0.volume > $1.volume }

        // Determine dominant side
        let totalVolume = volumeAbove + volumeBelow
        let dominantSide: LiquidityAnalyzerResult.LiquiditySide
        if totalVolume > 0 {
            let ratio = volumeAbove / totalVolume
            if ratio > 0.6 {
                dominantSide = .shortHeavy // more liquidity above = shorts clustered = price magnet up
            } else if ratio < 0.4 {
                dominantSide = .longHeavy  // more liquidity below = longs clustered = price magnet down
            } else {
                dominantSide = .balanced
            }
        } else {
            dominantSide = .balanced
        }

        // Cascade risk
        let hasCascade = clusters.contains { $0.cascadeRisk }
        let cascadeRiskLevel: LiquidityAnalyzerResult.CascadeRisk
        if hasCascade && clusters.first(where: { $0.cascadeRisk })?.volume ?? 0 > 5_000_000 {
            cascadeRiskLevel = .high
        } else if hasCascade {
            cascadeRiskLevel = .medium
        } else {
            cascadeRiskLevel = .low
        }

        // Nearest clusters
        let nearestAbove = clusters
            .filter { $0.price > currentPrice }
            .min { abs($0.price - currentPrice) < abs($1.price - currentPrice) }
        let nearestBelow = clusters
            .filter { $0.price < currentPrice }
            .min { abs($0.price - currentPrice) < abs($1.price - currentPrice) }

        // Score: balanced = 50, bullish imbalance (more shorts above) = higher, bearish = lower
        var score = 50
        switch dominantSide {
        case .shortHeavy: score += 15 // price likely pushed up to grab short liquidity
        case .longHeavy: score -= 15  // price likely pushed down to grab long liquidity
        case .balanced: break
        }

        switch cascadeRiskLevel {
        case .high: score += 10  // big moves expected = opportunity
        case .medium: score += 5
        case .low: break
        }

        score = max(0, min(100, score))

        return LiquidityAnalyzerResult(
            score: score,
            clusters: clusters,
            dominantSide: dominantSide,
            cascadeRiskLevel: cascadeRiskLevel,
            nearestClusterAbove: nearestAbove,
            nearestClusterBelow: nearestBelow
        )
    }
}
