//
//  PerformanceWidgetsView.swift
//  Journal de trading 2025
//
//  Widgets de performance en temps réel pour le Dashboard

import SwiftUI

struct PerformanceWidgetsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let trades: [Trade]
    @EnvironmentObject var appState: AppState
    
    var todayTrades: [Trade] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return trades.filter { calendar.isDate($0.date, inSameDayAs: today) }
    }
    
    var weekTrades: [Trade] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return trades.filter { $0.date >= weekAgo }
    }
    
    var todayPnL: Double {
        todayTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
    }
    
    var weekPnL: Double {
        weekTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
    }
    
    var bestTradeToday: Trade? {
        todayTrades.max { (appState.netPnL(for: $0) ?? 0) < (appState.netPnL(for: $1) ?? 0) }
    }
    
    var worstTradeToday: Trade? {
        todayTrades.min { (appState.netPnL(for: $0) ?? 0) < (appState.netPnL(for: $1) ?? 0) }
    }
    
    var currentWinStreak: Int {
        let sortedTrades = trades.sorted { $0.date > $1.date }
        var streak = 0
        for trade in sortedTrades {
            if let pnl = appState.netPnL(for: trade), pnl > 0 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }
    
    var currentDrawdown: Double {
        let sortedTrades = trades.sorted { $0.date < $1.date }
        var cumulative: Double = 0
        var peak: Double = 0
        var maxDrawdown: Double = 0
        
        for trade in sortedTrades {
            if let pnl = appState.netPnL(for: trade) {
                cumulative += pnl
                if cumulative > peak {
                    peak = cumulative
                }
                let drawdown = peak - cumulative
                if drawdown > maxDrawdown {
                    maxDrawdown = drawdown
                }
            }
        }
        
        return maxDrawdown
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Header
            HStack {
                Text(t("performanceTempsRel"))
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            
            // Widgets Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.md) {
                // P&L du jour
                PerformanceWidget(
                    title: "P&L Aujourd'hui",
                    value: String(format: "$%.2f", todayPnL),
                    change: weekPnL != 0 ? String(format: "%.1f%%", (todayPnL / abs(weekPnL)) * 100) : nil,
                    icon: "sun.max.fill",
                    color: todayPnL >= 0 ? AppColors.success : AppColors.error,
                    trend: todayPnL >= 0 ? .up : .down
                )
                
                // P&L de la semaine
                PerformanceWidget(
                    title: "P&L 7 jours",
                    value: String(format: "$%.2f", weekPnL),
                    change: nil,
                    icon: "calendar",
                    color: weekPnL >= 0 ? AppColors.success : AppColors.error,
                    trend: weekPnL >= 0 ? .up : .down
                )
                
                // Meilleur trade du jour
                if let bestTrade = bestTradeToday, let bestPnL = appState.netPnL(for: bestTrade) {
                    PerformanceWidget(
                        title: "Meilleur Trade",
                        value: String(format: "$%.2f", bestPnL),
                        change: bestTrade.symbol,
                        icon: "arrow.up.circle.fill",
                        color: AppColors.success,
                        trend: .up
                    )
                } else {
                    EmptyPerformanceWidget(title: "Meilleur Trade", icon: "arrow.up.circle.fill")
                }
                
                // Pire trade du jour
                if let worstTrade = worstTradeToday, let worstPnL = appState.netPnL(for: worstTrade) {
                    PerformanceWidget(
                        title: "Pire Trade",
                        value: String(format: "$%.2f", worstPnL),
                        change: worstTrade.symbol,
                        icon: "arrow.down.circle.fill",
                        color: AppColors.error,
                        trend: .down
                    )
                } else {
                    EmptyPerformanceWidget(title: "Pire Trade", icon: "arrow.down.circle.fill")
                }
                
                // Win streak
                PerformanceWidget(
                    title: "Win Streak",
                    value: "\(currentWinStreak)",
                    change: currentWinStreak > 0 ? "🔥" : nil,
                    icon: "flame.fill",
                    color: currentWinStreak > 0 ? AppColors.warning : AppColors.textSecondary,
                    trend: currentWinStreak > 0 ? .up : .neutral
                )
                
                // Drawdown actuel
                PerformanceWidget(
                    title: "Drawdown",
                    value: String(format: "$%.2f", currentDrawdown),
                    change: currentDrawdown > 0 ? "⚠️" : nil,
                    icon: "chart.line.downtrend.xyaxis",
                    color: currentDrawdown > 0 ? AppColors.error : AppColors.success,
                    trend: currentDrawdown > 0 ? .down : .neutral
                )
            }
        }
    }
}

// MARK: - Performance Widget
struct PerformanceWidget: View {
    let title: String
    let value: String
    let change: String?
    let icon: String
    let color: Color
    let trend: Trend
    
    enum Trend {
        case up, down, neutral
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                if let change = change {
                    Text(change)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            
            // Value
            Text(value)
                .font(AppTypography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Trend indicator
            HStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.caption2)
                    .foregroundColor(trendColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var trendIcon: String {
        switch trend {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .neutral: return "minus"
        }
    }
    
    private var trendColor: Color {
        switch trend {
        case .up: return AppColors.success
        case .down: return AppColors.error
        case .neutral: return AppColors.textSecondary
        }
    }
}

// MARK: - Empty Performance Widget
struct EmptyPerformanceWidget: View {
    let title: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                
                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
            }
            
            Text(t("aucunTrade"))
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground.opacity(0.5))
        )
    }
}

#Preview {
    PerformanceWidgetsView(trades: [])
        .environmentObject(AppState())
        .padding()
        .background(AppColors.background)
}



