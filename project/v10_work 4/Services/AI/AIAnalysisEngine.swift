//
//  AIAnalysisEngine.swift
//  Journal de trading 2025
//
//  Structured AI scoring engine that aggregates multiple analysis components
//  and produces deterministic scoring before GPT explanation generation.
//

import Foundation

// MARK: - Wyckoff Phase

enum WyckoffPhase: String, Codable, CaseIterable {
    case accumulation = "Accumulation"
    case markup = "Markup"
    case distribution = "Distribution"
    case markdown = "Markdown"
    case unknown = "Unknown"

    var displayName: String { rawValue }

    var emoji: String {
        switch self {
        case .accumulation: return "🟢"
        case .markup: return "🚀"
        case .distribution: return "🔴"
        case .markdown: return "📉"
        case .unknown: return "❓"
        }
    }
}

// MARK: - Trade Bias

enum TradeBias: String, Codable {
    case strongBullish = "Strong Bullish"
    case bullish = "Bullish"
    case neutral = "Neutral"
    case bearish = "Bearish"
    case strongBearish = "Strong Bearish"

    var displayName: String { rawValue }

    var emoji: String {
        switch self {
        case .strongBullish: return "🟢🟢"
        case .bullish: return "🟢"
        case .neutral: return "⚪"
        case .bearish: return "🔴"
        case .strongBearish: return "🔴🔴"
        }
    }
}

// MARK: - Derivatives Signal

enum DerivativesSignal: String, Codable {
    case longBuildup = "Long Build-up"
    case shortSqueeze = "Short Squeeze"
    case shortBuildup = "Short Build-up"
    case longLiquidation = "Long Liquidation"
    case neutral = "Neutral"

    var displayName: String { rawValue }
}

// MARK: - Liquidation Cluster

struct LiquidationCluster: Equatable {
    let price: Double
    let volume: Double
    let side: String // "long" or "short"
    let cascadeRisk: Bool

    var formattedVolume: String {
        if volume >= 1_000_000_000 {
            return String(format: "%.1fB", volume / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "%.0fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.0fK", volume / 1_000)
        }
        return String(format: "%.0f", volume)
    }
}

// MARK: - Correlation Result

struct CorrelationResult: Equatable {
    let ethBtcTrend: TrendDirection
    let btcDominanceTrend: TrendDirection
    let bestCandidate: String
    let relativeStrength: Double // -100 to 100

    enum TrendDirection: String {
        case rising = "Rising"
        case falling = "Falling"
        case flat = "Flat"
    }
}

// MARK: - Trader Stats

struct TraderPerformanceStats: Equatable {
    let totalTrades: Int
    let overallWinRate: Double
    let averageRR: Double
    let bestSetup: SetupStats?
    let worstSetup: SetupStats?
    let setupStats: [SetupStats]
    let recentBias: TradeBias

    struct SetupStats: Equatable, Identifiable {
        let id: UUID
        let name: String
        let winRate: Double
        let averageRR: Double
        let tradeCount: Int
        let totalPnL: Double
    }
}

// MARK: - AI Analysis Result

struct AIAnalysisResult: Equatable {
    var totalScore: Int // 0-100

    var mtfAlignmentScore: Int // 0-100
    var derivativesScore: Int // 0-100
    var liquidityScore: Int // 0-100
    var macroScore: Int // 0-100
    var correlationScore: Int // 0-100

    var detectedMarketPhase: WyckoffPhase
    var tradeBias: TradeBias

    // Detailed components
    var derivativesSignal: DerivativesSignal
    var liquidationClusters: [LiquidationCluster]
    var correlationResult: CorrelationResult?
    var traderStats: TraderPerformanceStats?

    // Contextual data for GPT prompt
    var mtfSummary: String
    var derivativesSummary: String
    var liquiditySummary: String
    var macroSummary: String
    var correlationSummary: String
    var wyckoffSummary: String
    var traderStatsSummary: String

    static let empty = AIAnalysisResult(
        totalScore: 50,
        mtfAlignmentScore: 50,
        derivativesScore: 50,
        liquidityScore: 50,
        macroScore: 50,
        correlationScore: 50,
        detectedMarketPhase: .unknown,
        tradeBias: .neutral,
        derivativesSignal: .neutral,
        liquidationClusters: [],
        correlationResult: nil,
        traderStats: nil,
        mtfSummary: "",
        derivativesSummary: "",
        liquiditySummary: "",
        macroSummary: "",
        correlationSummary: "",
        wyckoffSummary: "",
        traderStatsSummary: ""
    )
}

// MARK: - AI Analysis Engine

@MainActor
final class AIAnalysisEngine {

    // Sub-modules
    private let mtfAggregator = MTFAggregator()
    private let derivativesAnalyzer = DerivativesAnalyzer()
    private let liquidityAnalyzer = LiquidityAnalyzer()
    private let correlationAnalyzer = CorrelationAnalyzer()
    private let macroAnalyzer = MacroAnalyzer()
    private let traderStatsEngine = TraderStatsEngine()

    // MARK: - Run Full Analysis

    func runAnalysis(
        symbol: String,
        currentPrice: Double,
        mtfSnapshot: MTFSnapshot?,
        wtSnapshot: WTSnapshot?,
        vmcOscSnapshot: VMCOscillatorSnapshot?,
        liquidityZones: [(price: Double, volume: Double, side: String)]?,
        economicRiskAnalysis: MarketRiskAnalysis?,
        trades: [Trade],
        systems: [TradingSystem],
        appState: AppState?,
        language: Localizable.Language = .french
    ) -> AIAnalysisResult {

        let isEN = language == .english

        // 1. MTF Alignment Score
        let mtfResult = mtfAggregator.computeScore(
            mtfSnapshot: mtfSnapshot,
            wtSnapshot: wtSnapshot,
            vmcOscSnapshot: vmcOscSnapshot
        )

        // 2. Derivatives Score
        let derivResult = derivativesAnalyzer.computeScore(
            currentPrice: currentPrice,
            wtSnapshot: wtSnapshot,
            vmcOscSnapshot: vmcOscSnapshot
        )

        // 3. Liquidity Score
        let liqResult = liquidityAnalyzer.computeScore(
            currentPrice: currentPrice,
            liquidityZones: liquidityZones
        )

        // 4. Correlation Score
        let corrResult = correlationAnalyzer.computeScore(
            symbol: symbol,
            mtfSnapshot: mtfSnapshot
        )

        // 5. Macro Score
        let macroResult = macroAnalyzer.computeScore(
            economicRiskAnalysis: economicRiskAnalysis
        )

        // 6. Wyckoff Phase
        let wyckoffPhase = detectWyckoffPhase(
            mtfSnapshot: mtfSnapshot,
            wtSnapshot: wtSnapshot,
            vmcOscSnapshot: vmcOscSnapshot,
            currentPrice: currentPrice
        )

        // 7. Trader Stats
        let traderStats = traderStatsEngine.computeStats(
            trades: trades,
            systems: systems,
            appState: appState
        )

        // Compute total score (weighted average)
        let totalScore = computeTotalScore(
            mtf: mtfResult.score,
            derivatives: derivResult.score,
            liquidity: liqResult.score,
            macro: macroResult.score,
            correlation: corrResult.score
        )

        // Determine trade bias
        let tradeBias = determineTradeBias(totalScore: totalScore, mtfScore: mtfResult.score)

        // Build summaries
        let mtfSummary = mtfResult.summary(isEN: isEN)
        let derivSummary = derivResult.summary(isEN: isEN)
        let liqSummary = liqResult.summary(isEN: isEN, currentPrice: currentPrice)
        let macroSummary = macroResult.summary(isEN: isEN)
        let corrSummary = corrResult.summary(isEN: isEN)
        let wyckoffSummary = buildWyckoffSummary(phase: wyckoffPhase, isEN: isEN)
        let traderSummary = buildTraderStatsSummary(stats: traderStats, isEN: isEN)

        return AIAnalysisResult(
            totalScore: totalScore,
            mtfAlignmentScore: mtfResult.score,
            derivativesScore: derivResult.score,
            liquidityScore: liqResult.score,
            macroScore: macroResult.score,
            correlationScore: corrResult.score,
            detectedMarketPhase: wyckoffPhase,
            tradeBias: tradeBias,
            derivativesSignal: derivResult.signal,
            liquidationClusters: liqResult.clusters,
            correlationResult: corrResult.result,
            traderStats: traderStats,
            mtfSummary: mtfSummary,
            derivativesSummary: derivSummary,
            liquiditySummary: liqSummary,
            macroSummary: macroSummary,
            correlationSummary: corrSummary,
            wyckoffSummary: wyckoffSummary,
            traderStatsSummary: traderSummary
        )
    }

    // MARK: - Total Score Computation

    private func computeTotalScore(
        mtf: Int, derivatives: Int, liquidity: Int, macro: Int, correlation: Int
    ) -> Int {
        // Weights: MTF 35%, Derivatives 20%, Liquidity 15%, Macro 15%, Correlation 15%
        let weighted = Double(mtf) * 0.35
            + Double(derivatives) * 0.20
            + Double(liquidity) * 0.15
            + Double(macro) * 0.15
            + Double(correlation) * 0.15
        return max(0, min(100, Int(weighted)))
    }

    // MARK: - Trade Bias

    private func determineTradeBias(totalScore: Int, mtfScore: Int) -> TradeBias {
        let avg = (totalScore + mtfScore) / 2
        if avg >= 80 { return .strongBullish }
        if avg >= 60 { return .bullish }
        if avg >= 40 { return .neutral }
        if avg >= 20 { return .bearish }
        return .strongBearish
    }

    // MARK: - Wyckoff Phase Detection

    private func detectWyckoffPhase(
        mtfSnapshot: MTFSnapshot?,
        wtSnapshot: WTSnapshot?,
        vmcOscSnapshot: VMCOscillatorSnapshot?,
        currentPrice: Double
    ) -> WyckoffPhase {
        guard let mtf = mtfSnapshot else { return .unknown }

        let score = mtf.globalCombinedScore // -100 to +100
        let confluence = mtf.confluencePercent // 0-100
        let isTurningUp = mtf.isTurningUp
        let isTurningDown = mtf.isTurningDown
        let momentum = wtSnapshot?.currentMomentum ?? 0
        let vmcCompression = vmcOscSnapshot?.compression ?? false

        // Accumulation: low scores, turning up, low confluence (range-bound), compression
        if score < -20 && (isTurningUp || vmcCompression) && confluence < 50 {
            return .accumulation
        }

        // Markup: bullish scores, high confluence, growing momentum
        if score > 20 && confluence > 50 && momentum > 0 {
            return .markup
        }

        // Distribution: high scores, turning down, decreasing momentum, low confluence
        if score > 20 && (isTurningDown || momentum < 0) && confluence < 50 {
            return .distribution
        }

        // Markdown: bearish scores, high confluence, falling momentum
        if score < -20 && confluence > 50 && momentum < 0 {
            return .markdown
        }

        // Edge cases with WT/VMC
        if let wt = wtSnapshot {
            if wt.isOversold && isTurningUp { return .accumulation }
            if wt.isOverbought && isTurningDown { return .distribution }
        }

        return .unknown
    }

    // MARK: - Summary Builders

    private func buildWyckoffSummary(phase: WyckoffPhase, isEN: Bool) -> String {
        switch phase {
        case .accumulation:
            return isEN
                ? "Market phase: Accumulation. Institutional buyers absorbing supply in a range. Watch for Spring/breakout."
                : "Phase de marché : Accumulation. Les institutionnels absorbent l'offre dans un range. Surveiller le Spring/cassure."
        case .markup:
            return isEN
                ? "Market phase: Markup. Strong uptrend with institutional participation. Look for pullback entries."
                : "Phase de marché : Markup. Forte tendance haussière avec participation institutionnelle. Chercher des entrées sur replis."
        case .distribution:
            return isEN
                ? "Market phase: Distribution. Institutional sellers distributing to retail. Watch for UTAD/breakdown."
                : "Phase de marché : Distribution. Les institutionnels distribuent aux particuliers. Surveiller le UTAD/cassure baissière."
        case .markdown:
            return isEN
                ? "Market phase: Markdown. Strong downtrend with institutional selling. Avoid long positions, look for short setups."
                : "Phase de marché : Markdown. Forte tendance baissière avec vente institutionnelle. Éviter les positions longues."
        case .unknown:
            return isEN
                ? "Market phase: Undetermined. Insufficient data for phase detection."
                : "Phase de marché : Indéterminée. Données insuffisantes pour la détection de phase."
        }
    }

    private func buildTraderStatsSummary(stats: TraderPerformanceStats?, isEN: Bool) -> String {
        guard let stats = stats, stats.totalTrades >= 5 else {
            return isEN
                ? "Insufficient trade history for personalized recommendations (minimum 5 trades)."
                : "Historique de trades insuffisant pour des recommandations personnalisées (minimum 5 trades)."
        }

        var lines: [String] = []

        lines.append(isEN
            ? "Trader profile: \(stats.totalTrades) trades, WR \(Int(stats.overallWinRate * 100))%, Avg RR \(String(format: "%.1f", stats.averageRR))"
            : "Profil trader : \(stats.totalTrades) trades, WR \(Int(stats.overallWinRate * 100))%, RR moyen \(String(format: "%.1f", stats.averageRR))")

        if let best = stats.bestSetup {
            lines.append(isEN
                ? "Best setup: '\(best.name)' (WR \(Int(best.winRate * 100))%, \(best.tradeCount) trades) — FAVOR this setup."
                : "Meilleur setup : '\(best.name)' (WR \(Int(best.winRate * 100))%, \(best.tradeCount) trades) — PRIVILÉGIER ce setup.")
        }

        if let worst = stats.worstSetup, worst.winRate < 0.4 {
            lines.append(isEN
                ? "Weak setup: '\(worst.name)' (WR \(Int(worst.winRate * 100))%) — AVOID or reduce size on this setup."
                : "Setup faible : '\(worst.name)' (WR \(Int(worst.winRate * 100))%) — ÉVITER ou réduire la taille sur ce setup.")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Build Structured Prompt Context

    func buildStructuredContext(result: AIAnalysisResult, isEN: Bool) -> String {
        var lines: [String] = []

        lines.append("=== AI SCORING ENGINE RESULTS ===")
        lines.append(isEN ? "TOTAL SCORE: \(result.totalScore)/100" : "SCORE TOTAL : \(result.totalScore)/100")
        lines.append(isEN ? "Trade bias: \(result.tradeBias.displayName)" : "Biais de trading : \(result.tradeBias.displayName)")
        lines.append(isEN ? "Wyckoff phase: \(result.detectedMarketPhase.displayName)" : "Phase Wyckoff : \(result.detectedMarketPhase.displayName)")
        lines.append("")

        lines.append(isEN ? "--- Sub-scores ---" : "--- Sous-scores ---")
        lines.append(isEN ? "MTF Alignment: \(result.mtfAlignmentScore)/100" : "Alignement MTF : \(result.mtfAlignmentScore)/100")
        lines.append(isEN ? "Derivatives: \(result.derivativesScore)/100" : "Dérivés : \(result.derivativesScore)/100")
        lines.append(isEN ? "Liquidity: \(result.liquidityScore)/100" : "Liquidité : \(result.liquidityScore)/100")
        lines.append(isEN ? "Macro: \(result.macroScore)/100" : "Macro : \(result.macroScore)/100")
        lines.append(isEN ? "Correlation: \(result.correlationScore)/100" : "Corrélation : \(result.correlationScore)/100")
        lines.append("")

        if !result.mtfSummary.isEmpty {
            lines.append("--- MTF ANALYSIS ---")
            lines.append(result.mtfSummary)
            lines.append("")
        }

        if !result.derivativesSummary.isEmpty {
            lines.append("--- DERIVATIVES ---")
            lines.append(result.derivativesSummary)
            lines.append("")
        }

        if !result.liquiditySummary.isEmpty {
            lines.append("--- LIQUIDITY ---")
            lines.append(result.liquiditySummary)
            lines.append("")
        }

        if !result.macroSummary.isEmpty {
            lines.append("--- MACRO ---")
            lines.append(result.macroSummary)
            lines.append("")
        }

        if !result.correlationSummary.isEmpty {
            lines.append("--- CORRELATION ---")
            lines.append(result.correlationSummary)
            lines.append("")
        }

        if !result.wyckoffSummary.isEmpty {
            lines.append("--- WYCKOFF PHASE ---")
            lines.append(result.wyckoffSummary)
            lines.append("")
        }

        if !result.traderStatsSummary.isEmpty {
            lines.append("--- TRADER PROFILE ---")
            lines.append(result.traderStatsSummary)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
