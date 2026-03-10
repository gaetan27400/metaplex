//
//  PnlContextChartView.swift
//  Journal de trading 2025
//
//  Graphique P&L avec contexte émotionnel en arrière-plan
//  Solution : séparation visuelle claire entre données principales et contexte
//

import SwiftUI
import Charts

/// Vue P&L avec contexte émotionnel (Version Standalone)
struct StandalonePnlContextChartView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeframe: Timeframe = .month
    @State private var selectedBar: PnLBar?
    @State private var showEmotionalContext: Bool = true
    
    private var calendar: Calendar { .current }
    
    // MARK: - Data Models
    
    private struct PnLBar: Identifiable {
        let id = UUID()
        let date: Date
        let pnl: Double
        let emotionalLoad: Double  // 0-100
        let tradeCount: Int
        let wins: Int
        let losses: Int
    }
    
    private var bars: [PnLBar] {
        let trades = filteredTrades
        guard !trades.isEmpty else { return [] }
        
        // Regrouper par jour
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: trades) { trade in
            calendar.startOfDay(for: trade.date)
        }
        
        // Créer les barres
        return groupedByDay.map { (day, dayTrades) in
            let pnls = dayTrades.compactMap { appState.netPnL(for: $0) }
            let totalPnL = pnls.reduce(0, +)
            let wins = pnls.filter { $0 > 0 }.count
            let losses = pnls.filter { $0 < 0 }.count
            let emotionLoad = appState.emotionalLoadByDay[day] ?? 50.0
            
            return PnLBar(
                date: day,
                pnl: totalPnL,
                emotionalLoad: emotionLoad,
                tradeCount: dayTrades.count,
                wins: wins,
                losses: losses
            )
        }.sorted { $0.date < $1.date }
    }
    
    private var filteredTrades: [Trade] {
        let now = Date()
        let calendar = Calendar.current
        
        switch selectedTimeframe {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return appState.trades.filter { $0.date >= start }
        case .month:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return appState.trades.filter { $0.date >= start }
        case .threeMonths:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return appState.trades.filter { $0.date >= start }
        case .sixMonths:
            let start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            return appState.trades.filter { $0.date >= start }
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return appState.trades.filter { $0.date >= start }
        case .all:
            return appState.trades
        }
    }
    
    // Statistiques
    private var stats: (totalPnL: Double, avgPnL: Double, winRate: Double, maxDrawdown: Double) {
        let pnls = bars.map { $0.pnl }
        guard !pnls.isEmpty else { return (0, 0, 0, 0) }
        
        let total = pnls.reduce(0, +)
        let avg = total / Double(pnls.count)
        
        let totalWins = bars.map { $0.wins }.reduce(0, +)
        let totalTrades = bars.map { $0.tradeCount }.reduce(0, +)
        let winRate = totalTrades > 0 ? Double(totalWins) / Double(totalTrades) : 0
        
        // Max drawdown
        var peak = pnls[0]
        var maxDD: Double = 0
        var cumulative = 0.0
        for pnl in pnls {
            cumulative += pnl
            if cumulative > peak {
                peak = cumulative
            }
            let dd = peak - cumulative
            if dd > maxDD {
                maxDD = dd
            }
        }
        
        return (total, avg, winRate, maxDD)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    statsSection
                    
                    if bars.isEmpty {
                        emptyState
                    } else {
                        chartSection
                        controlsSection
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("pnlWithContext"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("plQuotidien"))
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            Text(t("avecContextemotionnelEnArrireplan"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Timeframe.allCases, id: \.self) { tf in
                        Button {
                            HapticFeedback.selection()
                            withAnimation(.spring(response: 0.3)) { selectedTimeframe = tf }
                        } label: {
                            Text(tf.title)
                                .font(AppTypography.labelMedium)
                                .foregroundColor(selectedTimeframe == tf ? .white : AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(
                                    Capsule()
                                        .fill(selectedTimeframe == tf ? AppColors.primary : AppColors.cardBackground)
                                )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: AppSpacing.sm) {
            MiniStatCard(
                title: "P&L Total",
                value: formatCurrency(stats.totalPnL),
                color: stats.totalPnL >= 0 ? AppColors.success : AppColors.error
            )
            
            MiniStatCard(
                title: "P&L Moyen",
                value: formatCurrency(stats.avgPnL),
                color: stats.avgPnL >= 0 ? AppColors.success : AppColors.error
            )
            
            MiniStatCard(
                title: "Win Rate",
                value: String(format: "%.1f%%", stats.winRate * 100),
                color: stats.winRate >= 0.5 ? AppColors.success : AppColors.warning
            )
            
            MiniStatCard(
                title: "Max DD",
                value: formatCurrency(-stats.maxDrawdown),
                color: AppColors.error
            )
        }
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            chartContent
        }
    }
    
    private var chartContent: some View {
        let pnls = bars.map { $0.pnl }
        let minPnl = pnls.min() ?? -100
        let maxPnl = pnls.max() ?? 100
        let range = max(abs(maxPnl - minPnl), 100)
        let padding = range * 0.15
        
        return Chart {
            // ✅ 1. Contexte émotionnel en arrière-plan (DISCRET)
            if showEmotionalContext {
                ForEach(bars) { bar in
                    // Bande de couleur proportionnelle à la charge émotionnelle
                    let intensity = bar.emotionalLoad / 100.0
                    let emotionColor = emotionColor(for: bar.emotionalLoad)
                    
                    // Rectangle couvrant toute la hauteur mais très transparent
                    RectangleMark(
                        x: .value("Date", bar.date, unit: .day),
                        yStart: .value("Min", minPnl - padding),
                        yEnd: .value("Max", maxPnl + padding),
                        width: .ratio(0.9)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                emotionColor.opacity(0.02 + 0.08 * intensity),
                                emotionColor.opacity(0.01 + 0.04 * intensity)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(4)
                    .opacity(0.7)
                }
            }
            
            // ✅ 2. Barres P&L (SIGNAL PRINCIPAL)
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Date", bar.date, unit: .day),
                    y: .value("P&L", bar.pnl),
                    width: .ratio(0.7)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: bar.pnl >= 0
                            ? [AppColors.success, AppColors.success.opacity(0.7)]
                            : [AppColors.error, AppColors.error.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(6)
            }
            
            // ✅ 3. Ligne de break-even
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .foregroundStyle(AppColors.textSecondary.opacity(0.35))
            
            // ✅ 4. Sélection (overlay distinct)
            if let selected = selectedBar {
                // Highlight de la barre
                BarMark(
                    x: .value("Date", selected.date, unit: .day),
                    y: .value("P&L", selected.pnl),
                    width: .ratio(0.7)
                )
                .foregroundStyle(AppColors.primary.opacity(0.3))
                .cornerRadius(6)
                
                // Ligne verticale
                RuleMark(x: .value("Date", selected.date, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .foregroundStyle(AppColors.primary.opacity(0.5))
                
                // Point au sommet de la barre
                PointMark(
                    x: .value("Date", selected.date, unit: .day),
                    y: .value("P&L", selected.pnl)
                )
                .symbolSize(180)
                .foregroundStyle(AppColors.primary)
                .annotation(position: .top, alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selected.date.formatted(date: .abbreviated, time: .omitted))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(.white.opacity(0.9))
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                        
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("totalPnL"))
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(.white.opacity(0.7))
                                Text(formatCurrency(selected.pnl))
                                    .font(AppTypography.labelMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(selected.pnl >= 0 ? AppColors.success : AppColors.error)
                            }
                            
                            Divider()
                                .frame(height: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("trades"))
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(selected.tradeCount)")
                                    .font(AppTypography.labelMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        HStack(spacing: 6) {
                            Text("W: \(selected.wins)")
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.success)
                            Text("•") // TODO: Traduire avec clé appropriée
                                .foregroundColor(.white.opacity(0.5))
                            Text("L: \(selected.losses)")
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.error)
                        }
                        
                        if showEmotionalContext {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(emotionColor(for: selected.emotionalLoad))
                                    .frame(width: 8, height: 8)
                                Text("Charge: \(Int(selected.emotionalLoad * 100))")
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.primary.opacity(0.5), lineWidth: 1.5)
                            )
                    )
                }
            }
        }
        .chartYScale(domain: (minPnl - padding)...(maxPnl + padding))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine().foregroundStyle(AppColors.border.opacity(0.1))
                AxisValueLabel(format: .dateTime.month().day())
                    .font(AppTypography.captionSmall)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(AppColors.border.opacity(0.1))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(formatCurrency(v))
                            .font(AppTypography.captionSmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let x = value.location.x - geo.frame(in: .local).minX
                                guard let date: Date = proxy.value(atX: x) else { return }
                                let closest = bars.min(by: {
                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                })
                                if let c = closest {
                                    HapticFeedback.selection()
                                    withAnimation(.easeInOut(duration: 0.15)) { selectedBar = c }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.2)) { selectedBar = nil }
                            }
                    )
            }
        }
        .frame(height: 360)
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 4)
    }
    
    // MARK: - Controls Section
    
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Toggle(isOn: $showEmotionalContext.animation(.spring())) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.accent)
                    Text(t("afficherLeContextemotionnel"))
                        .font(AppTypography.labelMedium)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
            .tint(AppColors.primary)
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                    )
            )
            
            if showEmotionalContext {
                legendSection
            }
        }
    }
    
    private var legendSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("lgendemotionnelle"))
                .font(AppTypography.captionMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            HStack(spacing: AppSpacing.md) {
                LegendItem(
                    color: Color(hex: "#10B981"),
                    label: "Calme (0-30)"
                )
                LegendItem(
                    color: Color(hex: "#F59E0B"),
                    label: "Attention (30-60)"
                )
            }
            
            HStack(spacing: AppSpacing.md) {
                LegendItem(
                    color: Color(hex: "#F97316"),
                    label: "Tension (60-80)"
                )
                LegendItem(
                    color: Color(hex: "#EF4444"),
                    label: "Danger (80-100)"
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground.opacity(0.5))
        )
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 44))
                .foregroundColor(AppColors.textSecondary.opacity(0.8))
            Text(t("pasEncoreDeDonnesPl"))
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Text(t("trades"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
    
    // MARK: - Helpers
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "€\(Int(value))"
    }
    
    private func emotionColor(for load: Double) -> Color {
        switch load {
        case 0..<30: return Color(hex: "#10B981") // Green
        case 30..<60: return Color(hex: "#F59E0B") // Amber
        case 60..<80: return Color(hex: "#F97316") // Orange
        default: return Color(hex: "#EF4444") // Red
        }
    }
    
    // MARK: - Supporting Types
    
    private enum Timeframe: CaseIterable {
        case week, month, threeMonths, sixMonths, year, all
        
        var title: String {
            switch self {
            case .week: return "7j"
            case .month: return "30j"
            case .threeMonths: return "3m"
            case .sixMonths: return "6m"
            case .year: return "1a"
            case .all: return "Tout"
            }
        }
    }
}

// MARK: - Supporting Views

private struct MiniStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(AppTypography.labelLarge)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.6))
                .frame(width: 20, height: 12)
            Text(label)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}
