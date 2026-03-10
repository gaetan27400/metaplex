//
//  CorrelationChartView.swift
//  Journal de trading 2025
//
//  Graphique de corrélation Émotions ↔ Performance avec axes distincts
//  Solution : axe primaire (P&L) + axe secondaire (Indice émotionnel)
//

import SwiftUI
import Charts

/// Vue de corrélation entre émotions et performance (Version Standalone)
struct StandaloneCorrelationChartView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeframe: Timeframe = .month
    @State private var selectedPoint: CorrelationPoint?
    
    private var calendar: Calendar { .current }
    
    // MARK: - Data Models
    
    private struct CorrelationPoint: Identifiable {
        let id = UUID()
        let date: Date
        let pnl: Double              // Axe primaire (gauche)
        let emotionScore: Double     // Axe secondaire (droite) - normalisé 0-100
        let dominantEmotion: EmotionalState?
        let tradeCount: Int
    }
    
    private var dataPoints: [CorrelationPoint] {
        let trades = filteredTrades
        guard !trades.isEmpty else { return [] }
        
        // Regrouper par jour
        let calendar = Calendar.current
        let groupedByDay = Dictionary(grouping: trades) { trade in
            calendar.startOfDay(for: trade.date)
        }
        
        // Calculer P&L et score émotionnel par jour
        var points: [CorrelationPoint] = []
        for (day, dayTrades) in groupedByDay.sorted(by: { $0.key < $1.key }) {
            // P&L du jour
            let dailyPnL = dayTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            
            // Score émotionnel du jour (depuis emotionalLoadByDay)
            let emotionScore = appState.emotionalLoadByDay[day] ?? 50.0
            
            // Émotion dominante : on peut l'obtenir depuis appState si disponible
            // Pour l'instant, on laisse nil car on n'a pas accès direct aux MoodEntry
            let dominantEmotion: EmotionalState? = nil
            
            points.append(CorrelationPoint(
                date: day,
                pnl: dailyPnL,
                emotionScore: emotionScore,
                dominantEmotion: dominantEmotion,
                tradeCount: dayTrades.count
            ))
        }
        
        return points
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
    
    // Calcul de corrélation (Pearson)
    private var correlation: Double {
        let pnls = dataPoints.map { $0.pnl }
        let emotions = dataPoints.map { $0.emotionScore }
        
        guard pnls.count > 1, emotions.count == pnls.count else { return 0 }
        
        let meanPnl = pnls.reduce(0, +) / Double(pnls.count)
        let meanEmotion = emotions.reduce(0, +) / Double(emotions.count)
        
        var covariance: Double = 0
        var variancePnl: Double = 0
        var varianceEmotion: Double = 0
        
        for i in 0..<pnls.count {
            let diffPnl = pnls[i] - meanPnl
            let diffEmotion = emotions[i] - meanEmotion
            covariance += diffPnl * diffEmotion
            variancePnl += diffPnl * diffPnl
            varianceEmotion += diffEmotion * diffEmotion
        }
        
        let denominator = sqrt(variancePnl * varianceEmotion)
        return denominator > 0 ? covariance / denominator : 0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    statsSection
                    
                    if dataPoints.isEmpty {
                        emptyState
                    } else {
                        chartSection
                        interpretationSection
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("emotionsPerformance"))
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
            Text(t("analyse"))
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            Text(t("comparezVosmotionsEtVosPerformancesQuotidiennes"))
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
        HStack(spacing: AppSpacing.md) {
            // Corrélation
            StatCard(
                title: "Corrélation",
                value: String(format: "%.2f", correlation),
                icon: "arrow.left.arrow.right",
                color: correlationColor
            )
            
            // Nombre de points
            StatCard(
                title: "Jours",
                value: "\(dataPoints.count)",
                icon: "calendar",
                color: AppColors.primary
            )
        }
    }
    
    private var correlationColor: Color {
        if correlation > 0.3 {
            return AppColors.success
        } else if correlation < -0.3 {
            return AppColors.error
        } else {
            return AppColors.warning
        }
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Légende des axes
            HStack {
                Label {
                    Text(t("pl"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                } icon: {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 8, height: 8)
                }
                
                Spacer()
                
                Label {
                    Text(t("chargemotionnelle0100"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                } icon: {
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            
            chartContent
        }
    }
    
    private var chartContent: some View {
        // ✅ SOLUTION : Deux axes Y distincts avec normalisation
        let pnls = dataPoints.map { $0.pnl }
        let minPnl = pnls.min() ?? -100
        let maxPnl = pnls.max() ?? 100
        let pnlRange = max(abs(maxPnl - minPnl), 100)
        let pnlPadding = pnlRange * 0.2
        
        // Normaliser l'émotion sur l'échelle du P&L pour l'affichage
        // mais garder les labels séparés
        let emotionScale = pnlRange / 100.0 // facteur de conversion
        let emotionOffset = minPnl - pnlPadding
        
        return Chart {
            // ✅ 1. Zone de référence (break-even P&L)
            RectangleMark(
                yStart: .value("Min", minPnl - pnlPadding),
                yEnd: .value("Zero", 0)
            )
            .foregroundStyle(AppColors.error.opacity(0.03))
            
            RectangleMark(
                yStart: .value("Zero", 0),
                yEnd: .value("Max", maxPnl + pnlPadding)
            )
            .foregroundStyle(AppColors.success.opacity(0.03))
            
            // ✅ 2. Barres P&L (axe primaire - gauche)
            ForEach(dataPoints) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("P&L", point.pnl)
                )
                .foregroundStyle(
                    point.pnl >= 0
                        ? AppColors.success.opacity(0.7)
                        : AppColors.error.opacity(0.7)
                )
                .cornerRadius(4)
            }
            
            // ✅ 3. Ligne émotionnelle (axe secondaire - droite, normalisée)
            ForEach(dataPoints) { point in
                let scaledEmotion = emotionOffset + (point.emotionScore * emotionScale)
                
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Émotion", scaledEmotion)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppColors.accent)
                .lineStyle(.init(lineWidth: 3, lineCap: .round))
            }
            
            // Points sur la ligne émotionnelle
            ForEach(dataPoints) { point in
                let scaledEmotion = emotionOffset + (point.emotionScore * emotionScale)
                
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Émotion", scaledEmotion)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(60)
            }
            
            // ✅ 4. Point sélectionné
            if let selected = selectedPoint {
                let scaledEmotion = emotionOffset + (selected.emotionScore * emotionScale)
                
                // Ligne verticale
                RuleMark(x: .value("Date", selected.date, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .foregroundStyle(AppColors.primary.opacity(0.5))
                
                // Marqueurs
                PointMark(
                    x: .value("Date", selected.date, unit: .day),
                    y: .value("P&L", selected.pnl)
                )
                .foregroundStyle(AppColors.success)
                .symbolSize(150)
                
                PointMark(
                    x: .value("Date", selected.date, unit: .day),
                    y: .value("Émotion", scaledEmotion)
                )
                .foregroundStyle(AppColors.accent)
                .symbolSize(150)
                
                // Annotation
                    .annotation(position: .top, alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(selected.date.formatted(date: .abbreviated, time: .omitted))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(.white.opacity(0.9))
                            
                            HStack(spacing: 8) {
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
                                    .frame(height: 30)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t("loading"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("\(Int(selected.emotionScore * 100))")
                                        .font(AppTypography.labelMedium)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppColors.accent)
                                }
                            }
                            
                            if let emotion = selected.dominantEmotion {
                                Text(t("name"))
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.15)))
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.8))
                        )
                    }
            }
            
            // ✅ 5. Ligne de break-even
            RuleMark(y: .value("Zero", 0))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                .foregroundStyle(AppColors.textSecondary.opacity(0.4))
        }
        .chartYScale(domain: (minPnl - pnlPadding)...(maxPnl + pnlPadding))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(AppColors.border.opacity(0.1))
                AxisValueLabel(format: .dateTime.month().day())
                    .font(AppTypography.captionSmall)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .chartYAxis {
            // ✅ Axe primaire : P&L (gauche)
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
                                let closest = dataPoints.min(by: {
                                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                })
                                if let c = closest {
                                    HapticFeedback.selection()
                                    withAnimation(.easeInOut(duration: 0.15)) { selectedPoint = c }
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.easeOut(duration: 0.2)) { selectedPoint = nil }
                            }
                    )
            }
        }
        .frame(height: 340)
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
    
    // MARK: - Interpretation Section
    
    private var interpretationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("interprtation"))
                .font(AppTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(interpretationText)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(correlationColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(correlationColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var interpretationText: String {
        if correlation > 0.5 {
            return "Corrélation positive forte : Vos meilleures performances arrivent quand votre charge émotionnelle est élevée. Vous êtes peut-être stimulé par l'intensité."
        } else if correlation > 0.2 {
            return "Corrélation positive modérée : Une charge émotionnelle plus élevée semble légèrement associée à de meilleures performances."
        } else if correlation < -0.5 {
            return "Corrélation négative forte : Vos meilleures performances arrivent quand votre charge émotionnelle est basse. Le calme vous favorise."
        } else if correlation < -0.2 {
            return "Corrélation négative modérée : Une charge émotionnelle élevée semble légèrement nuire à vos performances."
        } else {
            return "Corrélation faible : Pas de lien clair entre votre charge émotionnelle et vos performances. D'autres facteurs sont probablement plus déterminants."
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 44))
                .foregroundColor(AppColors.textSecondary.opacity(0.8))
            Text(t("pasEncoreDeDonnesDeCorrlation"))
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

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                Text(value)
                    .font(AppTypography.titleSmall)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
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
