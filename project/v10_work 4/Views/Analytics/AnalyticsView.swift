import Foundation
import SwiftUI
import Combine

// MARK: - Analytics View
struct AnalyticsView: View {
    @EnvironmentObject var appState: AppState
    @Binding var language: Localizable.Language
    @State private var selectedPeriod: PeriodFilter = .all
    @State private var selectedTab: AnalyticsTab = .analytics
    @State private var showAddTrade = false
    @State private var showFilterMenu = false
    
    private var filteredTrades: [Trade] {
        let calendar = Calendar.current
        let now = Date()
        
        let startDate: Date = {
            switch selectedPeriod {
            case .all:
                return Date.distantPast
            case .currentWeek:
                return calendar.date(byAdding: .day, value: -7, to: now) ?? now
            case .lastWeek:
                return calendar.date(byAdding: .day, value: -14, to: now) ?? now
            case .last2Weeks:
                return calendar.date(byAdding: .day, value: -14, to: now) ?? now
            case .lastMonth:
                return calendar.date(byAdding: .month, value: -1, to: now) ?? now
            case .last3Months:
                return calendar.date(byAdding: .month, value: -3, to: now) ?? now
            case .last6Months:
                return calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .lastYear:
                return calendar.date(byAdding: .year, value: -1, to: now) ?? now
            }
        }()
        
        return appState.trades.filter { $0.date >= startDate }
    }
    
    private var symbolStats: [(symbol: String, pnl: Double, avgPnl: Double, trades: Int)] {
        let grouped = Dictionary(grouping: filteredTrades) { $0.symbol }
        return grouped.map { symbol, trades in
            let totalPnl = trades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            let avgPnl = trades.isEmpty ? 0 : totalPnl / Double(trades.count)
            return (symbol, totalPnl, avgPnl, trades.count)
        }.sorted { $0.avgPnl > $1.avgPnl }
    }
    
    private var stats: Statistics {
        Statistics.calculate(trades: filteredTrades, appState: appState)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Period Filter
                Menu {
                    ForEach(PeriodFilter.allCases) { period in
                        Button(action: { selectedPeriod = period }) {
                            HStack {
                                Text(period.rawValue)
                                if selectedPeriod == period {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedPeriod.rawValue)
                            .foregroundColor(AppColors.textPrimary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surface2)
                    .cornerRadius(12)
                }
                .padding()
                
                // Tabs
                HStack(spacing: 12) {
                    ForEach([AnalyticsTab.analytics, .timeMetrics, .calendar], id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .white : .gray)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(selectedTab == tab ? Color.purple : Color.clear)
                                .cornerRadius(20)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 20) {
                        if selectedTab == .analytics {
                            analyticsContent
                        } else if selectedTab == .timeMetrics {
                            Text("Time Metrics - Coming soon")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Calendar - Coming soon")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showAddTrade = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(AppColors.textPrimary)
                        }
                        
                        Button(action: {}) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.title2)
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddTrade) {
                AddTradeView()
                    .environmentObject(AppState.shared)
            }
        }
    }
    
    private var analyticsContent: some View {
        VStack(spacing: 16) {
            // Top 3 cards
            HStack(spacing: 12) {
                AnalyticsCard(
                    title: "Best symbol\nby average",
                    value: symbolStats.first?.symbol ?? "-",
                    icon: nil
                )
                
                AnalyticsCard(
                    title: "Worst symbol\nby average",
                    value: symbolStats.last?.symbol ?? "-",
                    icon: nil
                )
                
                AnalyticsCard(
                    title: "Numbers\nof symbols",
                    value: "\(Set(filteredTrades.map { $0.symbol }).count)",
                    icon: nil
                )
            }
            
            // Best/Worst by PNL
            HStack(spacing: 12) {
                AnalyticsCard(
                    title: "Best symbol by PNL",
                    value: symbolStats.first?.symbol ?? "-",
                    icon: "exclamationmark.circle",
                    isLarge: true
                )
                
                AnalyticsCard(
                    title: "Worst symbol by PNL",
                    value: symbolStats.last?.symbol ?? "-",
                    icon: "exclamationmark.circle",
                    isLarge: true
                )
            }
            
            // Trade Statistics
            VStack(alignment: .leading, spacing: 16) {
                Text("Trade Statistics")
                    .font(.title3.bold())
                    .foregroundColor(AppColors.textPrimary)
                
                // Win/Loss
                VStack(spacing: 8) {
                    HStack {
                        Text("Win")
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("Loss")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .font(.subheadline)
                    
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geometry.size.width * (stats.winRate / 100))
                            Rectangle()
                                .fill(Color.red)
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
                    HStack {
                        Text("\(stats.wins)")
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Text("\(stats.losses)")
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .font(.title3.bold())
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Buy/Sell
                VStack(spacing: 8) {
                    HStack {
                        Text("Buy")
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                        Text("Sell")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .font(.subheadline)
                    
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.green)
                                .frame(width: geometry.size.width * 0.5)
                            Rectangle()
                                .fill(Color.blue)
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
                    HStack {
                        Text("\(stats.longTrades)")
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Text("\(stats.shortTrades)")
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .font(.title3.bold())
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Average duration & result
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average duration")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.purple)
                            Text("-")
                                .font(.title3.bold())
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average result")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.purple)
                            Text(String(format: "$%.0f", stats.avgWin))
                                .font(.title3.bold())
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Best/Worst trade
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Best trade")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.purple)
                            if let best = filteredTrades.compactMap({ appState.netPnL(for: $0) }).max() {
                                Text(String(format: "$%.0f", best))
                                    .font(.title3.bold())
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Worst trade")
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.purple)
                            if let worst = filteredTrades.compactMap({ appState.netPnL(for: $0) }).min() {
                                Text(String(format: "$%.0f", worst))
                                    .font(.title3.bold())
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.surface2)
            .cornerRadius(16)
        }
    }
    
    
    private var calendarContent: some View {
        VStack {
            Text("Calendar")
                .font(.title2)
                .foregroundColor(AppColors.textPrimary)
            Text("Coming soon...")
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Analytics Card
struct AnalyticsCard: View {
    let title: String
    let value: String
    let icon: String?
    var isLarge: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Text(value)
                .font(isLarge ? .title2.bold() : .title3.bold())
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .frame(height: isLarge ? 120 : 100)
        .background(Color.surface2)
        .cornerRadius(12)
    }
}

