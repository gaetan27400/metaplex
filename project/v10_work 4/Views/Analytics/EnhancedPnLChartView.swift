//
//  EnhancedPnLChartView.swift
//  Journal de trading 2025
//
//  Vue améliorée de la courbe P&L avec analyse graphique avancée
//

import SwiftUI
import Charts

struct EnhancedPnLChartView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let trades: [Trade]
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTimeframe: ChartTimeframe = .all
    @State private var selectedPoint: PnLDataPoint?
    @State private var showAnalysis = true
    @State private var chartScale: ChartScale = .auto
    @State private var tooltipPosition: CGPoint = .zero
    @State private var showTooltip = false
    @State private var dragOffset: CGSize = .zero
    @State private var showEmotionOverlay: Bool = true
    
    var filteredTrades: [Trade] {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedTimeframe {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return trades.filter { $0.date >= weekAgo }.sorted { $0.date < $1.date }
        case .month:
            let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return trades.filter { $0.date >= monthAgo }.sorted { $0.date < $1.date }
        case .quarter:
            let quarterAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return trades.filter { $0.date >= quarterAgo }.sorted { $0.date < $1.date }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now) ?? now
            return trades.filter { $0.date >= yearAgo }.sorted { $0.date < $1.date }
        case .all:
            return trades.sorted { $0.date < $1.date }
        }
    }
    
    var pnlData: [PnLDataPoint] {
        var cumulative: Double = 0
        return filteredTrades.map { trade in
            let dailyPnL = appState.netPnL(for: trade) ?? 0.0
            cumulative += dailyPnL
            return PnLDataPoint(
                date: trade.date,
                cumulativePnL: cumulative,
                dailyPnL: dailyPnL,
                trade: trade
            )
        }
    }
    
    private var emotionalLoadByDay: [Date: Double] {
        appState.emotionalLoadByDay
    }
    
    var chartStats: ChartStatistics {
        let data = pnlData
        guard !data.isEmpty else {
            return ChartStatistics(
                currentValue: 0,
                maxValue: 0,
                minValue: 0,
                totalReturn: 0,
                maxDrawdown: 0,
                avgDailyReturn: 0,
                winRate: 0
            )
        }
        
        let values = data.map { $0.cumulativePnL }
        let maxValue = values.max() ?? 0
        let minValue = values.min() ?? 0
        let currentValue = data.last?.cumulativePnL ?? 0
        let firstValue = data.first?.cumulativePnL ?? 0
        let totalReturn = currentValue - firstValue
        
        // Calcul du drawdown maximum
        var maxDrawdown: Double = 0
        var peak: Double = firstValue
        for value in values {
            if value > peak {
                peak = value
            }
            let drawdown = peak - value
            if drawdown > maxDrawdown {
                maxDrawdown = drawdown
            }
        }
        
        // Taux de réussite
        let tradesWithPnL = filteredTrades.compactMap { trade -> (Trade, Double)? in
            guard let pnl = appState.netPnL(for: trade) else { return nil }
            return (trade, pnl)
        }
        let wins = tradesWithPnL.filter { $0.1 > 0 }.count
        let winRate = tradesWithPnL.isEmpty ? 0 : Double(wins) / Double(tradesWithPnL.count)
        
        // Rendement moyen quotidien
        let dailyReturns = data.enumerated().compactMap { index, point -> Double? in
            guard index > 0 else { return nil }
            return point.cumulativePnL - data[index - 1].cumulativePnL
        }
        let avgDailyReturn = dailyReturns.isEmpty ? 0 : dailyReturns.reduce(0, +) / Double(dailyReturns.count)
        
        return ChartStatistics(
            currentValue: currentValue,
            maxValue: maxValue,
            minValue: minValue,
            totalReturn: totalReturn,
            maxDrawdown: maxDrawdown,
            avgDailyReturn: avgDailyReturn,
            winRate: winRate
        )
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header avec titre et contrôles
                    headerSection
                    
                    // Statistiques principales
                    statsCardsSection
                    
                    // Graphique principal
                    mainChartSection
                    
                    // Analyse graphique
                    if showAnalysis {
                        analysisSection
                    }
                    
                    // Légende et contrôles
                    controlsSection
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("pnlCurve"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("courbeDePlCumul"))
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(t("trades"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // Toggle analyse
                Button {
                    withAnimation {
                        showAnalysis.toggle()
                    }
                } label: {
                    Image(systemName: showAnalysis ? "chart.bar.fill" : "chart.bar")
                        .font(.title3)
                        .foregroundColor(AppColors.primary)
                }
            }
            
            // Sélecteur de timeframe
            timeframeSelector
        }
    }
    
    private var timeframeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(ChartTimeframe.allCases, id: \.self) { timeframe in
                    Button {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.3)) {
                            selectedTimeframe = timeframe
                        }
                    } label: {
                        Text(timeframe.displayName)
                            .font(AppTypography.labelMedium)
                            .foregroundColor(selectedTimeframe == timeframe ? .white : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                Capsule()
                                    .fill(selectedTimeframe == timeframe ? AppColors.primary : AppColors.cardBackground)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Stats Cards
    private var statsCardsSection: some View {
        let columns: [GridItem] = [
            GridItem(.flexible(), spacing: AppSpacing.md),
            GridItem(.flexible(), spacing: AppSpacing.md)
        ]
        
        return LazyVGrid(columns: columns, alignment: .leading, spacing: AppSpacing.md) {
            PnLStatCard(
                title: "P&L Actuel",
                value: formatCurrency(chartStats.currentValue),
                color: chartStats.currentValue >= 0 ? AppColors.success : AppColors.error,
                icon: "dollarsign.circle.fill"
            )
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            
            PnLStatCard(
                title: "Rendement Total",
                value: formatCurrency(chartStats.totalReturn),
                color: chartStats.totalReturn >= 0 ? AppColors.success : AppColors.error,
                icon: "arrow.up.right.circle.fill"
            )
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            
            PnLStatCard(
                title: "Max Drawdown",
                value: formatCurrency(-chartStats.maxDrawdown),
                color: AppColors.warning,
                icon: "arrow.down.circle.fill"
            )
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            
            PnLStatCard(
                title: "Win Rate",
                value: String(format: "%.1f%%", chartStats.winRate * 100),
                color: chartStats.winRate >= 0.5 ? AppColors.success : AppColors.error,
                icon: "chart.line.uptrend.xyaxis"
            )
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        }
    }
    
    // MARK: - Main Chart
    private var mainChartSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if pnlData.isEmpty {
                emptyStateView
            } else {
                ZStack(alignment: .topLeading) {
                    chartView
                        .frame(height: 380)
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            AppColors.cardBackground,
                                            AppColors.cardBackground.opacity(0.95)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    AppColors.border.opacity(0.3),
                                                    AppColors.border.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .shadow(color: AppColors.primary.opacity(0.1), radius: 20, x: 0, y: 8)
                        .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 4)

                    // Hint d’interaction (WWDC: rendre l’affordance explicite sans polluer)
                    if selectedPoint == nil {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.draw")
                                .font(.system(size: 12, weight: .semibold))
                            Text(t("touchezGlissez"))
                                .font(AppTypography.captionSmall)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(AppColors.textSecondary.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.25))
                                .overlay(
                                    Capsule()
                                        .stroke(AppColors.border.opacity(0.18), lineWidth: 1)
                                )
                        )
                        .padding(.top, 10)
                        .padding(.leading, 10)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                    }
                }
            }
        }
    }
    
    private var chartView: some View {
        let lineColor = chartStats.currentValue >= 0 ? AppColors.success : AppColors.error

        let values = pnlData.map { $0.cumulativePnL }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let padding = max(50, (maxV - minV) * 0.15)
        let yDomain = (minV - padding)...(maxV + padding)
        
        return buildChart(lineColor: lineColor, yMin: yDomain.lowerBound, yMax: yDomain.upperBound)
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: xAxisDesiredCount)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(AppColors.border.opacity(0.10))
                    AxisTick(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(AppColors.border.opacity(0.18))
                    AxisValueLabel(format: xAxisDateFormat)
                        .font(AppTypography.captionSmall)
                        .foregroundStyle(AppColors.textSecondary.opacity(0.8))
                }
            }
            .chartYAxis(.hidden)
            .chartBackground { chartProxy in
                chartBackgroundView(chartProxy: chartProxy)
            }
    }

    private var xAxisDateFormat: Date.FormatStyle {
        switch selectedTimeframe {
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.month().day()
        case .quarter, .year, .all:
            return .dateTime.month(.abbreviated)
        }
    }
    
    private var xAxisDesiredCount: Int {
        switch selectedTimeframe {
        case .week: return 4
        case .month: return 4
        case .quarter: return 4
        case .year: return 5
        case .all: return 5
        }
    }
    
    private func buildChart(lineColor: Color, yMin: Double, yMax: Double) -> some View {
        return Chart {
            // ✅ Couche émotionnelle (contexte) : arrière-plan discret 0..100
            if showEmotionOverlay, !emotionalLoadByDay.isEmpty {
                // On pose des "bandes" quotidiennes (opacité = charge) derrière le P&L.
                // Note: P&L = signal principal ; émotion = contexte.
                let cal = Calendar.current
                let days = Array(Set(pnlData.map { cal.startOfDay(for: $0.date) })).sorted()
                
                ForEach(days, id: \.self) { day in
                    let load = emotionalLoadByDay[day] ?? 0
                    if load > 0 {
                        let t = max(0.0, min(1.0, load / 100.0))
                        let intensity = pow(t, 0.75)
                        let tint: Color = {
                            switch load {
                            case ..<25: return Color(hex: "#2DD4BF") // teal
                            case ..<55: return Color(hex: "#60A5FA") // soft blue
                            case ..<75: return Color(hex: "#FB923C") // orange
                            default: return Color(hex: "#F87171") // soft red
                            }
                        }()
                        
                        // Bande sur 1 jour (start..+1d)
                        let next = cal.date(byAdding: .day, value: 1, to: day) ?? day
                        RectangleMark(
                            xStart: .value("Start", day, unit: .day),
                            xEnd: .value("End", next, unit: .day),
                            yStart: .value("YMin", yMin),
                            yEnd: .value("YMax", yMax)
                        )
                        .foregroundStyle(tint.opacity(0.05 + 0.18 * intensity))
                    }
                }
            }
            
            // Ligne principale: passé désaturé (fin), présent accentué (épais) sur ~20% des points
            let total = pnlData.count
            let recentCount = max(2, Int(Double(total) * 0.20))
            let splitIndex = max(0, total - recentCount)
            let past = Array(pnlData.prefix(max(0, splitIndex + 1))) // +1 pour continuité visuelle
            let recent = Array(pnlData.suffix(max(0, total - splitIndex)))
            
            ForEach(past) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("P&L", point.cumulativePnL)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.16), lineColor.opacity(0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            
            ForEach(recent) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("P&L", point.cumulativePnL)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [lineColor.opacity(0.55), lineColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.catmullRom)
            }
            
            // Break-even: repère discret
            RuleMark(y: .value("BreakEven", 0))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(AppColors.textSecondary.opacity(0.25))
            
            // Dernier point: focus (histoire du chart)
            if let last = pnlData.last {
                PointMark(
                    x: .value("Date", last.date, unit: .day),
                    y: .value("P&L", last.cumulativePnL)
                )
                .symbolSize(120)
                .foregroundStyle(last.cumulativePnL >= 0 ? AppColors.success : AppColors.error)
                .annotation(position: .top) {
                    Text(String(format: "$%.0f", last.cumulativePnL))
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.6))
                        )
                }
            }
            
            // Interaction visible: ligne verticale + point qui suit la courbe + annotation date/valeur
            if let selected = selectedPoint {
                RuleMark(x: .value("Date", selected.date, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.28))
                    .zIndex(0)
                
                // Halo autour du point
                PointMark(
                    x: .value("Date", selected.date, unit: .day),
                    y: .value("P&L", selected.cumulativePnL)
                )
                .foregroundStyle(AppColors.primary.opacity(0.2))
                .symbolSize(200)
                
                // Point principal
                PointMark(
                    x: .value("Date", selected.date, unit: .day),
                    y: .value("P&L", selected.cumulativePnL)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolSize(140)
                .shadow(color: AppColors.primary.opacity(0.5), radius: 8, x: 0, y: 4)
                .annotation(position: .top, alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.date.formatted(xAxisDateFormat))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(.white.opacity(0.9))
                        Text(formatCurrency(selected.cumulativePnL))
                            .font(AppTypography.captionMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.65))
                    )
                }
            }
        }
    }
    
    private func chartBackgroundView(chartProxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateSelectedPoint(at: value.location, in: geometry, chartProxy: chartProxy)
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedPoint = nil
                                showTooltip = false
                            }
                        }
                )
        }
    }
    
    private func updateSelectedPoint(at location: CGPoint, in geometry: GeometryProxy, chartProxy: ChartProxy) {
        // Utiliser la position relative dans le graphique
        let chartFrame = geometry.frame(in: .local)
        let relativeX = location.x - chartFrame.minX
        
        guard relativeX >= 0 && relativeX <= chartFrame.width,
              let date: Date = chartProxy.value(atX: relativeX) else {
            return
        }
        
        // Trouver le point le plus proche
        let closestPoint = pnlData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
        
        if let closest = closestPoint, abs(closest.date.timeIntervalSince(date)) < 86400 { // 1 jour
            HapticFeedback.selection()
            
            // Calculer la position du tooltip (au-dessus du point)
            let tooltipX = min(max(location.x, 100), chartFrame.width - 100) // Garder dans les limites
            let tooltipY = max(location.y - 140, 20) // Au-dessus du point
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPoint = closest
                tooltipPosition = CGPoint(x: tooltipX, y: tooltipY)
                showTooltip = true
            }
        }
    }
    
    // MARK: - Tooltip View
    private func tooltipView(for point: PnLDataPoint) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // En-tête avec date
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.primary)
                Text(point.date.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTypography.labelSmall)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
            
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            // P&L Cumulé (valeur principale)
            VStack(alignment: .leading, spacing: 4) {
                Text(t("plCumul"))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textTertiary)
                Text(formatCurrency(point.cumulativePnL))
                    .font(AppTypography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(point.cumulativePnL >= 0 ? AppColors.success : AppColors.error)
            }
            
            // P&L du jour
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("plDuJour"))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textTertiary)
                    HStack(spacing: 6) {
                        Image(systemName: point.dailyPnL >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 14))
                        Text(formatCurrency(point.dailyPnL))
                            .font(AppTypography.labelMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(point.dailyPnL >= 0 ? AppColors.success : AppColors.error)
                }
                Spacer()
            }
            
            // Détails du trade
            let trade = point.trade
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(trade.symbol)
                        .font(AppTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Text(trade.type.rawValue)
                        .font(AppTypography.captionSmall)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(trade.type == .long ? AppColors.success : AppColors.error)
                        )
                }
                
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("quantity"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                        Text(String(format: "%.4f", trade.quantity ?? 0))
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(t("price"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                        Text(formatCurrency(trade.entryPrice ?? 0))
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .frame(width: 240)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.cardBackground,
                            AppColors.cardBackground.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppColors.primary.opacity(0.5),
                                    AppColors.primary.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .shadow(color: AppColors.primary.opacity(0.3), radius: 20, x: 0, y: 10)
        .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 4)
    }
    
    // MARK: - Analysis Section
    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("analyse"))
                .font(AppTypography.titleSmall)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // Tendances
                analysisRow(
                    icon: "arrow.trending.up",
                    title: "Tendance",
                    value: chartStats.totalReturn >= 0 ? "Haussière" : "Baissière",
                    color: chartStats.totalReturn >= 0 ? AppColors.success : AppColors.error
                )
                
                // Volatilité
                let volatility = calculateVolatility()
                analysisRow(
                    icon: "waveform.path",
                    title: "Volatilité",
                    value: volatility > 0.1 ? "Élevée" : volatility > 0.05 ? "Modérée" : "Faible",
                    color: volatility > 0.1 ? AppColors.warning : AppColors.info
                )
                
                // Performance vs Drawdown
                let recoveryRatio = chartStats.maxDrawdown > 0 ? abs(chartStats.totalReturn) / chartStats.maxDrawdown : 0
                analysisRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Ratio Recouvrement",
                    value: String(format: "%.2fx", recoveryRatio),
                    color: recoveryRatio > 2 ? AppColors.success : recoveryRatio > 1 ? AppColors.warning : AppColors.error
                )
                
                // Instructions d'interaction
                if selectedPoint == nil {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.primary.opacity(0.7))
                        Text(t("ai"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(AppColors.primary.opacity(0.1))
                    )
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    private func analysisRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.labelMedium)
                .foregroundColor(color)
        }
    }
    
    private func calculateVolatility() -> Double {
        guard pnlData.count > 1 else { return 0 }
        
        let returns = pnlData.enumerated().compactMap { index, point -> Double? in
            guard index > 0 else { return nil }
            let prevValue = pnlData[index - 1].cumulativePnL
            guard prevValue != 0 else { return nil }
            return (point.cumulativePnL - prevValue) / abs(prevValue)
        }
        
        guard !returns.isEmpty else { return 0 }
        
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count)
        return sqrt(variance)
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Légende améliorée
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(t("lgende"))
                    .font(AppTypography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                HStack(spacing: AppSpacing.lg) {
                    legendItem(
                        color: AppColors.success,
                        label: "Profit",
                        icon: "arrow.up.circle.fill"
                    )
                    legendItem(
                        color: AppColors.error,
                        label: "Perte",
                        icon: "arrow.down.circle.fill"
                    )
                    legendItem(
                        color: AppColors.primary,
                        label: "Sélection",
                        icon: "hand.tap.fill"
                    )
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(AppColors.cardBackground.opacity(0.5))
            )
            
            // Instructions d'utilisation
            if selectedPoint == nil {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.primary.opacity(0.8))
                    Text(t("touchezEtGlissezSurLeGraphiquePourExplorerLesDonnes"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.primary.opacity(0.1))
                )
            }
        }
    }
    
    private func legendItem(color: Color, label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(label)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(AppColors.textTertiary)
            
            Text(t("noData"))
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textSecondary)
            
            Text(t("trades"))
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Helpers
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }
}

// MARK: - Supporting Types

enum ChartTimeframe: String, CaseIterable {
    case week = "7j"
    case month = "30j"
    case quarter = "3M"
    case year = "1A"
    case all = "Tout"
    
    var displayName: String {
        rawValue
    }
}

enum ChartScale {
    case auto
    case fixed
}

struct PnLDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let cumulativePnL: Double
    let dailyPnL: Double
    let trade: Trade
}

struct ChartStatistics {
    let currentValue: Double
    let maxValue: Double
    let minValue: Double
    let totalReturn: Double
    let maxDrawdown: Double
    let avgDailyReturn: Double
    let winRate: Double
}

struct PnLStatCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(AppTypography.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.15), color.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

