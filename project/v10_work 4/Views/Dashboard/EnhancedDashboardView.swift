import Foundation
import SwiftUI
import Combine

struct EnhancedDashboardView: View {
    @EnvironmentObject var appState: AppState
    @Binding var language: Localizable.Language
    @StateObject var dashboardCache = DashboardAnalyticsCache()
    @State var showAddTrade = false
    #if DEBUG
    @State var showDevMenu = false
    #endif
    @State var showHeatmap = false
    @State var showCumulativePnL = false
    @State var showOnboarding = false
    @State var showSubscription = false
    @State var showAPIConfig = false
    @State var showStorageSettings = false
    @State var showProfile = false
    @State var showChallengesHome = false
    @State var showMission = false
    @State var showReferral = false
    @State var showMEXCImport = false
    @State var showResetDataConfirmation = false
    @State var isResettingData = false
    @State var selectedGoal: TradingGoal?
    @State var selectedPeriod: PeriodFilter = .all
    @State var selectedAnalyticsTab: AnalyticsTab = .analytics
    // ✅ Personnalisation des plages horaires / sessions (Analyses avancées)
    @AppStorage("dash.hourRangesJSON") var hourRangesJSON: String = ""
    @AppStorage("dash.sessionRangesJSON") var sessionRangesJSON: String = ""
    @State var hourRanges: [DashboardTimeRange] = DashboardTimeRange.defaultHourRanges
    @State var sessionRanges: [DashboardTimeRange] = DashboardTimeRange.defaultSessionRanges
    @State var didLoadTimeRanges: Bool = false
    @State var showingHourRangesEditor: Bool = false
    @State var showingSessionRangesEditor: Bool = false
    @State var showLogin = false
    @State var showSignUp = false
    @State var assetFilter: AssetFilter = .all
    @State var showDashboardSettings = false
    @State var toolbarId = UUID()
    
    // ✅ Dashboard — respiration / hiérarchie (Essentiel vs Détails)
    @State var isDetailsExpanded: Bool = false
    
    var detailsSectionsCount: Int {
        (showAdvancedMetrics ? 1 : 0) + (showAnalytics ? 1 : 0) + (showEmotionalSummary ? 1 : 0)
    }

    // User preferences (persisted)
    @AppStorage("dash.showChallenges") var showChallenges: Bool = true
    @AppStorage("dash.showQuickActions") var showQuickActions: Bool = true
    @AppStorage("dash.showMainMetrics") var showMainMetrics: Bool = true
    @AppStorage("dash.showAdvancedMetrics") var showAdvancedMetrics: Bool = true
    @AppStorage("dash.showPerformances") var showPerformances: Bool = true
    @AppStorage("dash.showAnalytics") var showAnalytics: Bool = true
    @AppStorage("dash.showEmotionalSummary") var showEmotionalSummary: Bool = true
    @AppStorage("dash.assetFilter") var storedAssetFilter: String = "all"
    
    var dashboardRebuildKey: String {
        "\(filteredTrades.count)-\(appState.moodEntries.count)-\(appState.emotionalLoadVersion)-\(language.rawValue)"
    }

    /// Driver invisible pour déclencher le rebuild du cache sans alourdir le type-checker du `body`.
    var cacheRebuildDriver: some View {
        Color.clear
            .task(id: dashboardRebuildKey) {
                dashboardCache.rebuild(
                    trades: filteredTrades,
                    moodEntries: appState.moodEntries,
                    emotionalLoadByDay: appState.emotionalLoadByDay,
                    language: language
                )
            }
    }
    
    var stats: Statistics {
        print("📊 [EnhancedDashboardView.stats] Calcul avec \(filteredTrades.count) trades (appState.trades: \(appState.trades.count))")
        let result = Statistics.calculate(trades: filteredTrades, appState: appState)
        print("📊 [EnhancedDashboardView.stats] Résultat: \(result.totalTrades) trades, PnL total: \(result.totalPnL), Win rate: \(result.winRate)%")
        return result
    }
    
    // MARK: - Analytics Data
    var monthlyPerformance: [Double] {
        let calendar = Calendar.current
        let now = Date()
        var monthlyData: [Double] = []
        
        for i in 0..<12 {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: now),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                monthlyData.append(0)
                continue
            }
            
            let monthTrades = filteredTrades.filter { trade in
                trade.date >= monthStart && trade.date < monthEnd
            }
            
            let monthPnL = monthTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            monthlyData.append(monthPnL)
        }
        
        return monthlyData.reversed()
    }
    
    var bestMonth: Double {
        monthlyPerformance.max() ?? 0
    }
    
    var worstMonth: Double {
        monthlyPerformance.min() ?? 0
    }
    
    var averageMonth: Double {
        monthlyPerformance.isEmpty ? 0 : monthlyPerformance.reduce(0, +) / Double(monthlyPerformance.count)
    }
    
    var hourlyPerformance: [String: Double] {
        let calendar = Calendar.current
        var hourlyData: [String: Double] = [:]
        for range in hourRanges {
            let rangeTrades = filteredTrades.filter { trade in
                let hour = calendar.component(.hour, from: trade.date)
                return range.contains(hour: hour)
            }
            let rangePnL = rangeTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            hourlyData[range.label] = rangePnL
        }
        
        return hourlyData
    }
    
    var sessionPerformance: [String: Double] {
        let calendar = Calendar.current
        var data: [String: Double] = [:]
        
        for session in sessionRanges {
            let rangeTrades = filteredTrades.filter { trade in
                let hour = calendar.component(.hour, from: trade.date)
                return session.contains(hour: hour)
            }
            let rangePnL = rangeTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            data[session.label] = rangePnL
        }
        
        return data
    }
    
    var dailyPerformance: [String: Double] {
        let calendar = Calendar.current
        var dailyData: [String: Double] = [:]
        // ✅ 7 jours (Lun→Dim) incluant week-end
        let days: [(label: String, weekdayNumber: Int)] = [
            ("Lun", 2),
            ("Mar", 3),
            ("Mer", 4),
            ("Jeu", 5),
            ("Ven", 6),
            ("Sam", 7),
            ("Dim", 1)
        ]
        
        for (label, weekdayNumber) in days {
            let dayTrades = filteredTrades.filter { trade in
                calendar.component(.weekday, from: trade.date) == weekdayNumber
            }
            let dayPnL = dayTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            dailyData[label] = dayPnL
        }
        
        return dailyData
    }
    
    var timeMetricsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // ✅ Plus d'aération avec l'onglet selector
            Color.clear.frame(height: AppSpacing.md)
            
            // Performance par Heure (plages personnalisables)
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                Text(Localizable.text("performanceByHour", language: language))
                            .font(AppTypography.headlineSmall)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(Localizable.text("customizableRanges", language: language))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        HapticFeedback.selection()
                        showingHourRangesEditor = true
                    } label: {
                        Label(Localizable.text("modify", language: language), systemImage: "slider.horizontal.3")
                            .font(AppTypography.captionMedium)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.primary)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                    ForEach(hourRanges, id: \.id) { range in
                        let value = hourlyPerformance[range.label] ?? 0
                        let isPositive = value >= 0
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(range.label)
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                            
                            Text(formatCompactNumber(value))
                                .font(AppTypography.titleMedium)
                                .fontWeight(.bold)
                                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(AppColors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(isPositive ? AppColors.success.opacity(0.28) : AppColors.error.opacity(0.28), lineWidth: 1)
                                )
                        )
                    }
                    
                    // 🎁 Bonus UX: “+ Ajouter” en carte secondaire, en bas de la liste
                    AddDashedCard(title: Localizable.text("add", language: language), subtitle: Localizable.text("hourRange", language: language)) {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            hourRanges.append(.init(name: "Nouvelle plage", startHour: 9, endHour: 12))
                        }
                        showingHourRangesEditor = true
                    }
                }
            }
            
            Divider().overlay(AppColors.border.opacity(0.25))
            
            // ✅ Performance par Session (plages personnalisables)
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                        Text("Performance par Session")
                            .font(AppTypography.headlineSmall)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Asie / Londres / New York • Personnalisable")
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        HapticFeedback.selection()
                        showingSessionRangesEditor = true
                    } label: {
                        Label("Modifier", systemImage: "clock.badge.checkmark")
                            .font(AppTypography.captionMedium)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppColors.primary)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                    ForEach(sessionRanges, id: \.id) { session in
                        let value = sessionPerformance[session.label] ?? 0
                        let isPositive = value >= 0
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.name)
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                                .lineLimit(1)
                            
                            Text(session.label)
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textTertiary)
                                .lineLimit(1)
                            
                            Text(formatCompactNumber(value))
                                .font(AppTypography.titleMedium)
                                .fontWeight(.bold)
                                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                                .monospacedDigit()
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(AppColors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(isPositive ? AppColors.success.opacity(0.28) : AppColors.error.opacity(0.28), lineWidth: 1)
                                )
                        )
                    }
                    
                    // 🎁 Bonus UX: “+ Ajouter” en carte secondaire, en bas de la liste
                    AddDashedCard(title: Localizable.text("add", language: language), subtitle: Localizable.text("session", language: language)) {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            sessionRanges.append(.init(name: Localizable.text("newSession", language: language), startHour: 8, endHour: 16))
                        }
                        showingSessionRangesEditor = true
                    }
                }
            }
            
            Divider().overlay(AppColors.border.opacity(0.25))
            
            // Performance par jour (7 jours)
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                    Text(Localizable.text("performanceByDay", language: language))
                        .font(AppTypography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(Localizable.text("mondayToSunday", language: language))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                // ✅ Grille 2 lignes (4 + 3) pour la lisibilité sur petits écrans
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 4), spacing: AppSpacing.sm) {
                    ForEach([
                        Localizable.text("monday", language: language),
                        Localizable.text("tuesday", language: language),
                        Localizable.text("wednesday", language: language),
                        Localizable.text("thursday", language: language),
                        Localizable.text("friday", language: language),
                        Localizable.text("saturday", language: language),
                        Localizable.text("sunday", language: language)
                    ], id: \.self) { day in
                        let value = dailyPerformance[day] ?? 0
                        let isPositive = value >= 0
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day)
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text(formatCompactNumber(value))
                                .font(AppTypography.titleSmall)
                                .fontWeight(.bold)
                                .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(AppColors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(isPositive ? AppColors.success.opacity(0.28) : AppColors.error.opacity(0.28), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }
    
    func formatCompactNumber(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        
        if absValue >= 1_000_000 {
            return "\(sign)$\(String(format: "%.1f", absValue / 1_000_000))M"
        } else if absValue >= 1_000 {
            return "\(sign)$\(String(format: "%.1f", absValue / 1_000))K"
        } else {
            return "\(sign)$\(String(format: "%.0f", absValue))"
        }
    }

    // MARK: - Optional Asset Filter
    var filteredTrades: [Trade] {
        let result: [Trade]
        switch assetFilter {
        case .all:
            result = appState.trades
        case .crypto, .forex, .stocks, .futures, .options:
            result = appState.trades.filter { classifyAsset(for: $0.symbol) == assetFilter }
        }
        
        // Debug: vérifier que les trades sont bien récupérés
        print("📊 [EnhancedDashboardView] filteredTrades: \(result.count) trades (assetFilter: \(assetFilter.rawValue), appState.trades: \(appState.trades.count))")
        
        // CORRECTION: Si le filtre exclut tous les trades mais qu'il y a des trades dans appState,
        // forcer assetFilter à .all pour afficher tous les trades
        if result.isEmpty && appState.trades.count > 0 && assetFilter != .all {
            print("⚠️ [EnhancedDashboardView] CORRECTION: Le filtre \(assetFilter.rawValue) exclut tous les trades, passage à .all")
            print("⚠️ [EnhancedDashboardView] Échantillon de trades: \(appState.trades.prefix(3).map { "\($0.symbol) (\(classifyAsset(for: $0.symbol).rawValue))" }.joined(separator: ", "))")
            // Retourner tous les trades au lieu d'un tableau vide
            return appState.trades
        }
        
        if result.isEmpty && appState.trades.count > 0 {
            print("⚠️ [EnhancedDashboardView] ATTENTION: filteredTrades est vide alors que appState.trades contient \(appState.trades.count) trades")
        }
        
        return result
    }
    
    enum AssetFilter: String, CaseIterable, Identifiable {
        case all, crypto, forex, stocks, futures, options
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .all: return "Tous"
            case .crypto: return "Crypto"
            case .forex: return "Forex"
            case .stocks: return "Actions"
            case .futures: return "Futures"
            case .options: return "Options"
            }
        }
    }
    
    func classifyAsset(for symbol: String) -> AssetFilter {
        let s = symbol.uppercased()
        if ["BTC","ETH","SOL","ADA","LINK","AVAX","DOT","MATIC","UNI","AAVE"].contains(where: { s.contains($0) }) { return .crypto }
        if s.contains("USDT") || s.contains("USDC") { return .crypto }
        if s.contains("USD") || s.contains("EUR") || s.contains("GBP") || s.contains("JPY") { return .forex }
        if s.contains("PERP") || s.contains("FUT") { return .futures }
        if s.contains("CALL") || s.contains("PUT") { return .options }
        if s.count <= 5 && !s.contains("USD") { return .stocks }
        return .crypto
    }
    
    // Menu de langue simplifié - uniquement les options de langue
    var languageMenu: some View {
        Menu {
            ForEach(Localizable.Language.allCases) { lang in
                Button(action: {
                    HapticFeedback.selection()
                    language = lang
                }) {
                    let flagText = lang.flag
                    let langCode = lang.rawValue.uppercased()
                    Text("\(flagText) \(langCode)")
                }
            }
        } label: {
            Text(language.flag)
        }
    }
    
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                dashboardTopBar
                dashboardContent
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarHidden(true)

            if showAdvancedMetrics || showAnalytics || showEmotionalSummary {
                stickyDeepenButton
                    .padding(.bottom, 83)
            }
        }
    }

    var body: some View {
        NavigationView {
            mainContent
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .background(cacheRebuildDriver)
        .onAppear {
            loadTimeRangesIfNeeded()
            // Force toolbar to be visible on appear
            print("📊 [EnhancedDashboardView.onAppear] Démarrage avec \(appState.trades.count) trades dans appState")
            print("📊 [EnhancedDashboardView.onAppear] assetFilter: \(assetFilter.rawValue)")
            print("📊 [EnhancedDashboardView.onAppear] filteredTrades: \(filteredTrades.count) trades")
        }
        .onChange(of: appState.trades) { oldTrades, newTrades in
            print("🔄 [EnhancedDashboardView] appState.trades a changé: \(oldTrades.count) → \(newTrades.count) trades")
            print("🔄 [EnhancedDashboardView] filteredTrades après changement: \(filteredTrades.count) trades")
            
            // Forcer une mise à jour de la vue
            toolbarId = UUID()
        }
        .onChange(of: showAddTrade) { _, newValue in
            if !newValue {
                // Toolbar should reappear when sheet closes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Force toolbar refresh
                }
            }
        }
        #if DEBUG
        .onChange(of: showDevMenu) { _, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Force toolbar refresh
                }
            }
        }
        #endif
        .onChange(of: showDashboardSettings) { _, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Force toolbar refresh
                }
            }
        }
        .onChange(of: showProfile) { _, newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // Force toolbar refresh
                }
            }
        }
        // ⚠️ MASQUÉ TEMPORAIREMENT - Défis désactivés
        // .onChange(of: showChallengesHome) { _, newValue in
        //     if !newValue {
        //         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        //             // Force toolbar refresh
        //         }
        //     }
        // }
        .sheet(isPresented: $showAddTrade) {
            AddTradeSelectionView()
        }
        #if DEBUG
        .sheet(isPresented: $showDevMenu) {
            DeveloperMenuView()
        }
        #endif
        .sheet(isPresented: $showDashboardSettings) {
            DashboardSettingsView(
                assetFilter: $assetFilter,
                showChallenges: $showChallenges,
                showQuickActions: $showQuickActions,
                showMainMetrics: $showMainMetrics,
                showAdvancedMetrics: $showAdvancedMetrics,
                showPerformances: $showPerformances,
                showAnalytics: $showAnalytics
            )
        }
        .sheet(isPresented: $showHeatmap) {
            DashboardHeatmapDetailView(cache: dashboardCache)
        }
        .sheet(isPresented: $showCumulativePnL) {
            DashboardCurveDetailView(cache: dashboardCache)
        }
        .sheet(isPresented: $showingHourRangesEditor) {
            TimeRangesEditorSheet(
                title: "Plages horaires",
                subtitle: "Ajoutez / supprimez / modifiez vos créneaux",
                ranges: $hourRanges,
                onSave: persistHourRanges
            )
        }
        .sheet(isPresented: $showingSessionRangesEditor) {
            TimeRangesEditorSheet(
                title: Localizable.text("sessions", language: language),
                subtitle: Localizable.text("sessionsDescription", language: language),
                ranges: $sessionRanges,
                onSave: persistSessionRanges
            )
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(selectedGoal: $selectedGoal)
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAPIConfig) {
            APIConfigurationView()
        }
        .sheet(isPresented: $showStorageSettings) {
            StorageSettingsView()
        }
        .sheet(isPresented: $showMEXCImport) {
            MEXCImportView()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView().environmentObject(appState)
        }
        // ⚠️ MASQUÉ TEMPORAIREMENT - Défis désactivés
        // .sheet(isPresented: $showChallengesHome) {
        //     ChallengesHomeView().environmentObject(appState)
        // }
        // ⚠️ MASQUÉ TEMPORAIREMENT - Missions désactivées
        // .sheet(isPresented: $showMission) {
        //     MissionView().environmentObject(appState)
        // }
        .sheet(isPresented: $showReferral) {
            ReferralView()
        }
        .sheet(isPresented: $showLogin) {
            LoginView().environmentObject(appState.authManager)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView().environmentObject(appState.authManager)
        }
        // ── Réinitialisation des données ────────────
        .alert("Réinitialiser les données", isPresented: $showResetDataConfirmation) {
            Button("Annuler", role: .cancel) {}
            Button("Réinitialiser", role: .destructive) {
                performUserDataReset()
            }
        } message: {
            Text("Cette action supprimera définitivement tous vos trades, émotions et systèmes.\n\nVotre compte et votre authentification resteront intacts.\n\nCette action est irréversible.")
        }
        .overlay {
            if isResettingData {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(AppColors.primary)
                            .scaleEffect(1.2)
                        Text("Réinitialisation en cours…")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .padding(28)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(AppColors.cardBackground)
                    )
                }
            }
        }
        .onAppear {
            print("📊 [EnhancedDashboardView.onAppear] storedAssetFilter: '\(storedAssetFilter)'")
            if let saved = AssetFilter(rawValue: storedAssetFilter) {
                print("📊 [EnhancedDashboardView.onAppear] Chargement assetFilter depuis @AppStorage: \(saved.rawValue)")
                assetFilter = saved
                
                // CORRECTION: Si le filtre sauvegardé exclut tous les trades, réinitialiser à .all
                let testFiltered = saved == .all ? appState.trades : appState.trades.filter { classifyAsset(for: $0.symbol) == saved }
                if testFiltered.isEmpty && appState.trades.count > 0 {
                    print("⚠️ [EnhancedDashboardView.onAppear] CORRECTION: Le filtre sauvegardé '\(saved.rawValue)' exclut tous les trades, réinitialisation à .all")
                    assetFilter = .all
                    storedAssetFilter = "all"
                }
            } else {
                print("📊 [EnhancedDashboardView.onAppear] Aucun assetFilter sauvegardé, utilisation de .all par défaut")
                assetFilter = .all
            }
            print("📊 [EnhancedDashboardView.onAppear] assetFilter final: \(assetFilter.rawValue)")
            print("📊 [EnhancedDashboardView.onAppear] appState.trades.count: \(appState.trades.count)")
            print("📊 [EnhancedDashboardView.onAppear] filteredTrades.count: \(filteredTrades.count)")
        }
        .onChange(of: assetFilter) { _, newValue in
            storedAssetFilter = newValue.rawValue
        }
    }

    // MARK: - Time ranges persistence (UserDefaults via AppStorage)
    func loadTimeRangesIfNeeded() {
        guard !didLoadTimeRanges else { return }
        didLoadTimeRanges = true
        
        if let decodedHours = decodeRanges(from: hourRangesJSON), !decodedHours.isEmpty {
            hourRanges = decodedHours
        }
        if let decodedSessions = decodeRanges(from: sessionRangesJSON), !decodedSessions.isEmpty {
            sessionRanges = decodedSessions
        }
    }
    
    func persistHourRanges() {
        hourRangesJSON = encodeRanges(hourRanges) ?? ""
    }
    
    func persistSessionRanges() {
        sessionRangesJSON = encodeRanges(sessionRanges) ?? ""
    }
    
    func decodeRanges(from json: String) -> [DashboardTimeRange]? {
        guard !json.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([DashboardTimeRange].self, from: data)
    }
    
    func encodeRanges(_ ranges: [DashboardTimeRange]) -> String? {
        guard let data = try? JSONEncoder().encode(ranges) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Reset User Data (Trades + Emotions + Systems)

    /// Supprime tous les trades, émotions et systèmes de manière sûre.
    /// Conserve le compte utilisateur et l'authentification.
    func performUserDataReset() {
        isResettingData = true
        Task {
            do {
                // 1. Supprimer tous les trades
                let allTrades = try await appState.tradeStore.fetchAll()
                for trade in allTrades {
                    try await appState.tradeStore.delete(trade)
                }
                print("✅ [Reset] \(allTrades.count) trades supprimés")

                // 2. Supprimer toutes les émotions
                let allMoods = appState.moodEntries
                for mood in allMoods {
                    try await appState.moodStore.deleteMood(mood.id)
                }
                print("✅ [Reset] \(allMoods.count) émotions supprimées")

                // 3. Supprimer tous les systèmes
                let allSystems = try await appState.systemStore.fetchAll()
                for system in allSystems {
                    try await appState.systemStore.delete(system)
                }
                print("✅ [Reset] \(allSystems.count) systèmes supprimés")

                // 4. Rafraîchir l'état local sur le MainActor
                await MainActor.run {
                    appState.trades.removeAll()
                    appState.moodEntries.removeAll()
                    appState.systems.removeAll()
                    isResettingData = false
                    toolbarId = UUID() // Force refresh UI
                    HapticFeedback.success()
                    print("✅ [Reset] Interface rafraîchie — dashboard vide")
                }
            } catch {
                print("❌ [Reset] Erreur: \(error.localizedDescription)")
                await MainActor.run {
                    isResettingData = false
                    HapticFeedback.error()
                }
            }
        }
    }
}

// MARK: - Dashboard Top Bar (Menu + badges)
