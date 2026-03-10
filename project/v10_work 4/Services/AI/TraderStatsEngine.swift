//
//  TraderStatsEngine.swift
//  Journal de trading 2025
//
//  Trader performance database integration.
//  Computes per-strategy statistics, win rates, average RR,
//  and adapts AI recommendations to the trader's actual performance.
//

import Foundation

final class TraderStatsEngine {

    func computeStats(
        trades: [Trade],
        systems: [TradingSystem],
        appState: AppState?
    ) -> TraderPerformanceStats? {

        let closedTrades = trades.filter { $0.isClosed }
        guard closedTrades.count >= 5 else { return nil }

        // Overall stats
        let totalTrades = closedTrades.count
        let wins = closedTrades.filter { getPnL(for: $0, appState: appState) > 0 }
        let losses = closedTrades.filter { getPnL(for: $0, appState: appState) <= 0 }
        let overallWinRate = Double(wins.count) / Double(totalTrades)

        // Average RR
        let avgWin = wins.isEmpty ? 0 : wins.map { getPnL(for: $0, appState: appState) }.reduce(0, +) / Double(wins.count)
        let avgLoss = losses.isEmpty ? 1 : abs(losses.map { getPnL(for: $0, appState: appState) }.reduce(0, +) / Double(losses.count))
        let averageRR = avgLoss > 0 ? avgWin / avgLoss : 0

        // Per-system stats
        let bySystem = Dictionary(grouping: closedTrades) { $0.systemId }
        var setupStats: [TraderPerformanceStats.SetupStats] = []

        for (systemId, systemTrades) in bySystem {
            guard systemTrades.count >= 3 else { continue }
            let systemName = systems.first(where: { $0.id == systemId })?.name ?? "Unknown"
            let systemWins = systemTrades.filter { getPnL(for: $0, appState: appState) > 0 }
            let systemWinRate = Double(systemWins.count) / Double(systemTrades.count)
            let systemPnLs = systemTrades.map { getPnL(for: $0, appState: appState) }
            let totalPnL = systemPnLs.reduce(0, +)

            let sysAvgWin = systemWins.isEmpty ? 0 :
                systemWins.map { getPnL(for: $0, appState: appState) }.reduce(0, +) / Double(systemWins.count)
            let sysLosses = systemTrades.filter { getPnL(for: $0, appState: appState) <= 0 }
            let sysAvgLoss = sysLosses.isEmpty ? 1 :
                abs(sysLosses.map { getPnL(for: $0, appState: appState) }.reduce(0, +) / Double(sysLosses.count))
            let sysRR = sysAvgLoss > 0 ? sysAvgWin / sysAvgLoss : 0

            setupStats.append(TraderPerformanceStats.SetupStats(
                id: systemId,
                name: systemName,
                winRate: systemWinRate,
                averageRR: sysRR,
                tradeCount: systemTrades.count,
                totalPnL: totalPnL
            ))
        }

        // Sort by performance
        setupStats.sort { $0.winRate > $1.winRate }

        let bestSetup = setupStats.first(where: { $0.tradeCount >= 5 }) ?? setupStats.first
        let worstSetup = setupStats.last(where: { $0.tradeCount >= 5 }) ?? setupStats.last

        // Recent bias (last 10 trades)
        let recentTrades = Array(closedTrades.suffix(10))
        let recentWins = recentTrades.filter { getPnL(for: $0, appState: appState) > 0 }.count
        let recentWinRate = recentTrades.isEmpty ? 0.5 : Double(recentWins) / Double(recentTrades.count)
        let recentBias: TradeBias
        if recentWinRate >= 0.7 { recentBias = .strongBullish }
        else if recentWinRate >= 0.55 { recentBias = .bullish }
        else if recentWinRate >= 0.45 { recentBias = .neutral }
        else if recentWinRate >= 0.3 { recentBias = .bearish }
        else { recentBias = .strongBearish }

        return TraderPerformanceStats(
            totalTrades: totalTrades,
            overallWinRate: overallWinRate,
            averageRR: averageRR,
            bestSetup: bestSetup,
            worstSetup: worstSetup,
            setupStats: setupStats,
            recentBias: recentBias
        )
    }

    // MARK: - PnL Helper

    private func getPnL(for trade: Trade, appState: AppState?) -> Double {
        if let appState = appState {
            return appState.netPnL(for: trade) ?? trade.pnl
        }
        return trade.pnl
    }
}
