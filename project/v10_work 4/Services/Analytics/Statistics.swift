import Foundation
import SwiftUI
import Combine

// MARK: - Statistics Calculator
struct Statistics {
    let totalTrades: Int
    let wins: Int
    let losses: Int
    let winRate: Double
    let totalPnL: Double
    let totalFees: Double
    let avgWin: Double
    let avgLoss: Double
    let payoffRatio: Double
    let maxDrawdown: Double
    let sharpeRatio: Double
    let expectancy: Double
    let longestWinStreak: Int
    let longestLossStreak: Int
    
    let longTrades: Int
    let shortTrades: Int
    let longWinRate: Double
    let shortWinRate: Double
    let longPnL: Double
    let shortPnL: Double
    
    static func calculate(trades: [Trade], appState: AppState) -> Statistics {
        print("📊 [Statistics.calculate] Calcul avec \(trades.count) trades")
        // netPnL retourne maintenant 0.0 au lieu de nil pour les trades sans PnL calculable
        // Cela permet d'inclure tous les trades dans les statistiques (comptage, etc.)
        // même s'ils n'ont pas de PnL calculable
        let tradesWithPnL: [(trade: Trade, pnl: Double, fees: Double)] = trades.map { trade in
            // netPnL retourne toujours une valeur (0.0 si non calculable)
            let pnl = appState.netPnL(for: trade) ?? 0.0
            let fees = appState.fees(for: trade)
            return (trade, pnl, fees)
        }
        print("📊 [Statistics.calculate] \(tradesWithPnL.count) trades traités sur \(trades.count) total")
        
        let totalTrades = tradesWithPnL.count
        let wins = tradesWithPnL.filter { $0.pnl >= 0 }.count
        let losses = totalTrades - wins
        let winRate = totalTrades > 0 ? Double(wins) / Double(totalTrades) * 100 : 0
        
        let totalPnL = tradesWithPnL.reduce(0.0) { $0 + $1.pnl }
        let totalFees = tradesWithPnL.reduce(0.0) { $0 + $1.fees }
        
        let winningTrades = tradesWithPnL.filter { $0.pnl >= 0 }
        let losingTrades = tradesWithPnL.filter { $0.pnl < 0 }
        
        let avgWin = wins > 0 ? winningTrades.reduce(0.0) { $0 + $1.pnl } / Double(wins) : 0
        let avgLoss = losses > 0 ? losingTrades.reduce(0.0) { $0 + abs($1.pnl) } / Double(losses) : 0
        let payoffRatio = avgLoss > 0 ? avgWin / avgLoss : 0
        
        var cumulative = 0.0
        var peak = 0.0
        var maxDrawdown = 0.0
        
        for item in tradesWithPnL {
            cumulative += item.pnl
            if cumulative > peak { peak = cumulative }
            let drawdown = peak - cumulative
            if drawdown > maxDrawdown { maxDrawdown = drawdown }
        }
        
        let returns = tradesWithPnL.map { ($0.pnl / 1000) * 100 }
        let avgReturn = returns.isEmpty ? 0 : returns.reduce(0, +) / Double(returns.count)
        let variance = returns.isEmpty ? 0 : returns.reduce(0) { $0 + pow($1 - avgReturn, 2) } / Double(returns.count)
        let stdDev = sqrt(variance)
        let sharpeRatio = stdDev > 0 ? avgReturn / stdDev : 0
        
        let lossRate = totalTrades > 0 ? Double(losses) / Double(totalTrades) : 0
        let expectancy = (winRate / 100 * avgWin) - (lossRate * avgLoss)
        
        var currentStreak = 0
        var longestWinStreak = 0
        var longestLossStreak = 0
        var lastResult: Double? = nil
        
        for item in tradesWithPnL {
            let isWin = item.pnl >= 0
            if lastResult == nil || (isWin && lastResult! >= 0) || (!isWin && lastResult! < 0) {
                currentStreak += 1
            } else {
                currentStreak = 1
            }
            
            if isWin && currentStreak > longestWinStreak {
                longestWinStreak = currentStreak
            } else if !isWin && currentStreak > longestLossStreak {
                longestLossStreak = currentStreak
            }
            lastResult = item.pnl
        }
        
        let longTrades = tradesWithPnL.filter { $0.trade.type == .long }
        let shortTrades = tradesWithPnL.filter { $0.trade.type == .short }
        
        let longWins = longTrades.filter { $0.pnl >= 0 }.count
        let shortWins = shortTrades.filter { $0.pnl >= 0 }.count
        
        let longWinRate = longTrades.isEmpty ? 0 : Double(longWins) / Double(longTrades.count) * 100
        let shortWinRate = shortTrades.isEmpty ? 0 : Double(shortWins) / Double(shortTrades.count) * 100
        
        let longPnL = longTrades.reduce(0.0) { $0 + $1.pnl }
        let shortPnL = shortTrades.reduce(0.0) { $0 + $1.pnl }
        
        return Statistics(
            totalTrades: totalTrades,
            wins: wins,
            losses: losses,
            winRate: winRate,
            totalPnL: totalPnL,
            totalFees: totalFees,
            avgWin: avgWin,
            avgLoss: avgLoss,
            payoffRatio: payoffRatio,
            maxDrawdown: maxDrawdown,
            sharpeRatio: sharpeRatio,
            expectancy: expectancy,
            longestWinStreak: longestWinStreak,
            longestLossStreak: longestLossStreak,
            longTrades: longTrades.count,
            shortTrades: shortTrades.count,
            longWinRate: longWinRate,
            shortWinRate: shortWinRate,
            longPnL: longPnL,
            shortPnL: shortPnL
        )
    }
}

// MARK: - Enhanced AppState
