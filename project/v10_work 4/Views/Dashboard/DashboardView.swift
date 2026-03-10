//
//  DashboardView.swift
//  Journal de trading 2025
//

import SwiftUI
import Charts

struct DashboardView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @State private var selectedAssetType: AssetType? = nil
    @State private var showingFilters = false
    @State private var showingAddTrade = false
    @StateObject private var dashboardCache = DashboardAnalyticsCache()
    
    // Défis (compact banner tout en haut)
    @State private var showingChallengesHome = false
    @State private var dashboardChallenges: [Challenge] = []
    @State private var didLoadChallenges = false
    
    var filteredTrades: [Trade] {
        let allTrades = appState.trades
        print("🔍 [DashboardView] filteredTrades calculé: \(allTrades.count) trades dans appState.trades")
        
        if let assetType = selectedAssetType {
            let filtered = allTrades.filter { trade in
                getAssetType(for: trade.symbol) == assetType
            }
            print("🔍 [DashboardView] Filtre actif (\(assetType.displayName)): \(filtered.count) trades après filtrage")
            return filtered
        }
        
        print("🔍 [DashboardView] Aucun filtre actif: \(allTrades.count) trades retournés")
        return allTrades
    }
    
    // ⚠️ Analytics dashboard = cache (zéro calcul en View)
    
    var hasActiveFilter: Bool {
        selectedAssetType != nil
    }
    
    // ✅ Single rebuild trigger key (no date math here)
    private var dashboardRebuildKey: String {
        "\(appState.trades.count)-\(appState.moodEntries.count)-\(appState.emotionalLoadVersion)-\(languageManager.currentLanguage.rawValue)"
    }
    
    var body: some View {
        let _ = print("🔍 [DashboardView] body recalculé - appState.trades.count = \(appState.trades.count), filteredTrades.count = \(filteredTrades.count)")
        return NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dashboardHeader
                    // ⚠️ MASQUÉ TEMPORAIREMENT - Défis désactivés
                    // dashboardChallengesBar
                    activeFilterBadge
                    filterChipsSection
                    dashboardContent
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddTrade) {
                AddTradeSelectionView()
            }
            // ⚠️ MASQUÉ TEMPORAIREMENT - Défis désactivés
            // .sheet(isPresented: $showingChallengesHome) {
            //     ChallengesHomeView()
            //         .environmentObject(appState)
            // }
            .onAppear {
                print("🔍 [DashboardView] DashboardView onAppear - appState.trades.count = \(appState.trades.count)")
            }
            // ⚠️ MASQUÉ TEMPORAIREMENT - Chargement des challenges désactivé
            // .task {
            //     if !didLoadChallenges {
            //         didLoadChallenges = true
            //         await loadDashboardChallenges()
            //     }
            // }
            .task(id: dashboardRebuildKey) {
                dashboardCache.rebuild(
                    trades: appState.trades,
                    moodEntries: appState.moodEntries,
                    emotionalLoadByDay: appState.emotionalLoadByDay,
                    language: LanguageManager.shared.currentLanguage
                )
            }
        }
    }
    
    // MARK: - Sub-views pour simplifier le body
    
    private var dashboardHeader: some View {
        HStack {
            Text(t("dashboard"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            // 🌍 Sélecteur de langue
            LanguageSelector()
            
            Button(action: {
                showingAddTrade = true
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.success)
            }
            
            Button(action: {
                HapticFeedback.selection()
                withAnimation(AppAnimations.standard) {
                    showingFilters.toggle()
                }
            }) {
                ZStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(AppColors.primary)
                    
                    if hasActiveFilter {
                        Circle()
                            .fill(AppColors.error)
                            .frame(width: 10, height: 10)
                            .offset(x: 8, y: -8)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var activeFilterBadge: some View {
        if hasActiveFilter, let assetType = selectedAssetType {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(t("name"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring()) {
                        selectedAssetType = nil
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.15))
            )
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private var filterChipsSection: some View {
        if showingFilters {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Tous",
                    isSelected: selectedAssetType == nil,
                    action: {
                        withAnimation(.spring()) {
                            selectedAssetType = nil
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                
                ForEach(AssetType.allCases, id: \.self) { assetType in
                    FilterChip(
                        title: assetType.chipTitle,
                        isSelected: selectedAssetType == assetType,
                        action: {
                            withAnimation(.spring()) {
                                selectedAssetType = assetType
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    private var dashboardContent: some View {
        VStack(spacing: 20) {
            CoachIACardView(state: appState.coachIAState)
                .padding(.horizontal)
            
            UnifiedHeatmapBlock(cache: dashboardCache)
                .padding(.horizontal)
            
            UnifiedCurveBlock(cache: dashboardCache)
                .padding(.horizontal)
            
            if let summary = appState.coachIAState.dailySummary {
                IADailySummaryCard(summary: summary)
                    .padding(.horizontal)
            }
            
            EmotionPerformanceCard()
                .padding(.horizontal)
            
            PerformanceWidgetsView(trades: filteredTrades)
                .padding(.horizontal)
            
            StatisticsCardsView(trades: filteredTrades)
                .onAppear {
                    print("🔍 [DashboardView] StatisticsCardsView apparaît avec \(filteredTrades.count) trades")
                    print("🔍 [DashboardView] appState.trades.count = \(appState.trades.count)")
                }
            
            AssetTypeBreakdownView(trades: appState.trades)
                .environmentObject(appState)
        }
    }

    // MARK: - Défis du moment (Dashboard)
    // ⚠️ MASQUÉ TEMPORAIREMENT - Défis et missions désactivés
    private var dashboardChallengesBar: some View {
        EmptyView()
    }

    @MainActor
    // ⚠️ MASQUÉ TEMPORAIREMENT - Fonction désactivée
    // private func loadDashboardChallenges() async {
    //     do {
    //         var daily = try await appState.challengeEngine.getDailyChallenges()
    //         if daily.isEmpty {
    //             daily = try await appState.challengeEngine.rollDaily()
    //         }
    //         dashboardChallenges = daily.sorted { a, b in
    //             if a.isCompleted != b.isCompleted { return !a.isCompleted }
    //             return a.expiresAt < b.expiresAt
    //         }
    //     } catch {
    //         dashboardChallenges = []
    //         print("❌ [DashboardView] Erreur chargement défis: \(error)")
    //     }
    // }
    
    private func getAssetType(for symbol: String) -> AssetType {
        let symbol = symbol.uppercased()
        
        // Crypto
        if ["BTC", "ETH", "ADA", "SOL", "MATIC", "LINK", "AAVE", "AVAX", "DOT", "UNI"].contains(where: { symbol.contains($0) }) {
            return .crypto
        }
        
        // Forex
        if symbol.contains("USD") || symbol.contains("EUR") || symbol.contains("GBP") || symbol.contains("JPY") {
            return .forex
        }
        
        // Stocks
        if symbol.count <= 5 && !symbol.contains("USDT") && !symbol.contains("USD") {
            return .stocks
        }
        
        // Futures
        if symbol.contains("FUT") || symbol.contains("PERP") {
            return .futures
        }
        
        // Options
        if symbol.contains("CALL") || symbol.contains("PUT") {
            return .options
        }
        
        return .crypto // Par défaut
    }
}

struct CoachIACardView: View {
    let state: CoachIAState
    
    private var scoreProgress: Double {
        Double(state.disciplineScore.value) / 100.0
    }
    
    private var scoreColor: Color {
        switch state.disciplineScore.band {
        case .elite: return AppColors.success
        case .high: return AppColors.accent
        case .medium: return AppColors.warning
        case .low: return AppColors.error
        }
    }
    
    private var formatter: RelativeDateTimeFormatter {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(t("ai"))
                        .font(AppTypography.captionMedium)
                        .textCase(.uppercase)
                        .foregroundColor(AppColors.textSecondary)
                    Text(state.message.headline)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                TrendPillView(trend: state.disciplineScore.trend)
            }
            
            Text(state.message.body)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(t("scoreDeDiscipline"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(Int(state.disciplineScore.value))/100")
                        .font(AppTypography.labelMedium)
                        .foregroundColor(scoreColor)
                }
                
                ProgressView(value: scoreProgress)
                    .accentColor(scoreColor)
                    .scaleEffect(y: 1.2, anchor: .center)
            }
            
            WeeklyGoalSummaryView(goal: state.weeklyGoal)
            
            if !state.history.isEmpty {
                DisciplineHistorySparkline(history: state.history)
            }
            
            if let objective = state.objective {
                Divider().background(AppColors.border.opacity(0.6))
                ObjectiveCard(objective: objective)
            }
            
            Text("Mis à jour \(formatter.localizedString(for: state.message.generatedAt, relativeTo: Date()))")
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.cardBackground,
                            AppColors.cardBackground.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.xlarge)
                        .stroke(AppColors.primary.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: AppColors.primary.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

struct TrendPillView: View {
    let trend: Int
    
    var body: some View {
        let symbol = trend >= 0 ? "arrow.up.right" : "arrow.down.right"
        let tint = trend >= 0 ? AppColors.success : AppColors.error
        let text = trend == 0 ? "Stable" : "\(trend >= 0 ? "+" : "")\(trend) pts"
        
        return HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text)
                .fontWeight(.semibold)
        }
        .font(AppTypography.captionSmall)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs)
        .background(tint.opacity(0.15))
        .foregroundColor(tint)
        .clipShape(Capsule())
    }
}

struct WeeklyGoalSummaryView: View {
    let goal: WeeklyGoal
    
    private var deadlineText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMM"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: goal.deadline).capitalized
    }
    
    private var progressPercentage: Int {
        Int(goal.progress * 100)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                HStack(spacing: AppSpacing.xs) {
                    Text(goal.focus.emoji)
                    Text(goal.focus.displayName)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Text(deadlineText)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textTertiary)
            }
            
            Text(goal.title)
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
            
            Text(goal.description)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(2)
            
            ProgressView(value: goal.progress)
                .accentColor(AppColors.primary)
            
            Text("\(Int(goal.progress * 100))%")
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DisciplineHistorySparkline: View {
    let history: [DisciplineScoreSnapshot]
    
    var body: some View {
        let sorted = history.sorted { $0.recordedAt < $1.recordedAt }
        
        return Chart {
            ForEach(sorted) { snapshot in
                AreaMark(
                    x: .value("Date", snapshot.recordedAt),
                    y: .value("Score", snapshot.score)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.4), AppColors.primary.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                LineMark(
                    x: .value("Date", snapshot.recordedAt),
                    y: .value("Score", snapshot.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppColors.primary)
                .lineStyle(.init(lineWidth: 2))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 80)
    }
}

struct ObjectiveCard: View {
    let objective: CoachIAObjective
    
    private var deadlineText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: objective.dueDate)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(t("ai"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Text(objective.title)
                .font(AppTypography.labelLarge)
                .foregroundColor(AppColors.textPrimary)
            
            Text(objective.rationale)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Label(objective.targetMetric, systemImage: "target")
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                Text(deadlineText)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground.opacity(0.9))
        )
    }
}

struct SparklinePnLCard: View {
    let data: [ChartData]
    
    private var latestValue: Double {
        data.last?.value ?? 0
    }
    
    private var variation: Double {
        guard let first = data.first?.value else { return 0 }
        return latestValue - first
    }
    
    private var isPositive: Bool {
        variation >= 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(t("plCumulatif7Jours"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Text(String(format: "%+.2f $", latestValue))
                        .font(AppTypography.titleMedium)
                        .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                }
                
                Spacer()
                
                VariationBadge(variation: variation)
            }
            
            Chart {
                ForEach(data) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("P&L", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                (isPositive ? AppColors.success : AppColors.error).opacity(0.4),
                                AppColors.cardBackground.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("P&L", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(isPositive ? AppColors.success : AppColors.error)
                    .lineStyle(.init(lineWidth: 2))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 80)
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .shadow(color: AppColors.primary.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }
}

struct VariationBadge: View {
    let variation: Double
    
    var body: some View {
        let isPositive = variation >= 0
        let color = isPositive ? AppColors.success : AppColors.error
        let symbol = isPositive ? "arrow.up.right" : "arrow.down.right"
        
        return HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(String(format: "%+.2f", variation))
        }
        .font(AppTypography.captionMedium)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xxs)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

struct IADailySummaryCard: View {
    let summary: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Text("💬") // TODO: Traduire avec clé appropriée
                Text(t("ai"))
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
            }
            Text(summary)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isSelected ?
                                AppGradients.primary :
                                LinearGradient(colors: [AppColors.cardBackground], startPoint: .leading, endPoint: .leading)
                        )
                )
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                )
                .scaleEffect(isSelected ? 1.02 : 1.0)
                .shadow(color: isSelected ? AppColors.primary.opacity(0.3) : Color.clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct DashboardChallengeRow: View {
    let challenge: Challenge

    private var progress: Double {
        guard challenge.targetValue > 0 else { return 0 }
        return min(1.0, Double(challenge.currentValue) / Double(challenge.targetValue))
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 3)
                    .frame(width: 18, height: 18)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(challenge.isCompleted ? AppColors.success : AppColors.primary,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 18, height: 18)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)

                ProgressView(value: progress)
                    .tint(challenge.isCompleted ? AppColors.success : AppColors.primary)
                    .scaleEffect(y: 0.8)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(challenge.currentValue)/\(challenge.targetValue)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)

                Text("\(challenge.rewardXP) XP")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct StatisticsCardsView: View {
    @EnvironmentObject var appState: AppState
    let trades: [Trade]
    
    var totalPnL: Double {
        let pnl = trades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
        // Debug: afficher le PnL calculé
        if trades.count > 0 {
            print("📊 [StatisticsCardsView] Calcul PnL total: \(pnl) pour \(trades.count) trades")
        }
        return pnl
    }
    
    var totalFees: Double {
        trades.reduce(0) { $0 + appState.fees(for: $1) }
    }
    
    var winRate: Double {
        let tradesWithPnL = trades.compactMap { trade -> (Trade, Double)? in
            guard let pnl = appState.netPnL(for: trade) else { return nil }
            return (trade, pnl)
        }
        guard !tradesWithPnL.isEmpty else { return 0 }
        let winningTrades = tradesWithPnL.filter { $0.1 > 0 }
        return Double(winningTrades.count) / Double(tradesWithPnL.count) * 100
    }
    
    var totalTrades: Int {
        let count = trades.count
        // Debug: afficher le nombre de trades
        if count > 0 {
            print("📊 [StatisticsCardsView] Nombre de trades: \(count)")
        }
        return count
    }
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            StatCard(
                title: "P&L Total",
                value: String(format: "$%.2f", totalPnL),
                color: totalPnL >= 0 ? .green : .red
            )
            
            StatCard(
                title: "Frais Total",
                value: String(format: "$%.2f", totalFees),
                color: .orange
            )
            
            StatCard(
                title: "Win Rate",
                value: String(format: "%.1f%%", winRate),
                color: winRate >= 50 ? .green : .red
            )
            
            StatCard(
                title: "Total Trades",
                value: "\(totalTrades)",
                color: .blue
            )
        }
        .padding(.horizontal)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Text(value)
                .font(AppTypography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 4)
        )
    }
}

struct PnLChartView: View {
    let trades: [Trade]
    @EnvironmentObject var appState: AppState
    @State private var selectedTimeframe: Timeframe = .all
    @State private var selectedDataPoint: ChartData?
    @State private var selectedDate: Date?
    
    var cumulativePnL: [ChartData] {
        let sortedTrades = filteredTrades.sorted { $0.date < $1.date }
        var cumulative: Double = 0
        return sortedTrades.compactMap { trade -> ChartData? in
            guard let pnl = appState.netPnL(for: trade) else { return nil }
            cumulative += pnl
            return ChartData(date: trade.date, value: cumulative)
        }
    }
    
    var filteredTrades: [Trade] {
        switch selectedTimeframe {
        case .week:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return trades.filter { $0.date >= weekAgo }
        case .month:
            let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            return trades.filter { $0.date >= monthAgo }
        case .all:
            return trades
        }
    }
    
    var stats: ChartStats {
        let data = cumulativePnL
        let maxValue = data.map { $0.value }.max() ?? 0
        let minValue = data.map { $0.value }.min() ?? 0
        let lastValue = data.last?.value ?? 0
        return ChartStats(currentValue: lastValue, maxValue: maxValue, minValue: minValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("performancePl"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(t("trades"))
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    // Légende interactive discrète
                    if selectedDataPoint != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption2)
                                .foregroundColor(AppColors.primary)
                            Text(t("pointSlectionn"))
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                Spacer()
                timeframeSelector
            }
            .padding(.horizontal)
            
            if !cumulativePnL.isEmpty {
                chartContent
            } else {
                emptyChartState
            }
        }
    }
    
    private var timeframeSelector: some View {
        HStack(spacing: 8) {
            ForEach(Timeframe.allCases, id: \.self) { timeframe in
                Button(action: {
                    HapticFeedback.light()
                    withAnimation {
                        selectedTimeframe = timeframe
                    }
                }) {
                    Text(timeframe.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTimeframe == timeframe ? .white : .gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedTimeframe == timeframe ? AppColors.primary : AppColors.cardBackground)
                        )
                }
            }
        }
    }
    
    private var gradientColors: [Color] {
        if stats.currentValue >= 0 {
            return [AppColors.success.opacity(0.3), AppColors.success.opacity(0.05)]
        } else {
            return [AppColors.error.opacity(0.3), AppColors.error.opacity(0.05)]
        }
    }
    
    private var chartContent: some View {
        VStack(spacing: 12) {
            statsRow
            
            if let selected = selectedDataPoint {
                selectedPointCard(selected)
            }
            
            mainChartView
            
            breakdownChips
        }
        .padding(.horizontal)
    }
    
    private var mainChartView: some View {
        ZStack {
            // Graphique principal
            Chart(cumulativePnL) { data in
                AreaMark(
                    x: .value("Date", data.date, unit: .day),
                    yStart: .value("Zero", 0),
                    yEnd: .value("P&L", data.value)
                )
                .foregroundStyle(LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom))
                
                let lineColor = stats.currentValue >= 0 ? AppColors.success : AppColors.error
                LineMark(x: .value("Date", data.date, unit: .day), y: .value("P&L", data.value))
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                    .symbol {
                        Circle()
                            .fill(lineColor)
                            .frame(width: 4, height: 4)
                    }
                
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                
                // Selected point marker avec animation
                if let selected = selectedDataPoint, selected.id == data.id {
                    PointMark(x: .value("Date", data.date, unit: .day), y: .value("P&L", data.value))
                        .foregroundStyle(AppColors.primary)
                        .symbolSize(120)
                        .symbol {
                            Circle()
                                .fill(AppColors.primary)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .shadow(color: AppColors.primary.opacity(0.5), radius: 4)
                        }
                }
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(AppColors.border.opacity(0.3))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(AppColors.textSecondary).font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(AppColors.border.opacity(0.3))
                    if let doubleValue = value.as(Double.self) {
                        AxisValueLabel {
                            Text(formatCompactNumber(doubleValue))
                                .foregroundStyle(AppColors.textSecondary)
                                .font(.caption2)
                        }
                    }
                }
            }
            
            // Overlay interactif pour sélection de point
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleChartInteraction(at: value.location)
                        }
                )
                .onTapGesture { location in
                    handleChartTap(at: location)
                }
        }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(AppColors.cardBackground)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1))
            )
            .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 2)
    }
    
    private var statsRow: some View {
        HStack(spacing: 16) {
            StatMiniChip(label: "Actuel", value: String(format: "$%.0f", stats.currentValue),
                        color: stats.currentValue >= 0 ? AppColors.success : AppColors.error)
            StatMiniChip(label: "Max", value: String(format: "$%.0f", stats.maxValue), color: AppColors.success)
            if stats.minValue < 0 {
                StatMiniChip(label: "Min", value: String(format: "$%.0f", stats.minValue), color: AppColors.error)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    private var breakdownChips: some View {
        HStack(spacing: 8) {
            let tradesWithPnL = filteredTrades.compactMap { trade -> (Trade, Double)? in
                guard let pnl = appState.netPnL(for: trade) else { return nil }
                return (trade, pnl)
            }
            let wins = tradesWithPnL.filter { $0.1 > 0 }.count
            let losses = tradesWithPnL.filter { $0.1 < 0 }.count
            BreakdownChip(color: AppColors.success, count: wins, label: "Gains")
            BreakdownChip(color: AppColors.error, count: losses, label: "Pertes")
            Spacer()
        }
    }
    
    private func selectedPointCard(_ data: ChartData) -> some View {
        let index = cumulativePnL.firstIndex(where: { $0.id == data.id }) ?? 0
        let sortedTrades = filteredTrades.sorted { $0.date < $1.date }
        let tradeAtPoint = index < sortedTrades.count ? sortedTrades[index] : sortedTrades.first
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("pointSlectionn"))
                        .font(.caption2)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(dateFormatter.string(from: data.date))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "$%.2f", data.value))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(data.value >= 0 ? AppColors.success : AppColors.error)
                    
                    if let trade = tradeAtPoint, let pnl = appState.netPnL(for: trade) {
                        HStack(spacing: 4) {
                            Image(systemName: pnl >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            Text(String(format: "$%.2f", abs(pnl)))
                                .font(.caption2)
                        }
                        .foregroundColor(pnl >= 0 ? AppColors.success : AppColors.error)
                    }
                }
            }
            
            // Détails du trade si disponible
            if let trade = tradeAtPoint {
                Divider()
                    .background(AppColors.border.opacity(0.3))
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("trades"))
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                        Text("\(trade.symbol) \(trade.type.rawValue.uppercased())")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    if let entry = trade.entryPrice, let exit = trade.exitPrice {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("price"))
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                            Text("$\(String(format: "%.2f", entry)) → $\(String(format: "%.2f", exit))")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    
                    if let qty = trade.quantity {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("quantity"))
                                .font(.caption2)
                                .foregroundColor(AppColors.textSecondary)
                            Text(String(format: "%.4f", qty))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // Bouton pour voir les détails du trade
            if tradeAtPoint != nil {
                Button(action: {
                    // Navigation vers les détails du trade
                    HapticFeedback.medium()
                    // TODO: Implémenter la navigation vers TradeDetailView
                }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text(t("ai"))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppColors.primary.opacity(0.1))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.primary.opacity(0.3), lineWidth: 2)
                )
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var emptyChartState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 48)).foregroundColor(AppColors.textSecondary)
            Text(t("noData")).font(.subheadline).foregroundColor(AppColors.textSecondary)
        }
        .frame(height: 220).frame(maxWidth: .infinity)
        .padding().background(RoundedRectangle(cornerRadius: AppRadius.large).fill(AppColors.cardBackground))
    }
    
    
    private func formatCompactNumber(_ value: Double) -> String {
        let absValue = abs(value)
        if absValue >= 1000000 {
            return String(format: "%.1fM", value / 1000000)
        } else if absValue >= 1000 {
            return String(format: "%.1fK", value / 1000)
        } else {
            return String(format: "%.0f", value)
        }
    }
    
    // MARK: - Chart Interaction Functions
    private func handleChartTap(at location: CGPoint) {
        HapticFeedback.selection()
        selectNearestPoint(at: location)
    }
    
    private func handleChartInteraction(at location: CGPoint) {
        selectNearestPoint(at: location)
    }
    
    private func selectNearestPoint(at location: CGPoint) {
        guard !cumulativePnL.isEmpty else { return }
        
        // Calculer le point le plus proche basé sur la position X
        // Approximation simple : trouver le point le plus proche de la position X
        let sortedData = cumulativePnL.sorted { $0.date < $1.date }
        
        // Calculer la position relative dans le graphique (0.0 à 1.0)
        // Note: Cette implémentation est simplifiée, une vraie implémentation nécessiterait
        // de connaître les dimensions exactes du graphique
        let relativeX = location.x / 300.0 // Approximation de la largeur
        let clampedX = max(0.0, min(1.0, relativeX))
        let index = Int(clampedX * Double(sortedData.count - 1))
        let clampedIndex = max(0, min(sortedData.count - 1, index))
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDataPoint = sortedData[clampedIndex]
            selectedDate = sortedData[clampedIndex].date
        }
    }
}

struct StatMiniChip: View {
    let label: String
    let value: String
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundColor(AppColors.textSecondary)
                Text(value).font(.caption).fontWeight(.semibold).foregroundColor(color)
            }
        }
    }
}

struct BreakdownChip: View {
    let color: Color
    let count: Int
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color.opacity(0.2)).frame(width: 24, height: 24)
                .overlay(Text("\(count)").font(.caption2).fontWeight(.bold).foregroundColor(color))
            Text(label).font(.caption).foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.1)))
    }
}

enum Timeframe: String, CaseIterable {
    case week, month, all
    var title: String {
        switch self {
        case .week: return "7j"
        case .month: return "30j"
        case .all: return "Tout"
        }
    }
}

struct ChartStats {
    let currentValue: Double
    let maxValue: Double
    let minValue: Double
}

struct AssetTypeBreakdownView: View {
    @EnvironmentObject var appState: AppState
    let trades: [Trade]
    
    var assetTypeStats: [AssetTypeStat] {
        let grouped = Dictionary(grouping: trades) { trade in
            getAssetType(for: trade.symbol)
        }
        
        return AssetType.allCases.map { assetType in
            let tradesForType = grouped[assetType] ?? []
            let totalPnL = tradesForType.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            return AssetTypeStat(
                type: assetType,
                count: tradesForType.count,
                totalPnL: totalPnL
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(t("type"))
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(assetTypeStats, id: \.type) { stat in
                    AssetTypeCard(stat: stat)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func getAssetType(for symbol: String) -> AssetType {
        let symbol = symbol.uppercased()
        
        if ["BTC", "ETH", "ADA", "SOL", "MATIC", "LINK", "AAVE", "AVAX", "DOT", "UNI"].contains(where: { symbol.contains($0) }) {
            return .crypto
        }
        
        if symbol.contains("USD") || symbol.contains("EUR") || symbol.contains("GBP") || symbol.contains("JPY") {
            return .forex
        }
        
        if symbol.count <= 5 && !symbol.contains("USDT") && !symbol.contains("USD") {
            return .stocks
        }
        
        if symbol.contains("FUT") || symbol.contains("PERP") {
            return .futures
        }
        
        if symbol.contains("CALL") || symbol.contains("PUT") {
            return .options
        }
        
        return .crypto
    }
}

struct AssetTypeCard: View {
    let stat: AssetTypeStat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: stat.type.icon)
                    .foregroundColor(stat.type.color)
                
                Text(stat.type.displayName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            
            Text("\(stat.count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(String(format: "$%.2f", stat.totalPnL))
                .font(.caption)
                .foregroundColor(stat.totalPnL >= 0 ? .green : .red)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Data Models

enum AssetType: String, CaseIterable {
    case crypto = "crypto"
    case forex = "forex"
    case stocks = "stocks"
    case futures = "futures"
    case options = "options"
    
    var displayName: String {
        switch self {
        case .crypto: return "Crypto"
        case .forex: return "Forex"
        case .stocks: return "Actions"
        case .futures: return "Futures"
        case .options: return "Options"
        }
    }

    /// Titre ultra-compact pour la rangée de filtres (doit tenir sur une seule ligne).
    var chipTitle: String {
        switch self {
        case .crypto: return "Crypto"
        case .forex: return "FX"
        case .stocks: return "Stocks"
        case .futures: return "Fut."
        case .options: return "Opt."
        }
    }
    
    var icon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle"
        case .forex: return "dollarsign.circle"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .futures: return "arrow.triangle.2.circlepath"
        case .options: return "chart.bar.xaxis"
        }
    }
    
    var color: Color {
        switch self {
        case .crypto: return .orange
        case .forex: return .blue
        case .stocks: return .green
        case .futures: return .purple
        case .options: return .red
        }
    }
}

struct ChartData: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct AssetTypeStat {
    let type: AssetType
    let count: Int
    let totalPnL: Double
}

#Preview {
    DashboardView()
        .environmentObject(AppState.shared)
}
