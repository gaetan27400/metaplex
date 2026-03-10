//
//  AIAssistantView.swift
//  Journal de trading 2025
//

import SwiftUI

struct AIAssistantView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }
    
    private var language: Localizable.Language { languageManager.currentLanguage }
    private var isFR: Bool { language == .french }

    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AssistantTab = .insights
    @State private var isRefreshing = false
    
    let initialTab: AssistantTab?
    
    init(initialTab: AssistantTab? = nil) {
        self.initialTab = initialTab
    }
    
    // MTF Dashboard (RSI + VMC combinés)
    @State private var mtfSnapshot: MTFSnapshot?
    @State private var isLoadingMTF = false
    @State private var wtSnapshot: WTSnapshot?
    @StateObject private var wtNotificationPrefs = WTNotificationPreferences.shared
    @State private var isLoadingWT = false
    @State private var wtTimeframe: WTTimeframe = .h1
    
    // VMC Oscillator (graphique dédié)
    @State private var vmcOscSnapshot: VMCOscillatorSnapshot?
    @State private var isLoadingVMCOsc = false
    @State private var vmcOscTimeframe: WTTimeframe = .h1
    
    // Actif sélectionné (multi-assets)
    @State private var selectedSymbol: MarketSymbol = .btcDefault
    
    // Calendrier économique (pour l'analyse enrichie)
    @StateObject private var economicStore = EconomicCalendarStore.shared
    @State private var economicPeriod: EconomicCalendarView.PeriodFilter = .week
    
    // Edge Score Details Sheet
    @State private var showEdgeScoreDetails = false
    @State private var isGeneratingPDF = false
    @State private var cachedEnrichedAnalysis: String = ""
    @State private var cachedEnrichedAnalysisKey: String = "" // pour invalider si données changent
    @State private var gptAnalysis: String = ""
    @State private var isLoadingGPTAnalysis: Bool = false
    @State private var gptAnalysisSymbol: String = "" // pour détecter changement de symbole
    @State private var currentPrice: Double = 0  // prix actuel de l'actif sélectionné
    private let assistantAIServiceShared = AssistantAIService() // singleton de vue, pas recrée à chaque rebuild
    @State private var pdfShareData: Data? = nil
    @State private var showPDFShareSheet = false
    @State private var currentAdvice: TradingAdviceSummary?
    
    private var report: AssistantAIReport { appState.assistantReport }
    
    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barre d'onglets compacte scrollable
            segmentedControl
                .background(AppColors.background)
            
            // Contenu scrollable
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header avec dernière mise à jour
                    lastUpdateHeader
                    
                    // Contenu des onglets
                    tabContent
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.xl)
                // `TradingJournalApp` gère désormais l'espace de la bottom bar via `safeAreaInset`.
                .padding(.bottom, AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
        }
        .navigationTitle("Assistant IA")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                refreshButton
            }
        }
        .onAppear {
            // Si un onglet initial est spécifié (ex: depuis un deep link ou partage d'image)
            if let initialTab = initialTab {
                selectedTab = initialTab
            }
            
            // Charger les données selon l'onglet — en parallèle pour éviter le freeze
            loadDataForTab(selectedTab)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Charger les données en parallèle pour éviter le freeze
            loadDataForTab(newValue)
            // Déclencher l'analyse GPT si on arrive sur l'onglet Analyse
            if newValue == .analyse && gptAnalysis.isEmpty && !isLoadingGPTAnalysis {
                Task { await loadGPTAnalysis() }
            }
        }
        .onChange(of: selectedSymbol) { _, newSymbol in
            // Mettre à jour le routage API
            MarketDataService.shared.activeMarketSymbol = newSymbol
            wtSnapshot = nil
            vmcOscSnapshot = nil
            mtfSnapshot = nil
            gptAnalysis = ""
            gptAnalysisSymbol = ""
            // Lancer les 3 chargements en parallèle
            Task { await loadWTSnapshot() }
            Task { await loadVMCOscillatorSnapshot() }
            Task { await loadMTFSnapshot() }
            // Lancer l'analyse GPT si onglet Analyse actif
            if selectedTab == .analyse {
                Task { await loadGPTAnalysis() }
            }
        }
    }
    
    private var lastUpdateHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "clock.fill")
                .font(.caption)
                .foregroundColor(AppColors.textTertiary)
            Text("\(Localizable.text("lastUpdate", language: LanguageManager.shared.currentLanguage)) : \(relativeFormatter.localizedString(for: report.generatedAt, relativeTo: Date()))")
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            // Bouton de rafraîchissement visible
            Button(action: {
                Task {
                    await refreshAnalytics()
                }
            }) {
                HStack(spacing: AppSpacing.xs) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(AppColors.primary)
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 18))
                    }
                    Text(isRefreshing ? Localizable.text("refreshing", language: LanguageManager.shared.currentLanguage) : Localizable.text("refresh", language: LanguageManager.shared.currentLanguage))
                        .font(AppTypography.captionMedium)
                        .fontWeight(.medium)
                }
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule()
                        .fill(AppColors.primary.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .disabled(isRefreshing)
        }
        .padding(.bottom, AppSpacing.xs)
    }
    
    private var refreshButton: some View {
        Button {
            Task {
                await refreshAnalytics()
            }
        } label: {
            HStack(spacing: AppSpacing.xs) {
                if isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .font(.title3)
            .foregroundColor(AppColors.primary)
        }
        .disabled(isRefreshing)
        .accessibilityLabel(Localizable.text("refreshAnalytics", language: LanguageManager.shared.currentLanguage))
    }
    
    private func refreshAnalytics() async {
        isRefreshing = true
        HapticFeedback.medium()
        
        // Régénérer les rapports IA de manière asynchrone
        await MainActor.run {
            appState.regenerateAIReports()
        }
        
        // Recharger les dashboards et le calendrier économique
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadMTFSnapshot() }
            group.addTask { await self.loadWTSnapshot() }
            group.addTask {
                let _ = try? await self.economicStore.loadEvents(for: self.economicPeriod, forceRefresh: true)
            }
        }
        
        
        await MainActor.run {
            isRefreshing = false
            HapticFeedback.success()
        }
    }
    
    private var segmentedControl: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(AssistantTab.allCases.prefix(3)), id: \.self) { tab in
                    AssistantTabButton(tab: tab, isSelected: selectedTab == tab) {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            HStack(spacing: 6) {
                ForEach(Array(AssistantTab.allCases.suffix(3)), id: \.self) { tab in
                    AssistantTabButton(tab: tab, isSelected: selectedTab == tab) {
                        HapticFeedback.selection()
                        withAnimation(.spring(response: 0.3)) {
                            selectedTab = tab
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .insights:
            insightsContent
        case .conseils:
            conseilsContent
        case .analyse:
            analyseContent
        case .indicateurs:
            indicateursContent
        case .photo:
            photoContent
        case .calendar:
            calendarContent
        }
    }
    
    private var insightsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // 1. Résumé IA
            if let summary = section(of: .summary) {
                AssistantSummaryCard(section: summary, accentColorHex: summary.accentColorHex)
            }
            
            // 2. Prédiction Prochain Trade
            predictionCard
            
            // 3. Émotion & Mental
            if let emotion = section(of: .emotion) {
                AssistantEmotionCard(section: emotion, accentColorHex: emotion.accentColorHex, emotionScore: appState.emotionScore)
            }
            
            // 4. Cohérence du Plan
            coherenceCard
            
            // 5. Timing Optimal
            timingCard
        }
    }
    
    // MARK: - Prédiction Prochain Trade
    
    private var predictionCard: some View {
        let trades = appState.trades.filter { $0.isClosed }
        let winCount = trades.filter { appState.netPnL(for: $0) ?? 0 > 0 }.count
        let winRate = trades.isEmpty ? 0.0 : Double(winCount) / Double(trades.count)
        let confidence = min(Double(trades.count) / 200.0, 1.0) * 100 // Confiance basée sur le volume de trades
        
        let pnls = trades.compactMap { appState.netPnL(for: $0) }
        let maxLoss = pnls.min() ?? 0
        let maxGain = pnls.max() ?? 0
        let avgWin = pnls.filter { $0 > 0 }.isEmpty ? 0 : pnls.filter { $0 > 0 }.reduce(0, +) / Double(pnls.filter { $0 > 0 }.count)
        let avgLoss = pnls.filter { $0 < 0 }.isEmpty ? 0 : abs(pnls.filter { $0 < 0 }.reduce(0, +) / Double(pnls.filter { $0 < 0 }.count))
        let expectancy = (winRate * avgWin) - ((1 - winRate) * avgLoss)
        
        let discipline = Double(appState.riskScore)
        
        return AssistantCardContainer(accentColor: Color.purple.opacity(0.6)) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(t("predictionNextTrade"))
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                Text(t("basedOnHistory"))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                
                Divider().opacity(0.3)
                
                // Probabilité de gain
                HStack {
                    Text(t("winProbability"))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(Int(winRate * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(winRate >= 0.5 ? .green : .red)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppColors.background).frame(height: 8)
                        Capsule().fill(winRate >= 0.5 ? Color.green : Color.red)
                            .frame(width: geo.size.width * winRate, height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Spacer()
                    Image(systemName: "face.smiling")
                        .foregroundColor(AppColors.textTertiary)
                    Text(t("confidence") + " : \(Int(confidence))%")
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textTertiary)
                    Spacer()
                }
                
                // Perte max / Gain max
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading) {
                        Text(t("maxLoss"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                        Text(String(format: "%.2f$", maxLoss))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    
                    VStack(alignment: .trailing) {
                        Text(t("maxGain"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                        Text(String(format: "%.2f$", maxGain))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
                
                // Espérance mathématique
                HStack {
                    Text(t("expectedValue"))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(String(format: "%.2f$", expectancy))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(expectancy >= 0 ? .green : .red)
                }
                
                // Facteurs influents
                Text(t("influencingFactors"))
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                HStack {
                    Image(systemName: discipline >= 60 ? "plus.circle.fill" : "minus.circle.fill")
                        .foregroundColor(discipline >= 60 ? .green : AppColors.textTertiary)
                    Text(t("discipline"))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text("\(Int(discipline))%")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Divider().opacity(0.3)
                
                // Recommandation
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("💡")
                        Text(t("recommendation"))
                            .font(AppTypography.captionMedium)
                            .foregroundColor(.pink)
                            .fontWeight(.bold)
                    }
                    Text(winRate >= 0.5
                         ? "✅ " + (isFR ? "Probabilité élevée (\(Int(winRate * 100))%) — conditions favorables pour trader" : "High probability (\(Int(winRate * 100))%) — favorable conditions to trade")
                         : "⚠️ " + (isFR ? "Probabilité faible (\(Int(winRate * 100))%) — prudence recommandée" : "Low probability (\(Int(winRate * 100))%) — caution recommended"))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding()
                .background(Color.pink.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
        }
    }
    
    // MARK: - Cohérence du Plan
    
    private var coherenceCard: some View {
        let trades = appState.trades.filter { $0.isClosed }
        let totalTrades = trades.count
        
        // Trades avec système assigné = disciplinés
        let tradesWithSystem = trades.filter { $0.systemId != UUID() }
        let adherence = totalTrades > 0 ? Double(tradesWithSystem.count) / Double(totalTrades) * 100 : 0
        
        // Meilleur système
        let systemPnL = Dictionary(grouping: trades, by: { $0.systemId })
            .mapValues { trades in trades.compactMap { appState.netPnL(for: $0) }.reduce(0, +) }
        let bestSystemId = systemPnL.max(by: { $0.value < $1.value })?.key
        let worstSystemId = systemPnL.min(by: { $0.value < $1.value })?.key
        let bestSystemName = appState.systems.first(where: { $0.id == bestSystemId })?.name ?? "—"
        let worstSystemName = appState.systems.first(where: { $0.id == worstSystemId })?.name ?? "—"
        
        // Trades impulsifs (sans système ou système par défaut)
        let impulsiveCount = trades.filter { trade in
            !appState.systems.contains(where: { $0.id == trade.systemId })
        }.count
        
        // Durée moyenne (approximation basée sur closedAt - date)
        let durations = trades.compactMap { trade -> TimeInterval? in
            guard let closed = trade.closedAt else { return nil }
            return closed.timeIntervalSince(trade.date)
        }
        let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)
        let avgMinutes = Int(avgDuration / 60)
        
        return AssistantCardContainer(accentColor: Color.orange.opacity(0.6)) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    VStack(alignment: .leading) {
                        Text(t("planConsistency"))
                            .font(AppTypography.titleSmall)
                            .foregroundColor(AppColors.textPrimary)
                        Text(t("respectStrategy"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(Int(adherence))%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(adherence >= 80 ? .green : adherence >= 50 ? .orange : .red)
                        Text(t("adherence"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Divider().opacity(0.3)
                
                coherenceRow(icon: "star.fill", iconColor: .green, label: "Meilleur système", value: bestSystemName)
                coherenceRow(icon: "exclamationmark.triangle.fill", iconColor: .orange, label: "Système à réviser", value: worstSystemName)
                coherenceRow(icon: "bolt.fill", iconColor: .red, label: "Trades impulsifs", value: "\(impulsiveCount)")
                coherenceRow(icon: "clock.fill", iconColor: .blue, label: "Détention moyenne", value: avgMinutes > 60 ? "\(avgMinutes / 60)h\(avgMinutes % 60)min" : "\(avgMinutes)min")
                
                Divider().opacity(0.3)
                
                // Recommandation IA
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("💡")
                        Text(t("aiRecommendations"))
                            .font(AppTypography.captionMedium)
                            .foregroundColor(.pink)
                            .fontWeight(.bold)
                    }
                    if let bestId = bestSystemId, let bestPnL = systemPnL[bestId] {
                        Text("✅ '\(bestSystemName)' " + (isFR ? "est ton système le plus performant (P&L \(String(format: "%.2f", bestPnL))$)" : "is your best performing system (P&L \(String(format: "%.2f", bestPnL))$)"))
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text("✅ '\(bestSystemName)' " + (isFR ? "est ton système le plus performant" : "is your best performing system"))
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding()
                .background(Color.pink.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
        }
    }
    
    private func coherenceRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)
            Text(label)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.bodySmall)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    // MARK: - Timing Optimal
    
    private var timingCard: some View {
        let trades = appState.trades.filter { $0.isClosed }
        let calendar = Calendar.current
        
        // Grouper par heure
        let byHour = Dictionary(grouping: trades, by: { calendar.component(.hour, from: $0.date) })
        let hourPnL = byHour.mapValues { trades in
            trades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
        }
        let bestHour = hourPnL.max(by: { $0.value < $1.value })?.key
        let worstHour = hourPnL.min(by: { $0.value < $1.value })?.key
        
        // Grouper par jour de la semaine
        let byWeekday = Dictionary(grouping: trades, by: { calendar.component(.weekday, from: $0.date) })
        let weekdayPnL = byWeekday.mapValues { trades in
            trades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
        }
        let bestDay = weekdayPnL.max(by: { $0.value < $1.value })?.key
        let dayName: String = {
            guard let d = bestDay else { return "—" }
            let names = ["", "Dimanche", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi"]
            return d < names.count ? names[d] : "—"
        }()
        
        return AssistantCardContainer(accentColor: Color.cyan.opacity(0.6)) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading) {
                        Text(t("optimalTiming"))
                            .font(AppTypography.titleSmall)
                            .foregroundColor(AppColors.textPrimary)
                        Text(t("bestMomentsToTrade"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Divider().opacity(0.3)
                
                // Meilleure heure
                HStack {
                    Image(systemName: "star.fill").foregroundColor(.green).frame(width: 20)
                    Text("\(t("bestHour")) : \(bestHour.map { "\($0)h-\($0+1)h" } ?? "—")")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                // Pire heure
                HStack {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red).frame(width: 20)
                    Text("\(t("avoidHour")) : \(worstHour.map { "\($0)h-\($0+1)h" } ?? "—")")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                // Meilleur jour
                HStack {
                    Image(systemName: "calendar.circle.fill").foregroundColor(.blue).frame(width: 20)
                    Text(t("bestDay") + " : \(dayName)")
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Divider().opacity(0.3)
                
                // Recommandation
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("💡")
                        Text(t("recommendations"))
                            .font(AppTypography.captionMedium)
                            .foregroundColor(.pink)
                            .fontWeight(.bold)
                    }
                    if let hour = bestHour, let hourTrades = byHour[hour] {
                        let winCount = hourTrades.filter { (appState.netPnL(for: $0) ?? 0) > 0 }.count
                        let winRate = hourTrades.isEmpty ? 0.0 : Double(winCount) / Double(hourTrades.count) * 100
                        Text(t("preferablyTrade") + " \(hour)h-\(hour+1)h (WR \(Int(winRate))%)")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text(t("preferablyTrade") + " " + (bestHour.map { "\($0)h-\($0+1)h" } ?? "—"))
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding()
                .background(Color.pink.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
        }
    }
    
    private var conseilsContent: some View {
        let advice = AdviceGenerator.generateAdvice(
            disciplineScore: appState.riskScore,
            emotionalLoad: appState.emotionScore,
            trades: appState.trades,
            appState: appState,
            language: language
        )
        
        return VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // 1. Statut & Edge Score
            statusCard(advice: advice)
            
            // 2. Action Prioritaire
            actionCard(advice: advice)
            
            // 3. Fenêtre Optimale
            windowCard(advice: advice)
            
            // 4. Focus du Jour
            focusCard(advice: advice)
            
            // 5. Facteurs Influents
            factorsCard(advice: advice)
        }
        .onAppear {
            currentAdvice = advice
        }
    }
    
    // MARK: - Conseils Cards
    
    private func statusCard(advice: TradingAdviceSummary) -> some View {
        Button(action: {
            HapticFeedback.selection()
            showEdgeScoreDetails = true
        }) {
            AssistantCardContainer(accentColor: Color(hex: advice.status.color)) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.title2)
                            .foregroundColor(Color(hex: advice.status.color))
                        VStack(alignment: .leading) {
                            Text(t("currentStatus"))
                                .font(AppTypography.titleSmall)
                                .foregroundColor(AppColors.textPrimary)
                            Text(t("evaluatingConditions"))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        
                        // Indicateur "tap pour détails"
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundColor(Color(hex: advice.status.color).opacity(0.6))
                    }
                    
                    Divider().opacity(0.3)
                    
                    // Edge Score
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("edgeScore"))
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                            Text("\(advice.edgeScore)/100")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: advice.status.color))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 8) {
                            Text(advice.status.emoji)
                                .font(.system(size: 40))
                            Text(advice.status.label)
                                .font(AppTypography.captionMedium)
                                .foregroundColor(Color(hex: advice.status.color))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: advice.status.color).opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.background).frame(height: 8)
                            Capsule().fill(Color(hex: advice.status.color))
                                .frame(width: geo.size.width * (Double(advice.edgeScore) / 100.0), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEdgeScoreDetails) {
            edgeScoreDetailsSheet(advice: currentAdvice)
        }
    }
    
    private func actionCard(advice: TradingAdviceSummary) -> some View {
        AssistantCardContainer(accentColor: Color(hex: advice.status.color).opacity(0.7)) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text(t("priorityAction"))
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Text(advice.primaryAction)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: advice.status.color).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
        }
    }
    
    private func windowCard(advice: TradingAdviceSummary) -> some View {
        AssistantCardContainer(accentColor: Color.cyan.opacity(0.6)) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading) {
                        Text(t("optimalWindow"))
                            .font(AppTypography.titleSmall)
                            .foregroundColor(AppColors.textPrimary)
                        Text(t("timingEdge"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                if let window = advice.optimalWindow {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.green)
                        Text(window)
                            .font(AppTypography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
            }
        }
    }
    
    private func focusCard(advice: TradingAdviceSummary) -> some View {
        AssistantCardContainer(accentColor: Color.purple.opacity(0.6)) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundColor(.purple)
                    VStack(alignment: .leading) {
                        Text(t("dailyFocus"))
                            .font(AppTypography.titleSmall)
                            .foregroundColor(AppColors.textPrimary)
                        Text(t("prioritySetup"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                if let focus = advice.focus {
                    HStack {
                        Image(systemName: "scope")
                            .foregroundColor(.purple)
                        Text(focus)
                            .font(AppTypography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
            }
        }
    }
    
    private func factorsCard(advice: TradingAdviceSummary) -> some View {
        AssistantCardContainer(accentColor: Color.blue.opacity(0.6)) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text(t("influencingFactorsPlural"))
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                // Facteurs positifs
                if !advice.positiveFactors.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(isFR ? "✅ Positifs" : "✅ Positives")
                            .font(AppTypography.captionMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        
                        ForEach(advice.positiveFactors, id: \.self) { factor in
                            HStack(alignment: .top, spacing: AppSpacing.xs) {
                                Text("•")
                                    .foregroundColor(.green)
                                Text(factor)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
                
                // Facteurs négatifs
                if !advice.negativeFactors.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(isFR ? "⚠️ Négatifs" : "⚠️ Negatives")
                            .font(AppTypography.captionMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                        
                        ForEach(advice.negativeFactors, id: \.self) { factor in
                            HStack(alignment: .top, spacing: AppSpacing.xs) {
                                Text("•")
                                    .foregroundColor(.red)
                                Text(factor)
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
            }
        }
    }
    
    private func streakTiltCard(streak: StreakAnalysis) -> some View {
        AssistantCardContainer(accentColor: Color.red.opacity(0.6)) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: streak.tiltDetected ? "exclamationmark.triangle.fill" : "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundColor(streak.tiltDetected ? .red : .orange)
                    VStack(alignment: .leading) {
                        Text(t("streakAndTiltAnalysis"))
                            .font(AppTypography.titleSmall)
                            .foregroundColor(AppColors.textPrimary)
                        Text(t("behaviorAfterWinsLosses"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    
                    if streak.tiltDetected {
                        Text("🚨 TILT")
                            .font(AppTypography.captionMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                }
                
                Divider().opacity(0.3)
                
                // Streaks actuels
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading) {
                        Text(t("currentStreak"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                        if streak.currentWinStreak > 0 {
                            Text("🔥 \(streak.currentWinStreak) gains")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.green)
                        } else if streak.currentLossStreak > 0 {
                            Text("❄️ \(streak.currentLossStreak) pertes")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.red)
                        } else {
                            Text("—")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    
                    VStack(alignment: .trailing) {
                        Text(t("records"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                        Text("↗️ \(streak.maxWinStreak) / ↘️ \(streak.maxLossStreak)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppColors.background)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
                
                Divider().opacity(0.3)
                
                // Comportement après wins/losses
                Text(t("behaviorAfterTrades"))
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                VStack(spacing: AppSpacing.sm) {
                    streakBehaviorRow(
                        icon: "arrow.up.circle.fill",
                        iconColor: .green,
                        label: "Après 1 gain",
                        winRate: streak.winRateAfterWin,
                        delay: streak.avgDelayAfterWin
                    )
                    
                    streakBehaviorRow(
                        icon: "arrow.down.circle.fill",
                        iconColor: .orange,
                        label: "Après 1 perte",
                        winRate: streak.winRateAfterLoss,
                        delay: streak.avgDelayAfterLoss
                    )
                    
                    streakBehaviorRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .red,
                        label: "Après 2 pertes",
                        winRate: streak.winRateAfter2Losses,
                        delay: nil
                    )
                }
                
                // Revenge trades
                if streak.revengeTradesDetected > 0 {
                    Divider().opacity(0.3)
                    
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t("revengeTradesDetected"))
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            Text("\(streak.revengeTradesDetected) trades dans les 15 min après une perte")
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
                
                // Alerte tilt
                if streak.tiltDetected {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("🚨")
                            Text(t("tiltDetected"))
                                .font(AppTypography.captionMedium)
                                .foregroundColor(.red)
                                .fontWeight(.bold)
                        }
                        Text(languageManager.currentLanguage == .english ? "After 2 consecutive losses, your WR drops to \(Int(streak.winRateAfter2Losses * 100))%. You are in tilt mode. STOP immediately." : "Après 2 pertes consécutives, ton WR chute à \(Int(streak.winRateAfter2Losses * 100))%. Tu es en mode tilt. STOP immédiat recommandé.")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
            }
        }
    }
    
    private func streakBehaviorRow(icon: String, iconColor: Color, label: String, winRate: Double, delay: TimeInterval?) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                
                HStack(spacing: AppSpacing.sm) {
                    Text("WR \(Int(winRate * 100))%")
                        .font(AppTypography.captionMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(winRate >= 0.5 ? .green : .red)
                    
                    if let delay = delay {
                        let minutes = Int(delay / 60)
                        let hours = minutes / 60
                        let mins = minutes % 60
                        Text("⏱ \(hours > 0 ? "\(hours)h\(mins)min" : "\(mins)min")")
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
    
    // MARK: - Edge Score Details Sheet
    
    private func edgeScoreDetailsSheet(advice: TradingAdviceSummary?) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    if let advice = advice {
                        // Header avec le score
                        edgeScoreHeader(advice: advice)
                        
                        Divider()
                            .padding(.vertical, AppSpacing.sm)
                        
                        // Comment est calculé le score
                        calculationExplanation(advice: advice)
                        
                        Divider()
                            .padding(.vertical, AppSpacing.sm)
                        
                        // Interprétation des paliers
                        statusThresholdsExplanation()
                        
                        Divider()
                            .padding(.vertical, AppSpacing.sm)
                        
                        // Facteurs détaillés
                        detailedFactorsExplanation(advice: advice)
                    } else {
                        // Fallback : générer l'advice maintenant
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                            Text(t("loadingData"))
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            // Générer l'advice si pas disponible
                            let newAdvice = AdviceGenerator.generateAdvice(
                                disciplineScore: appState.riskScore,
                                emotionalLoad: appState.emotionScore,
                                trades: appState.trades,
                                appState: appState,
                                language: language
                            )
                            currentAdvice = newAdvice
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edge Score Détaillé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        showEdgeScoreDetails = false
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    private func edgeScoreHeader(advice: TradingAdviceSummary) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Score principal
            VStack(spacing: AppSpacing.sm) {
                Text(advice.status.emoji)
                    .font(.system(size: 60))
                
                Text("\(advice.edgeScore)/100")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: advice.status.color))
                
                Text(advice.status.label)
                    .font(AppTypography.titleMedium)
                    .foregroundColor(Color(hex: advice.status.color))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: advice.status.color).opacity(0.15))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(Color(hex: advice.status.color).opacity(0.08))
            )
            
            // Description du statut
            Text(statusDescription(for: advice.status))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private func calculationExplanation(advice: TradingAdviceSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.cyan)
                Text(t("edgeScoreExplanation"))
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(t("baselinePoints"))
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .padding(.bottom, AppSpacing.sm)
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                calculationRow(
                    label: "Discipline",
                    value: appState.riskScore,
                    multiplier: 0.3,
                    isPositive: true,
                    emoji: "✅"
                )
                
                calculationRow(
                    label: isFR ? "Charge émotionnelle" : "Emotional load",
                    value: appState.emotionScore,
                    multiplier: 0.3,
                    isPositive: false,
                    emoji: "🧠"
                )
                
                if let streak = advice.streakAnalysis {
                    if streak.currentWinStreak > 0 {
                        calculationRow(
                            label: isFR ? "Série de gains" : "Win streak",
                            value: streak.currentWinStreak,
                            multiplier: 2.0,
                            isPositive: true,
                            emoji: "🔥"
                        )
                    }
                    
                    if streak.currentLossStreak > 0 {
                        calculationRow(
                            label: isFR ? "Série de pertes" : "Loss streak",
                            value: streak.currentLossStreak,
                            multiplier: 5.0,
                            isPositive: false,
                            emoji: "❄️"
                        )
                    }
                }
            }
            
            // Formule finale
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(t("result"))
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(t("edgeScoreFormula") + " \(calculateFormulaDetails(advice: advice))")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: advice.status.color))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
            .padding(.top, AppSpacing.sm)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
    }
    
    private func calculationRow(label: String, value: Int, multiplier: Double, isPositive: Bool, emoji: String) -> some View {
        HStack {
            Text(emoji)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                
                Text("\(value) × \(String(format: "%.1f", multiplier)) = \(isPositive ? "+" : "-")\(String(format: "%.1f", Double(value) * multiplier)) pts")
                    .font(AppTypography.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(isPositive ? .green : .red)
            }
            
            Spacer()
            
            Text("\(isPositive ? "+" : "-")\(Int(Double(value) * multiplier))")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(isPositive ? .green : .red)
        }
        .padding()
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
    
    private func statusThresholdsExplanation() -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                Text(t("decisionLevels"))
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            VStack(spacing: AppSpacing.sm) {
                statusThresholdRow(
                    emoji: "🟢",
                    label: "Optimal (> 75)",
                    description: "Conditions idéales pour trader. Exécute ton plan avec confiance.",
                    color: "#4CD964"
                )
                
                statusThresholdRow(
                    emoji: "🟡",
                    label: "Neutre (50-75)",
                    description: "Conditions acceptables. Sois sélectif, trade uniquement tes meilleurs setups.",
                    color: "#FF9F0A"
                )
                
                statusThresholdRow(
                    emoji: "🔴",
                    label: "À éviter (< 50)",
                    description: "Conditions défavorables. Pause recommandée ou maximum 1 trade avec taille réduite.",
                    color: "#FF3B30"
                )
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
    }
    
    private func statusThresholdRow(emoji: String, label: String, description: String, color: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Text(emoji)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: color))
                
                Text(description)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding()
        .background(Color(hex: color).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
    
    private func detailedFactorsExplanation(advice: TradingAdviceSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(.blue)
                Text(t("factorsInfluencingEdge"))
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // Facteurs positifs
            if !advice.positiveFactors.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(t("currentEdgeAdvantages"))
                            .font(AppTypography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    
                    ForEach(advice.positiveFactors, id: \.self) { factor in
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Text("•")
                                .foregroundColor(.green)
                            Text(factor)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
            
            // Facteurs négatifs
            if !advice.negativeFactors.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(t("riskToWatch"))
                            .font(AppTypography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    
                    ForEach(advice.negativeFactors, id: \.self) { factor in
                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            Text("•")
                                .foregroundColor(.red)
                            Text(factor)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding()
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
            
            // Conseil d'action
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("💡")
                    Text(t("recommendedAction"))
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                Text(advice.primaryAction)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding()
            .background(Color.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
    }
    
    // MARK: - Helper Functions
    
    private func statusDescription(for status: AdviceStatus) -> String {
        switch status {
        case .optimal:
            return isFR
                ? "Tes conditions sont idéales pour trader. Discipline élevée, état mental stable et contexte favorable. C'est le moment d'exécuter ton plan avec confiance."
                : "Your conditions are ideal for trading. High discipline, stable mindset and favorable context. Now is the time to execute your plan with confidence."
        case .neutral:
            return isFR
                ? "Conditions acceptables mais pas parfaites. Sois plus sélectif que d'habitude et concentre-toi uniquement sur tes setups A+ avec un avantage clair."
                : "Acceptable but not perfect conditions. Be more selective than usual and focus only on your A+ setups with a clear edge."
        case .avoid:
            return isFR
                ? "Conditions actuellement défavorables. Il est recommandé de prendre une pause ou, si tu trades, de limiter ta prise de risque au maximum (1 trade, taille réduite)."
                : "Currently unfavorable conditions. It is recommended to take a break or, if you trade, to limit your risk to a maximum (1 trade, reduced size)."
        }
    }
    
    private func calculateFormulaDetails(advice: TradingAdviceSummary) -> String {
        var parts: [String] = []
        
        let disciplineContribution = Double(appState.riskScore) * 0.3
        if disciplineContribution != 0 {
            parts.append(String(format: "%.1f", disciplineContribution))
        }
        
        let emotionContribution = Double(appState.emotionScore) * 0.3
        if emotionContribution != 0 {
            parts.append(String(format: "- %.1f", emotionContribution))
        }
        
        if let streak = advice.streakAnalysis {
            if streak.currentWinStreak > 0 {
                let winContribution = Double(streak.currentWinStreak) * 2.0
                parts.append(String(format: "+ %.1f", winContribution))
            }
            
            if streak.currentLossStreak > 0 {
                let lossContribution = Double(streak.currentLossStreak) * 5.0
                parts.append(String(format: "- %.1f", lossContribution))
            }
        }
        
        return parts.isEmpty ? "0" : parts.joined(separator: " ")
    }
    
    private var analyseContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Barre de recherche + bouton PDF + bouton Rafraîchir
            HStack(spacing: AppSpacing.sm) {
                SymbolSearchBar(selectedSymbol: $selectedSymbol)
                
                // Bouton rafraîchir analyse
                Button(action: {
                    Task { await loadGPTAnalysis(force: true) }
                }) {
                    Image(systemName: isLoadingGPTAnalysis ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.cyan)
                        .rotationEffect(.degrees(isLoadingGPTAnalysis ? 360 : 0))
                        .animation(isLoadingGPTAnalysis ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoadingGPTAnalysis)
                        .frame(width: 36, height: 36)
                        .background(Color.cyan.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
                }
                .disabled(isLoadingGPTAnalysis)
                
                // Bouton PDF
                Button(action: { generateAndSharePDF() }) {
                    HStack(spacing: 4) {
                        if isGeneratingPDF {
                            ProgressView().scaleEffect(0.6).tint(.white)
                        } else {
                            Image(systemName: "arrow.up.doc.fill").font(.system(size: 12))
                        }
                        Text("PDF").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [Color(hex: "#0066cc"), Color(hex: "#5500cc")], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
                .disabled(isGeneratingPDF)
            }
            .padding(.bottom, AppSpacing.xs)
            .sheet(isPresented: $showPDFShareSheet, onDismiss: { pdfShareData = nil }) {
                if let data = pdfShareData {
                    PDFActivityView(data: data, filename: "TradeMindset_Analyse_\(selectedSymbol.displayName).pdf")
                }
            }
            
            // Carte analyse GPT
            gptAnalysisCard
            
            // Liquidation Heatmap (crypto uniquement)
            if selectedSymbol.isCrypto {
                LiquidityHeatmapView(symbol: selectedSymbol.symbol)
                    .id("analyse_heatmap_\(selectedSymbol.symbol)")
            }
        }
    }
    
    // MARK: - GPT Analysis Card

    private var gptAnalysisCard: some View {
        Group {
            if !gptAnalysis.isEmpty {
                // Résultat disponible → l'afficher directement (même si refresh en cours)
                GPTAnalysisRenderer(text: gptAnalysis, symbol: selectedSymbol.displayName, currentPrice: currentPrice)
            } else if isLoadingGPTAnalysis {
                // Loading skeleton
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.07)).frame(width: 120, height: 16)
                        Spacer()
                        Circle().fill(Color.white.opacity(0.07)).frame(width: 72, height: 72)
                    }
                    .padding(16)
                    .background(Color(hex: "#131722"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 10) {
                        gptLoadingStep(icon: "waveform.path.ecg", text: isFR ? "Analyse des indicateurs techniques..." : "Analyzing technical indicators...", delay: 0)
                        gptLoadingStep(icon: "chart.xyaxis.line", text: isFR ? "Calcul du Score IA..." : "Computing AI Score...", delay: 0.25)
                        gptLoadingStep(icon: "target", text: isFR ? "Génération du plan de trade..." : "Generating trade plan...", delay: 0.5)
                        gptLoadingStep(icon: "checkmark.shield", text: isFR ? "Évaluation du risque..." : "Evaluating risk...", delay: 0.75)
                    }
                    .padding(16)
                    .background(Color(hex: "#131722"))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 36))
                        .foregroundColor(Color(hex: "#7B2FFF").opacity(0.4))
                    Text(t("selectAssetToAnalyze"))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
                .background(Color(hex: "#131722"))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    @State private var gptLoadingPulse = false

    private func gptLoadingStep(icon: String, text: String, delay: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 11)).foregroundColor(Color(hex: "#7B2FFF").opacity(0.6)).frame(width: 16)
            Text(text).font(.system(size: 11)).foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .opacity(gptLoadingPulse ? 0.9 : 0.35)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(delay), value: gptLoadingPulse)
        .onAppear { gptLoadingPulse = true }
        .onDisappear { gptLoadingPulse = false }
    }

    // MARK: - Load GPT Analysis

    private func loadGPTAnalysis(force: Bool = false) async {
        let sym = selectedSymbol.displayName
        guard force || gptAnalysisSymbol != sym || gptAnalysis.isEmpty else { return }
        guard !isLoadingGPTAnalysis else { return }

        await MainActor.run {
            isLoadingGPTAnalysis = true
            gptAnalysisSymbol = sym
        }

        // Fetch prix actuel avant d'envoyer à GPT
        // S'assurer que activeMarketSymbol est synchronisé
        await MainActor.run { MarketDataService.shared.activeMarketSymbol = selectedSymbol }

        if selectedSymbol.isCrypto {
            // Crypto : Binance ticker direct
            let binSymbol = selectedSymbol.binanceSymbol ?? selectedSymbol.symbol
            if let priceURL = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=\(binSymbol)"),
               let (priceData, _) = try? await URLSession.shared.data(from: priceURL),
               let priceDict = try? JSONSerialization.jsonObject(with: priceData) as? [String: Any],
               let priceStr = priceDict["price"] as? String,
               let price = Double(priceStr) {
                await MainActor.run { currentPrice = price }
            }
        } else {
            // Action / Forex : utiliser selectedSymbol.symbol (ex: "AAPL", pas "Apple Inc.")
            // activeMarketSymbol est synchronisé juste au-dessus → fetchKlines routera vers Finnhub/TwelveData
            if let candles = try? await MarketDataService.shared.fetchKlines(
                symbol: selectedSymbol.symbol, interval: "1day", limit: 1
            ), let last = candles.last {
                await MainActor.run { currentPrice = last.close }
            }
        }

        let symbolType: String = selectedSymbol.instrumentType.marketDisplayName

        do {
            // Extraire les zones de liquidité majeures (crypto uniquement)
            var liquidityZones: [(price: Double, volume: Double, side: String)]? = nil
            if selectedSymbol.isCrypto && currentPrice > 0 {
                liquidityZones = await extractLiquidityZones(symbol: selectedSymbol.symbol, currentPrice: currentPrice)
            }
            
            let result = try await assistantAIServiceShared.generateGPTAnalysis(
                symbol: sym,
                symbolType: symbolType,
                currentPrice: currentPrice,
                mtfSnapshot: mtfSnapshot,
                wtSnapshot: wtSnapshot,
                vmcOscSnapshot: vmcOscSnapshot,
                liquidityZones: liquidityZones,
                economicRiskAnalysis: economicStore.riskAnalysis,
                fundingRate: appState.fundingRate,
                language: LanguageManager.shared.currentLanguage
            )
            await MainActor.run {
                gptAnalysis = result
                isLoadingGPTAnalysis = false
            }
        } catch {
            let lang = LanguageManager.shared.currentLanguage
            let errorMsg = lang == .english
                ? "❌ Analysis error: \(error.localizedDescription)"
                : "❌ Erreur lors de l'analyse : \(error.localizedDescription)"
            await MainActor.run {
                gptAnalysis = errorMsg
                isLoadingGPTAnalysis = false
            }
        }
    }

    // MARK: - Extract Liquidity Zones for GPT
    
    /// Extrait les zones de liquidité majeures depuis Binance Futures depth
    private func extractLiquidityZones(symbol: String, currentPrice: Double) async -> [(price: Double, volume: Double, side: String)] {
        let urlStr = "https://fapi.binance.com/fapi/v1/depth?symbol=\(symbol)&limit=1000"
        guard let url = URL(string: urlStr) else { return [] }
        
        do {
            let (data, _) = try await NetworkSession.market.data(from: url)
            let resp = try JSONDecoder().decode(BinanceDepthResponse.self, from: data)
            
            // Agréger par tranches de prix (buckets de ~0.5%)
            let bucketSize = currentPrice * 0.005
            var bidBuckets: [Double: Double] = [:]
            var askBuckets: [Double: Double] = [:]
            
            for arr in resp.bids {
                guard arr.count >= 2, let p = Double(arr[0]), let q = Double(arr[1]) else { continue }
                let bucket = (p / bucketSize).rounded() * bucketSize
                bidBuckets[bucket, default: 0] += q * p
            }
            for arr in resp.asks {
                guard arr.count >= 2, let p = Double(arr[0]), let q = Double(arr[1]) else { continue }
                let bucket = (p / bucketSize).rounded() * bucketSize
                askBuckets[bucket, default: 0] += q * p
            }
            
            // Trier par volume et prendre les plus gros
            var zones: [(price: Double, volume: Double, side: String)] = []
            
            let topBids = bidBuckets.sorted { $0.value > $1.value }.prefix(4)
            for (price, vol) in topBids {
                zones.append((price: price, volume: vol, side: "🟢 Support (bids)"))
            }
            
            let topAsks = askBuckets.sorted { $0.value > $1.value }.prefix(4)
            for (price, vol) in topAsks {
                zones.append((price: price, volume: vol, side: "🔴 Résistance (asks)"))
            }
            
            // Trier par distance au prix actuel
            zones.sort { abs($0.price - currentPrice) < abs($1.price - currentPrice) }
            
            return zones
        } catch {
            return []
        }
    }
    
    // MARK: - PDF Generation

    private func generateAndSharePDF() {
        guard !isGeneratingPDF else { return }
        HapticFeedback.medium()
        isGeneratingPDF = true

        let enrichedAnalysis = assistantAIServiceShared.generateEnrichedTechnicalAnalysis(
            indicators: appState.indicatorSnapshots,
            mtfSnapshot: mtfSnapshot,
            wtSnapshot: wtSnapshot,
            economicRiskAnalysis: economicStore.riskAnalysis,
            language: LanguageManager.shared.currentLanguage
        )
        let sym = selectedSymbol.displayName
        let confluence = appState.marketConfluence
        let fundingRate = appState.fundingRate
        let recommendations = appState.aiRecommendations
        let mtf = mtfSnapshot
        let wt = wtSnapshot
        let vmc = vmcOscSnapshot
        let isCrypto = selectedSymbol.isCrypto
        let binSymbol = selectedSymbol.binanceSymbol ?? selectedSymbol.symbol
        let capturedGPT = gptAnalysis  // capture du texte GPT pour le PDF

        Task.detached(priority: .userInitiated) {
            // Charger la heatmap en async si crypto
            var heatmap: LiquidityHeatmapData? = nil
            if isCrypto {
                let heatmapVM = await LiquidityHeatmapViewModel(symbol: binSymbol)
                await heatmapVM.load()
                let loaded = await heatmapVM.heatmapData
                if !loaded.snapshots.isEmpty { heatmap = loaded }
            }

            let data = AnalysePDFService.generate(
                symbol: sym,
                enrichedAnalysis: enrichedAnalysis,
                gptAnalysis: capturedGPT,
                confluence: confluence,
                fundingRate: fundingRate,
                recommendations: recommendations,
                mtfSnapshot: mtf,
                wtSnapshot: wt,
                vmcOscSnapshot: vmc,
                heatmapData: heatmap,
                isCrypto: isCrypto
            )
            await MainActor.run {
                pdfShareData = data
                showPDFShareSheet = true
                isGeneratingPDF = false
            }
        }
    }
    
    // MARK: - AI Loading View
    
    @State private var loadingPulse = false
    
    private var aiLoadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            // Skeleton card 1
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.sm) {
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.cyan.opacity(0.4))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        skeletonLine(width: 140)
                        skeletonLine(width: 80)
                    }
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.cyan)
                }
                
                Divider().background(AppColors.border.opacity(0.2))
                
                // Fake loading steps
                VStack(alignment: .leading, spacing: 8) {
                    aiLoadingStep(icon: "waveform.path.ecg", text: isFR ? "Chargement des indicateurs techniques..." : "Loading technical indicators...", delay: 0)
                    aiLoadingStep(icon: "chart.bar.fill", text: isFR ? "Analyse multi-timeframe en cours..." : "Running multi-timeframe analysis...", delay: 0.3)
                    aiLoadingStep(icon: "globe.americas.fill", text: isFR ? "Intégration du calendrier économique..." : "Integrating economic calendar...", delay: 0.6)
                    aiLoadingStep(icon: "cpu", text: isFR ? "Génération de l'analyse IA..." : "Generating AI analysis...", delay: 0.9)
                }
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
            )
            
            // Skeleton card 2
            VStack(spacing: AppSpacing.sm) {
                skeletonLine(width: 200)
                skeletonLine()
                skeletonLine()
                skeletonLine(width: 160)
            }
            .padding(AppSpacing.md)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        }
        .onAppear { loadingPulse = true }
    }
    
    private func skeletonLine(width: CGFloat? = nil) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(AppColors.textTertiary.opacity(loadingPulse ? 0.15 : 0.08))
            .frame(maxWidth: width ?? .infinity, minHeight: 12, maxHeight: 12)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: loadingPulse)
    }
    
    private func aiLoadingStep(icon: String, text: String, delay: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.cyan.opacity(0.5))
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
        .opacity(loadingPulse ? 0.9 : 0.4)
        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true).delay(delay), value: loadingPulse)
    }
    
    // MARK: - Enriched Analysis Card

    /// Calcule une clé de cache légère pour détecter si les données ont changé
    private var enrichedAnalysisCacheKey: String {
        let mtfKey = mtfSnapshot.map { "mtf-\(Int($0.globalCombinedScore*100))-\($0.confluencePercent)" } ?? "nil"
        let wtKey = wtSnapshot.map { "wt-\($0.currentWT1.rounded())" } ?? "nil"
        let snapCount = appState.indicatorSnapshots.count
        return "\(mtfKey)-\(wtKey)-\(snapCount)"
    }

    private func enrichedAnalysisCard(performance: AssistantAISection) -> some View {
        // Recalcul uniquement si les données sous-jacentes ont changé
        let currentKey = enrichedAnalysisCacheKey
        if cachedEnrichedAnalysisKey != currentKey {
            DispatchQueue.main.async {
                self.cachedEnrichedAnalysisKey = currentKey
                self.cachedEnrichedAnalysis = self.assistantAIServiceShared.generateEnrichedTechnicalAnalysis(
                    indicators: self.appState.indicatorSnapshots,
                    mtfSnapshot: self.mtfSnapshot,
                    wtSnapshot: self.wtSnapshot,
                    economicRiskAnalysis: self.economicStore.riskAnalysis
                )
            }
        }
        let enrichedAnalysis = cachedEnrichedAnalysis
        
        return AssistantCardContainer(accentColor: Color(hex: performance.accentColorHex)) {
            let accentColor = Color(hex: performance.accentColorHex)
            
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(AppSpacing.sm)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("analyse"))
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                    Text(t("no"))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(accentColor.opacity(0.8))
                }
                Spacer()
                
                // Indicateurs de chargement
                if isLoadingMTF || isLoadingWT || economicStore.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Divider().background(AppColors.border.opacity(0.4))
                .padding(.vertical, AppSpacing.xs)
            
            // Analyse enrichie
            if enrichedAnalysis.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    if isLoadingMTF || isLoadingWT || economicStore.isLoading {
                        HStack {
                            ProgressView().scaleEffect(0.8)
                            Text(t("loadingIndicators"))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    } else {
                        Text(t("loadingEnrichedData"))
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppSpacing.md)
            } else {
                // Afficher l'analyse avec formatage professionnel
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        // Parser et afficher chaque section avec un style professionnel
                        let sections = enrichedAnalysis.components(separatedBy: "\n\n")
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            if !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    let lines = section.components(separatedBy: "\n")
                                    ForEach(Array(lines.enumerated()), id: \.offset) { lineIndex, line in
                                        if lineIndex == 0 && line.contains("────") {
                                            // Ignorer les lignes de séparation
                                        } else if lineIndex == 0 {
                                            // Titre de section
                                            Text(line)
                                                .font(AppTypography.titleSmall)
                                                .fontWeight(.bold)
                                                .foregroundColor(AppColors.textPrimary)
                                                .padding(.top, lineIndex == 0 && index > 0 ? AppSpacing.sm : 0)
                                        } else if line.hasPrefix("•") || line.hasPrefix("✅") || line.hasPrefix("⚠️") || line.hasPrefix("🚨") || line.hasPrefix("🟢") || line.hasPrefix("🔴") || line.hasPrefix("💡") {
                                            // Points importants avec emoji
                                            HStack(alignment: .top, spacing: AppSpacing.xs) {
                                                Text(line.prefix(1))
                                                    .font(AppTypography.bodySmall)
                                                Text(String(line.dropFirst()))
                                                    .font(AppTypography.bodySmall)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                        } else if line.contains(":") {
                                            // Ligne clé-valeur
                                            HStack(alignment: .top, spacing: AppSpacing.xs) {
                                                let parts = line.components(separatedBy: ":")
                                                if parts.count >= 2 {
                                                    Text(parts[0] + ":")
                                                        .font(AppTypography.bodySmall)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(AppColors.textPrimary)
                                                    Text(parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                                        .font(AppTypography.bodySmall)
                                                        .foregroundColor(AppColors.textSecondary)
                                                } else {
                                                    Text(line)
                                                        .font(AppTypography.bodySmall)
                                                        .foregroundColor(AppColors.textSecondary)
                                                }
                                            }
                                        } else {
                                            // Ligne normale
                                            Text(line)
                                                .font(AppTypography.bodySmall)
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.xs)
                }
                .frame(maxHeight: 600)
            }
        }
    }
    
    // MARK: - Load Analysis Data
    
    private func loadAnalysisData() async {
        // S'assurer que le routage API est à jour
        MarketDataService.shared.activeMarketSymbol = selectedSymbol
        // Charger en parallèle — les services ont leur propre cache TTL (120s)
        // On ne recharge WT/MTF que s'ils sont nil (déjà gérés par le cache actor)
        await withTaskGroup(of: Void.self) { group in
            // MTF et WT : toujours via cache (les actors retournent le cache si valide)
            group.addTask { await self.loadMTFSnapshot() }
            group.addTask { await self.loadWTSnapshot() }
            // VMC oscillateur : uniquement si pas encore chargé
            if vmcOscSnapshot == nil {
                group.addTask { await self.loadVMCOscillatorSnapshot() }
            }
            // Calendrier : cache 1h, ne recharge pas si déjà en mémoire
            group.addTask {
                let _ = try? await self.economicStore.loadEvents(for: self.economicPeriod, forceRefresh: false)
            }
        }
    }
    
    private var indicateursContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Barre de recherche d'actifs
            SymbolSearchBar(selectedSymbol: $selectedSymbol)
                .padding(.bottom, AppSpacing.sm)
            
            // Wave Trend Oscillator
            wtDashboardSection
            
            // VMC Oscillator (sous le Wave Trend)
            vmcOscillatorSection
            
            // Liquidity Heatmap (BTC uniquement)
            liquidityHeatmapSection
            
            // MTF Dashboard (RSI + VMC combinés)
            mtfdashboardSection
            
            if let performance = section(of: .performance) {
                // Analyse technique détaillée basée sur le tableau
                if !appState.technicalSummary.isEmpty && !appState.indicatorSnapshots.isEmpty {
                    AssistantCardContainer(accentColor: Color(hex: performance.accentColorHex)) {
                        let accentColor = Color(hex: performance.accentColorHex)
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "brain.head.profile")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(AppSpacing.sm)
                                .background(
                                    LinearGradient(
                                        colors: [accentColor, accentColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t("analyse"))
                                    .font(AppTypography.titleSmall)
                                    .foregroundColor(AppColors.textPrimary)
                                Text(t("synthse"))
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(accentColor.opacity(0.8))
                            }
                            Spacer()
                        }
                        
                        // Résumé principal
                        Text(appState.technicalSummary)
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                            .padding(.top, AppSpacing.xs)
                        
                        // Analyse détaillée basée sur le tableau
                        Divider().background(AppColors.border.opacity(0.4))
                            .padding(.vertical, AppSpacing.xs)
                        
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(t("ai"))
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            // Analyser chaque timeframe du tableau
                            ForEach(appState.indicatorSnapshots) { snapshot in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(snapshot.timeframe)
                                            .font(AppTypography.captionSmall)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppColors.textPrimary)
                                        Spacer()
                                        Text(snapshot.bias.rawValue.capitalized)
                                            .font(AppTypography.captionSmall)
                                            .foregroundColor(snapshot.bias == .bullish ? AppColors.success : snapshot.bias == .bearish ? AppColors.error : AppColors.textSecondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(snapshot.bias == .bullish ? AppColors.success.opacity(0.2) : snapshot.bias == .bearish ? AppColors.error.opacity(0.2) : AppColors.textSecondary.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    
                                    HStack(spacing: AppSpacing.sm) {
                                        if snapshot.rsi > 0 {
                                            Text(t("rsi"))
                                                .font(AppTypography.captionSmall)
                                                .foregroundColor(snapshot.rsi > 70 ? AppColors.error : snapshot.rsi < 30 ? AppColors.success : AppColors.textSecondary)
                                        }
                                        if snapshot.macd != 0 {
                                            Text("MACD: \(String(format: "%.2f", snapshot.macd))")
                                                .font(AppTypography.captionSmall)
                                                .foregroundColor(snapshot.macd > 0 ? AppColors.success : AppColors.error)
                                        }
                                    }
                                    
                                    // Interprétation du timeframe
                                    let interpretation = interpretTimeframe(snapshot)
                                    if !interpretation.isEmpty {
                                        Text(interpretation)
                                            .font(AppTypography.captionSmall)
                                            .foregroundColor(AppColors.textTertiary)
                                            .italic()
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.top, AppSpacing.xs)
                    }
                }
                
                // Tableau des indicateurs
                AssistantPerformanceCard(
                    section: performance,
                    accentColorHex: performance.accentColorHex,
                    indicatorSnapshots: appState.indicatorSnapshots,
                    technicalSummary: appState.technicalSummary,
                    riskScore: appState.riskScore
                )
            }
        }
    }
    
    // MARK: - MTF Dashboard Section (RSI + VMC combinés)
    
    @ViewBuilder
    private var mtfdashboardSection: some View {
        if let snapshot = mtfSnapshot {
            MTFDashboardView(snapshot: snapshot, symbol: selectedSymbol.symbol)
                .padding(.bottom, AppSpacing.md)
        } else if isLoadingMTF {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text(t("loadingMTF"))
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
    }
    
    // MARK: - Liquidity Heatmap Section
    
    @ViewBuilder
    private var liquidityHeatmapSection: some View {
        if selectedSymbol.isCrypto {
            LiquidityHeatmapView(symbol: selectedSymbol.symbol)
                .id("heatmap_\(selectedSymbol.symbol)")  // force recréation au changement de symbole
                .padding(.bottom, AppSpacing.md)
        }
    }
    
    // MARK: - VMC Oscillator Section
    
    @ViewBuilder
    private var vmcOscillatorSection: some View {
        if let snapshot = vmcOscSnapshot {
            VMCOscillatorView(
                snapshot: snapshot,
                symbol: selectedSymbol.symbol,
                currentTimeframe: vmcOscTimeframe,
                onTimeframeChange: { newTimeframe in
                    vmcOscTimeframe = newTimeframe
                    Task { await loadVMCOscillatorSnapshot(timeframe: newTimeframe) }
                }
            )
            .padding(.bottom, AppSpacing.md)
        } else if isLoadingVMCOsc {
            HStack {
                ProgressView().scaleEffect(0.8)
                Text(t("loadingVMC"))
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        }
    }
    
    // MARK: - Wave Trend Dashboard Section
    
    @ViewBuilder
    private var wtDashboardSection: some View {
        if let snapshot = wtSnapshot {
            WTDashboardView(
                snapshot: snapshot,
                symbol: selectedSymbol.symbol,
                currentTimeframe: wtTimeframe,
                onTimeframeChange: { newTimeframe in
                    wtTimeframe = newTimeframe
                    Task {
                        await loadWTSnapshot(timeframe: newTimeframe)
                    }
                }
            )
            .padding(.bottom, AppSpacing.md)
        } else if isLoadingWT {
            HStack {
                ProgressView().scaleEffect(0.8)
                Text(t("loadingWaveTrend"))
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        }
    }
    
    /// Lance le chargement des données en parallèle pour éviter tout freeze UI
    private func loadDataForTab(_ tab: AssistantTab) {
        switch tab {
        case .indicateurs:
            // TaskGroup pour vrai parallélisme — skip si données déjà en cache
            Task {
                await withTaskGroup(of: Void.self) { group in
                    if mtfSnapshot == nil {
                        group.addTask { await self.loadMTFSnapshot() }
                    }
                    if wtSnapshot == nil {
                        group.addTask { await self.loadWTSnapshot() }
                    }
                    if vmcOscSnapshot == nil {
                        group.addTask { await self.loadVMCOscillatorSnapshot() }
                    }
                }
            }
        case .analyse:
            break
        case .conseils:
            // Charger les snapshots pour AnalysisContentView (scénarios)
            Task {
                await withTaskGroup(of: Void.self) { group in
                    if mtfSnapshot == nil {
                        group.addTask { await self.loadMTFSnapshot() }
                    }
                    if wtSnapshot == nil {
                        group.addTask { await self.loadWTSnapshot() }
                    }
                    if vmcOscSnapshot == nil {
                        group.addTask { await self.loadVMCOscillatorSnapshot() }
                    }
                }
            }
            Task { await loadAnalysisData() }
        case .calendar:
            Task { let _ = try? await economicStore.loadEvents(for: economicPeriod, forceRefresh: false) }
        default:
            break
        }
    }
    
    private func loadWTSnapshot(timeframe: WTTimeframe? = nil) async {
        let selectedTimeframe = timeframe ?? wtTimeframe
        isLoadingWT = true
        defer { isLoadingWT = false }
        do {
            let snapshot = try await WTService.shared.fetchWTSnapshotCached(
                symbol: selectedSymbol.symbol,
                interval: selectedTimeframe.binanceInterval,
                limit: 200,
                config: WTConfig.default
            )
            await MainActor.run {
                // Détecter les nouveaux signaux pour les notifications (par UT)
                if let currentSignal = snapshot.currentSignal {
                    // Vérifier si on doit notifier pour ce timeframe (avec score de qualité)
                    if wtNotificationPrefs.shouldNotify(
                        signal: currentSignal,
                        for: selectedTimeframe,
                        quality: snapshot.signalQuality
                    ) {
                        // Nouveau signal détecté - envoyer une notification
                        PushService.shared.sendWTSignalNotification(
                            symbol: selectedSymbol.symbol,
                            signal: currentSignal,
                            timeframe: selectedTimeframe.displayName,
                            bias: snapshot.currentMarketBias
                        )
                    }
                    
                    // Mettre à jour le dernier signal pour ce timeframe
                    wtNotificationPrefs.updateLastSignal(currentSignal, for: selectedTimeframe)
                }
                
                self.wtSnapshot = snapshot
                self.wtTimeframe = selectedTimeframe
            }
        } catch {
            Logger.default.error("Failed to load WT snapshot: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load VMC Oscillator Snapshot
    
    private func loadVMCOscillatorSnapshot(timeframe: WTTimeframe? = nil) async {
        let tf = timeframe ?? vmcOscTimeframe
        isLoadingVMCOsc = true
        defer { isLoadingVMCOsc = false }
        do {
            let snapshot = try await VMCService.shared.fetchVMCOscillatorSnapshot(
                symbol: selectedSymbol.symbol,
                interval: tf.binanceInterval,
                limit: 200,
                preset: .swing
            )
            await MainActor.run { self.vmcOscSnapshot = snapshot }
        } catch {
            Logger.default.error("Failed to load VMC Oscillator: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Load MTF Snapshot
    
    private func loadMTFSnapshot() async {
        isLoadingMTF = true
        defer { isLoadingMTF = false }
        
        do {
            let snapshot = try await MTFService.shared.fetchMTFSnapshotCached(symbol: selectedSymbol.symbol)
            await MainActor.run {
                self.mtfSnapshot = snapshot
            }
        } catch {
            Logger.default.error("Failed to load MTF snapshot: \(error.localizedDescription)")
        }
    }
    
    private var photoContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            PhotoAnalysisView()
                .environmentObject(appState)
            
            // Heatmap de liquidation si crypto sélectionné
            if selectedSymbol.isCrypto {
                LiquidityHeatmapView(symbol: selectedSymbol.symbol)
                    .id("photo_heatmap_\(selectedSymbol.symbol)")
            }
        }
    }
    
    private var calendarContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            EconomicCalendarView()
        }
    }
    
    private func section(of type: AssistantAISectionType) -> AssistantAISection? {
        report.sections.first(where: { $0.type == type })
    }
    
    private func interpretTimeframe(_ snapshot: AssistantAIIndicatorSnapshot) -> String {
        var interpretation: [String] = []
        let lang = languageManager.currentLanguage
        
        // RSI
        if snapshot.rsi > 70 {
            interpretation.append(t("rsiOverbought"))
        } else if snapshot.rsi < 30 {
            interpretation.append(t("rsiOversold"))
        }
        
        // MACD
        if snapshot.macd > 0.5 {
            interpretation.append(t("macdBullish"))
        } else if snapshot.macd < -0.5 {
            interpretation.append(t("macdBearish"))
        }
        
        // VMC
        if snapshot.vmc > 30 {
            interpretation.append(t("vmcBullish"))
        } else if snapshot.vmc < -30 {
            interpretation.append(t("vmcBearish"))
        }
        
        // Bias global
        switch snapshot.bias {
        case .bullish:
            interpretation.append(t("biasBullish"))
        case .bearish:
            interpretation.append(t("biasBearish"))
        case .neutral:
            interpretation.append(t("biasNeutral"))
        }
        
        return interpretation.isEmpty ? "" : interpretation.joined(separator: " • ")
    }
}

// MARK: - Specialized Cards

private struct AssistantSummaryCard: View {
    let section: AssistantAISection
    let accentColorHex: String
    
    private var accentColor: Color { Color(hex: accentColorHex) }
    
    var body: some View {
        AssistantCardContainer(accentColor: accentColor) {
            AssistantCardHeader(section: section, accentColor: accentColor)
            Text(section.message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
    }
}

// MARK: - Market Analysis Card
private struct BTCMarketAnalysisCard: View {
    let section: AssistantAISection
    let accentColorHex: String
    let confluence: String
    let fundingRate: Double
    let recommendations: [String]
    var marketSymbol: MarketSymbol = .btcDefault
    
    @ObservedObject private var languageManager = LanguageManager.shared
    private var isEN: Bool { languageManager.currentLanguage == .english }
    
    @State private var btcPrice: Double?
    @State private var priceChange24h: Double?
    @State private var isLoading = false
    @State private var btcAnalysis: String = ""
    @State private var technicalIndicators: TechnicalIndicators?
    @State private var supportResistance: SupportResistance?
    @State private var selectedTimeframe: AnalysisTimeframe = .h1
    
    /// Le symbole à afficher (Binance pour crypto, TwelveData pour le reste)
    private var displaySymbol: String {
        marketSymbol.displayName
    }
    
    /// Le symbole API à utiliser pour les appels klines
    private var apiSymbol: String {
        marketSymbol.symbol
    }
    
    enum AnalysisTimeframe: String, CaseIterable {
        case m5 = "M5"
        case m15 = "M15"
        case h1 = "H1"
        case h4 = "H4"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        
        var binanceInterval: String {
            switch self {
            case .m5: return "5m"
            case .m15: return "15m"
            case .h1: return "1h"
            case .h4: return "4h"
            case .daily: return "1d"
            case .weekly: return "1w"
            case .monthly: return "1M"
            }
        }
        
        var displayName: String {
            rawValue
        }
    }
    
    private var accentColor: Color { Color(hex: accentColorHex) }
    
    private var fundingColor: Color {
        fundingRate >= 0 ? AppColors.success : AppColors.error
    }
    
    struct TechnicalIndicators {
        let rsi1h: Double?
        let rsi4h: Double?
        let rsi1d: Double?
        let macd1h: Double?
        let macd4h: Double?
        let macd1d: Double?
        let volume24h: Double?
        let avgVolume: Double?
        let volatility: Double?
        // Indicateurs pour le timeframe sélectionné
        let selectedRSI: Double?
        let selectedMACD: Double?
        let selectedTimeframe: String
    }
    
    struct SupportResistance {
        let support1: Double
        let support2: Double
        let resistance1: Double
        let resistance2: Double
    }
    
    var body: some View {
        AssistantCardContainer(accentColor: accentColor) {
            // Header dynamique avec nom de l'actif
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                Image(systemName: section.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(AppSpacing.sm)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text((LanguageManager.shared.currentLanguage == .english ? "Analysis" : "Analyse") + " " + displaySymbol)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(marketSymbol.instrumentType.marketDisplayName.uppercased())
                        .font(AppTypography.captionSmall)
                        .fontWeight(.bold)
                        .foregroundColor(accentColor)
                }
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.cyan)
                }
            }
            
            // Sélecteur de timeframe
            timeframeSelector
                .padding(.bottom, AppSpacing.sm)
            
            // Prix en temps réel
            if let price = btcPrice {
                HStack(spacing: AppSpacing.sm) {
                    Text(displaySymbol)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                Spacer()
                    Text("$\(String(format: "%.2f", price))")
                        .font(AppTypography.titleSmall)
                    .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    if let change = priceChange24h {
                        HStack(spacing: 4) {
                            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text(String(format: "%.2f%%", abs(change)))
                        }
                        .font(AppTypography.captionMedium)
                        .foregroundColor(change >= 0 ? AppColors.success : AppColors.error)
                    }
                }
                .padding(.bottom, AppSpacing.xs)
            }
            
            // Analyse BTC détaillée
            if !btcAnalysis.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(btcAnalysis)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
                    
                    // Indicateurs techniques
                    if let indicators = technicalIndicators {
                        Divider().background(AppColors.border.opacity(0.4))
                        
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            // Indicateurs du timeframe sélectionné
                            Text(t("indicateurs"))
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            if let selectedRSI = indicators.selectedRSI {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("rsi"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(AppColors.textSecondary)
                                    indicatorBadge(label: indicators.selectedTimeframe, value: selectedRSI, type: .rsi)
                                }
                            }
                            
                            if let selectedMACD = indicators.selectedMACD {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("indicators"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(AppColors.textSecondary)
                                    indicatorBadge(label: indicators.selectedTimeframe, value: selectedMACD, type: .macd)
                                }
                            }
                            
                            Divider().background(AppColors.border.opacity(0.4))
                                .padding(.vertical, AppSpacing.xs)
                            
                            // Comparaison multi-timeframe
                            Text(t("ai"))
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            // RSI Multi-timeframe
                            if let rsi1h = indicators.rsi1h, let rsi4h = indicators.rsi4h, let rsi1d = indicators.rsi1d {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("rsi"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(AppColors.textSecondary)
                                    HStack(spacing: AppSpacing.sm) {
                                        indicatorBadge(label: "1H", value: rsi1h, type: .rsi)
                                        indicatorBadge(label: "4H", value: rsi4h, type: .rsi)
                                        indicatorBadge(label: "1D", value: rsi1d, type: .rsi)
                                    }
                                }
                            }
                            
                            // MACD Multi-timeframe
                            if let macd1h = indicators.macd1h, let macd4h = indicators.macd4h, let macd1d = indicators.macd1d {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("indicators"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(AppColors.textSecondary)
                                    HStack(spacing: AppSpacing.sm) {
                                        indicatorBadge(label: "1H", value: macd1h, type: .macd)
                                        indicatorBadge(label: "4H", value: macd4h, type: .macd)
                                        indicatorBadge(label: "1D", value: macd1d, type: .macd)
                                    }
                                }
                            }
                            
                            // Volume
                            if let volume24h = indicators.volume24h, let avgVolume = indicators.avgVolume {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("volume24h"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(AppColors.textSecondary)
                                    HStack {
                                        Text(formatVolume(volume24h))
                                            .font(AppTypography.captionMedium)
                                            .foregroundColor(AppColors.textPrimary)
                                        if avgVolume > 0 {
                                            let ratio = volume24h / avgVolume
                                            HStack(spacing: 4) {
                                                Image(systemName: ratio > 1.2 ? "arrow.up.circle.fill" : ratio < 0.8 ? "arrow.down.circle.fill" : "minus.circle.fill")
                                                    .font(.caption2)
                                                Text(String(format: "%.1fx", ratio))
                                            }
                                            .font(AppTypography.captionSmall)
                                            .foregroundColor(ratio > 1.2 ? AppColors.success : ratio < 0.8 ? AppColors.error : AppColors.textSecondary)
                                        }
                                    }
                                }
                            }
                            
                            // Volatilité du timeframe sélectionné
                            if let volatility = indicators.volatility {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(t("indicateurs"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    Text(String(format: "%.2f%%", volatility))
                                        .font(AppTypography.captionMedium)
                                        .foregroundColor(volatility > volatilityThreshold(for: selectedTimeframe) ? AppColors.warning : AppColors.textPrimary)
                                }
                            }
                        }
                    }
                    
                    // Support/Résistance
                    if let sr = supportResistance, let price = btcPrice {
                        Divider().background(AppColors.border.opacity(0.4))
                        
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(t("name"))
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                levelRow(label: isEN ? "Resistance 2" : "Résistance 2", value: sr.resistance2, current: price, type: .resistance)
                                levelRow(label: isEN ? "Resistance 1" : "Résistance 1", value: sr.resistance1, current: price, type: .resistance)
                                levelRow(label: isEN ? "Current Price" : "Prix actuel", value: price, current: price, type: .current)
                                levelRow(label: isEN ? "Support 1" : "Support 1", value: sr.support1, current: price, type: .support)
                                levelRow(label: isEN ? "Support 2" : "Support 2", value: sr.support2, current: price, type: .support)
                            }
                        }
                    }
                }
                .padding(.bottom, AppSpacing.sm)
            } else if isLoading {
                VStack(spacing: AppSpacing.md) {
                    HStack(spacing: AppSpacing.sm) {
                        ProgressView()
                            .scaleEffect(0.9)
                            .tint(.cyan)
                        Text(LanguageManager.shared.currentLanguage == .english ? "Analyzing \(displaySymbol)..." : "Analyse de \(displaySymbol) en cours...")
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    // Barre de progression animée
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColors.background).frame(height: 4)
                            Capsule().fill(
                                LinearGradient(colors: [.cyan, .blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geo.size.width * 0.6, height: 4)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isLoading)
                        }
                    }
                    .frame(height: 4)
                    
                    // Étapes d'analyse
                    HStack(spacing: AppSpacing.lg) {
                        analysisStep(icon: "chart.bar.fill", label: isEN ? "Price" : "Prix", active: true)
                        analysisStep(icon: "waveform.path.ecg", label: isEN ? "Indicators" : "Indicateurs", active: true)
                        analysisStep(icon: "brain.head.profile", label: "AI", active: true)
                    }
                    .font(.system(size: 9))
                }
                .padding(AppSpacing.md)
                .background(AppColors.background.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                .padding(.bottom, AppSpacing.sm)
            }
            
            Divider().background(AppColors.border.opacity(0.4))
            
            // Confluence et Funding Rate
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label(confluence, systemImage: "point.fill.tip.down.left")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(accentColor)
                    Label(String(format: (isEN ? "Funding rate: %.3f%%" : "Funding rate : %.3f%%"), fundingRate * 100), systemImage: "dollarsign.circle")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(fundingColor)
                }
                Spacer()
            }
            
            // Recommandations IA
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(t("ai"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    ForEach(Array(recommendations.prefix(3)), id: \.self) { rec in
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Text("•") // TODO: Traduire avec clé appropriée
                                .foregroundColor(accentColor)
                            Text(rec)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await fetchBTCData()
                await fetchTechnicalData()
                await analyzeBTCMarket()
            }
        }
        .onChange(of: selectedTimeframe) { oldValue, newValue in
            Task {
                await fetchTechnicalData()
                await analyzeBTCMarket()
            }
        }
    }
    
    // MARK: - Sélecteur de Timeframe
    private var timeframeSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(t("unitDeTemps"))
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textTertiary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(AnalysisTimeframe.allCases, id: \.self) { timeframe in
                        Button(action: {
                            HapticFeedback.selection()
                            withAnimation(.spring(response: 0.3)) {
                                selectedTimeframe = timeframe
                            }
                        }) {
                            Text(timeframe.displayName)
                                .font(AppTypography.captionMedium)
                                .fontWeight(.medium)
                                .foregroundColor(selectedTimeframe == timeframe ? AppColors.textPrimary : AppColors.textSecondary)
                                .padding(.horizontal, AppSpacing.sm)
                                .padding(.vertical, AppSpacing.xs)
                                .background(
                                    Capsule()
                                        .fill(selectedTimeframe == timeframe ? accentColor.opacity(0.2) : AppColors.background)
                                        .overlay(
                                            Capsule()
                                                .stroke(selectedTimeframe == timeframe ? accentColor : AppColors.border.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xxs)
            }
        }
    }
    
    private func fetchBTCData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if marketSymbol.isCrypto {
                // CRYPTO : Prix via Binance
                let binSymbol = marketSymbol.binanceSymbol ?? marketSymbol.symbol
                let priceURL = URL(string: "https://api.binance.com/api/v3/ticker/price?symbol=\(binSymbol)")!
                let (priceData, _) = try await URLSession.shared.data(from: priceURL)
                if let priceDict = try JSONSerialization.jsonObject(with: priceData) as? [String: Any],
                   let priceStr = priceDict["price"] as? String,
                   let price = Double(priceStr) {
                    await MainActor.run {
                        btcPrice = price
                    }
                }
                
                let statsURL = URL(string: "https://api.binance.com/api/v3/ticker/24hr?symbol=\(binSymbol)")!
                let (statsData, _) = try await URLSession.shared.data(from: statsURL)
                if let statsDict = try JSONSerialization.jsonObject(with: statsData) as? [String: Any],
                   let changeStr = statsDict["priceChangePercent"] as? String,
                   let change = Double(changeStr) {
                    await MainActor.run {
                        priceChange24h = change
                    }
                }
            } else {
                // NON-CRYPTO : Prix via TwelveData (dernière bougie)
                let candles = try await MarketDataService.shared.fetchKlines(
                    symbol: apiSymbol, interval: "1day", limit: 2
                )
                if let last = candles.last {
                    await MainActor.run {
                        btcPrice = last.close
                        if candles.count >= 2 {
                            let prev = candles[candles.count - 2].close
                            priceChange24h = prev > 0 ? ((last.close - prev) / prev) * 100 : 0
                        }
                    }
                }
            }
        } catch {
            print("❌ [BTCMarketAnalysisCard] Error fetching BTC data: \(error)")
        }
    }
    
    private func fetchTechnicalData() async {
        guard let price = btcPrice else { return }
        
        do {
            let service = MarketDataService.shared
            
            // Récupérer les données pour le timeframe sélectionné
            let selectedInterval = selectedTimeframe.binanceInterval
            let candles = try await service.fetchKlines(symbol: apiSymbol, interval: selectedInterval, limit: 200)
            
            // Calculer les indicateurs pour le timeframe sélectionné
            let prices = candles.map { $0.close }
            let rsi = calculateRSI(prices: prices)
            let macd = calculateMACD(prices: prices)
            
            // Calculer la volatilité pour le timeframe sélectionné
            var returns: [Double] = []
            for index in 1..<prices.count {
                let change = (prices[index] - prices[index - 1]) / prices[index - 1]
                returns.append(change)
            }
            
            let volatility: Double
            if returns.isEmpty {
                volatility = 0
            } else {
                let squaredReturns = returns.map { pow($0, 2) }
                let sumSquared = squaredReturns.reduce(0, +)
                let variance = sumSquared / Double(returns.count)
                let stdDev = sqrt(variance)
                volatility = stdDev * 100
            }
            
            // Calculer support/résistance BASÉS SUR LE TIMEFRAME SÉLECTIONNÉ
            // Utiliser les 50 dernières bougies pour les niveaux clés
            let recentCandles = Array(candles.suffix(50))
            let recentHighs = recentCandles.map { $0.high }
            let recentLows = recentCandles.map { $0.low }
            
            // Résistances : les plus hauts récents
            let sortedHighs = recentHighs.sorted(by: >)
            let resistance1 = sortedHighs.first ?? (price * 1.02)
            let resistance2 = sortedHighs.count > 1 ? sortedHighs[1] : (resistance1 * 1.01)
            
            // Supports : les plus bas récents
            let sortedLows = recentLows.sorted(by: <)
            let support1 = sortedLows.first ?? (price * 0.98)
            let support2 = sortedLows.count > 1 ? sortedLows[1] : (support1 * 0.99)
            
            // Pour l'affichage multi-timeframe, on garde aussi H1, H4, 1D pour comparaison
            let candles1h = try await service.fetchKlines(symbol: apiSymbol, interval: "1h", limit: 100)
            let candles4h = try await service.fetchKlines(symbol: apiSymbol, interval: "4h", limit: 100)
            let candles1d = try await service.fetchKlines(symbol: apiSymbol, interval: "1d", limit: 100)
            
            let prices1h = candles1h.map { $0.close }
            let prices4h = candles4h.map { $0.close }
            let prices1d = candles1d.map { $0.close }
            
            let rsi1h = calculateRSI(prices: prices1h)
            let rsi4h = calculateRSI(prices: prices4h)
            let rsi1d = calculateRSI(prices: prices1d)
            
            let macd1h = calculateMACD(prices: prices1h)
            let macd4h = calculateMACD(prices: prices4h)
            let macd1d = calculateMACD(prices: prices1d)
            
            // Volume 24h (pour référence)
            let volume24h = candles1d.last?.volume ?? 0
            let avgVolume24h = candles1d.suffix(7).map { $0.volume }.reduce(0, +) / Double(min(7, candles1d.count))
            
            await MainActor.run {
                technicalIndicators = TechnicalIndicators(
                    rsi1h: rsi1h,
                    rsi4h: rsi4h,
                    rsi1d: rsi1d,
                    macd1h: macd1h,
                    macd4h: macd4h,
                    macd1d: macd1d,
                    volume24h: volume24h,
                    avgVolume: avgVolume24h,
                    volatility: volatility,
                    selectedRSI: rsi,
                    selectedMACD: macd,
                    selectedTimeframe: selectedTimeframe.displayName
                )
                
                supportResistance = SupportResistance(
                    support1: support1,
                    support2: support2,
                    resistance1: resistance1,
                    resistance2: resistance2
                )
            }
        } catch {
            print("❌ [BTCMarketAnalysisCard] Error fetching technical data: \(error)")
        }
    }
    
    private func calculateRSI(prices: [Double], period: Int = 14) -> Double? {
        guard prices.count > period + 1 else { return nil }
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        for i in 1..<prices.count {
            let change = prices[i] - prices[i-1]
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }
        
        var avgGain = gains.prefix(period).reduce(0, +) / Double(period)
        var avgLoss = losses.prefix(period).reduce(0, +) / Double(period)
        
        for i in period..<gains.count {
            avgGain = (avgGain * Double(period - 1) + gains[i]) / Double(period)
            avgLoss = (avgLoss * Double(period - 1) + losses[i]) / Double(period)
        }
        
        guard avgLoss != 0 else { return 50.0 }
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
    
    private func calculateMACD(prices: [Double], fast: Int = 12, slow: Int = 26) -> Double? {
        guard prices.count >= slow else { return nil }
        
        let fastEMA = calculateEMA(prices, length: fast)
        let slowEMA = calculateEMA(prices, length: slow)
        
        guard let fastVal = fastEMA.last, let slowVal = slowEMA.last else { return nil }
        return fastVal - slowVal
    }
    
    private func calculateEMA(_ values: [Double], length: Int) -> [Double] {
        guard length > 0, !values.isEmpty else { return Array(repeating: 0, count: values.count) }
        let k = 2.0 / (Double(length) + 1.0)
        var out = Array(repeating: 0.0, count: values.count)
        out[0] = values[0]
        for i in 1..<values.count {
            out[i] = values[i] * k + out[i-1] * (1 - k)
        }
        return out
    }
    
    private func analysisStep(icon: String, label: String, active: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundColor(active ? .cyan : AppColors.textTertiary)
            Text(label)
                .foregroundColor(active ? AppColors.textSecondary : AppColors.textTertiary)
        }
        .opacity(active ? 1 : 0.4)
    }
    
    private func analyzeBTCMarket() async {
        guard let price = btcPrice else { return }
        
        var analysis = "📊 " + (isEN ? "ADVANCED TECHNICAL ANALYSIS" : "ANALYSE TECHNIQUE AVANCÉE") + " - \(displaySymbol)\n"
        analysis += (isEN ? "⏱️ Timeframe: " : "⏱️ Timeframe : ") + "\(selectedTimeframe.displayName)\n\n"
        analysis += (isEN ? "💰 Current price: $" : "💰 Prix actuel : $") + "\(String(format: "%.2f", price))\n"
        
        if let change = priceChange24h {
            analysis += (isEN ? "📈 24h Change: " : "📈 Variation 24h : ") + "\(String(format: "%.2f", change))%\n"
        }
        
        analysis += "\n🎯 " + (isEN ? "Confluence: " : "Confluence : ") + "\(confluence)\n"
        if marketSymbol.isCrypto {
            analysis += "💵 Funding rate : \(String(format: "%.3f%%", fundingRate * 100))\n\n"
        } else {
            analysis += "\n"
        }
        
        analysis += "📌 " + (isEN ? "CONTEXT" : "CONTEXTE") + " \(selectedTimeframe.displayName) :\n"
        switch selectedTimeframe {
        case .m5, .m15:
            analysis += isEN
                ? "Very short-term analysis. Ideal for scalping and precise entries.\nSupport/resistance levels are very close to the current price.\n\n"
                : "Analyse très court terme. Idéal pour le scalping et les entrées précises.\nLes niveaux de support/résistance sont très proches du prix actuel.\n\n"
        case .h1, .h4:
            analysis += isEN
                ? "Short/medium-term analysis. Ideal for day traders and swing traders.\nKey levels reflect market structure over a few hours.\n\n"
                : "Analyse court/moyen terme. Idéal pour les day traders et swing traders.\nLes niveaux clés reflètent la structure du marché sur quelques heures.\n\n"
        case .daily:
            analysis += isEN
                ? "Medium-term analysis. Ideal for swing positions and trends.\nKey levels represent important zones for the week.\n\n"
                : "Analyse moyen terme. Idéal pour les positions swing et les tendances.\nLes niveaux clés représentent les zones importantes de la semaine.\n\n"
        case .weekly, .monthly:
            analysis += isEN
                ? "Long-term analysis. Ideal for investors and major trends.\nKey levels represent important structural zones.\n\n"
                : "Analyse long terme. Idéal pour les investisseurs et les tendances majeures.\nLes niveaux clés représentent les zones structurelles importantes.\n\n"
        }
        
        if let indicators = technicalIndicators {
            analysis += "📊 " + (isEN ? "ANALYSIS ON" : "ANALYSE SUR") + " \(indicators.selectedTimeframe) :\n\n"
            
            if let selectedRSI = indicators.selectedRSI {
                analysis += "🔍 RSI (\(indicators.selectedTimeframe)) : \(String(format: "%.1f", selectedRSI)) - \(rsiInterpretation(selectedRSI))\n"
                if selectedRSI > 70 {
                    analysis += isEN ? "⚠️ Overbought zone detected. Correction risk.\n" : "⚠️ Zone de surachat détectée. Risque de correction.\n"
                } else if selectedRSI < 30 {
                    analysis += isEN ? "📉 Oversold zone detected. Possible bounce.\n" : "📉 Zone de survente détectée. Possible rebond.\n"
                } else if selectedRSI > 50 {
                    analysis += isEN ? "✅ Bullish momentum on \(indicators.selectedTimeframe).\n" : "✅ Momentum haussier sur \(indicators.selectedTimeframe).\n"
                } else {
                    analysis += isEN ? "🔻 Bearish momentum on \(indicators.selectedTimeframe).\n" : "🔻 Momentum baissier sur \(indicators.selectedTimeframe).\n"
                }
                analysis += "\n"
            }
            
            if let selectedMACD = indicators.selectedMACD {
                analysis += "📈 MACD (\(indicators.selectedTimeframe)) : \(String(format: "%.4f", selectedMACD)) - \(macdInterpretation(selectedMACD))\n"
                if selectedMACD > 0 {
                    analysis += isEN ? "🚀 Buy momentum confirmed on \(indicators.selectedTimeframe).\n" : "🚀 Momentum d'achat confirmé sur \(indicators.selectedTimeframe).\n"
                } else {
                    analysis += isEN ? "📉 Sell momentum confirmed on \(indicators.selectedTimeframe).\n" : "📉 Momentum de vente confirmé sur \(indicators.selectedTimeframe).\n"
                }
                analysis += "\n"
            }
            
            analysis += "📊 " + (isEN ? "MULTI-TIMEFRAME COMPARISON" : "COMPARAISON MULTI-TIMEFRAME") + " :\n\n"
            
            if let rsi1h = indicators.rsi1h, let rsi4h = indicators.rsi4h, let rsi1d = indicators.rsi1d {
                analysis += "🔍 RSI (\(isEN ? "Relative Strength" : "Force Relative")) :\n"
                analysis += "• 1H : \(String(format: "%.1f", rsi1h)) - \(rsiInterpretation(rsi1h))\n"
                analysis += "• 4H : \(String(format: "%.1f", rsi4h)) - \(rsiInterpretation(rsi4h))\n"
                analysis += "• 1D : \(String(format: "%.1f", rsi1d)) - \(rsiInterpretation(rsi1d))\n\n"
                
                if rsi1h > 70 && rsi4h > 70 && rsi1d > 70 {
                    analysis += isEN ? "⚠️ WIDESPREAD OVERBOUGHT: All timeframes in overbought zone. High correction risk.\n\n" : "⚠️ SUR-ACHAT GÉNÉRALISÉ : Tous les timeframes en zone de surachat. Risque de correction élevé.\n\n"
                } else if rsi1h < 30 && rsi4h < 30 && rsi1d < 30 {
                    analysis += isEN ? "📉 WIDESPREAD OVERSOLD: All timeframes in oversold zone. Possible bounce.\n\n" : "📉 SUR-VENTE GÉNÉRALISÉE : Tous les timeframes en zone de survente. Possible rebond.\n\n"
                } else if (rsi1h > 50 && rsi4h > 50 && rsi1d > 50) {
                    analysis += isEN ? "✅ BULLISH MOMENTUM: RSI above 50 on all timeframes. Uptrend confirmed.\n\n" : "✅ MOMENTUM HAUSSIER : RSI au-dessus de 50 sur tous les timeframes. Tendance haussière confirmée.\n\n"
                } else if (rsi1h < 50 && rsi4h < 50 && rsi1d < 50) {
                    analysis += isEN ? "🔻 BEARISH MOMENTUM: RSI below 50 on all timeframes. Downtrend confirmed.\n\n" : "🔻 MOMENTUM BAISSIER : RSI en dessous de 50 sur tous les timeframes. Tendance baissière confirmée.\n\n"
                }
            }
            
            if let macd1h = indicators.macd1h, let macd4h = indicators.macd4h, let macd1d = indicators.macd1d {
                analysis += "📈 MACD (\(isEN ? "Momentum" : "Momentum")) :\n"
                analysis += "• 1H : \(String(format: "%.4f", macd1h)) - \(macdInterpretation(macd1h))\n"
                analysis += "• 4H : \(String(format: "%.4f", macd4h)) - \(macdInterpretation(macd4h))\n"
                analysis += "• 1D : \(String(format: "%.4f", macd1d)) - \(macdInterpretation(macd1d))\n\n"
                
                if macd1h > 0 && macd4h > 0 && macd1d > 0 {
                    analysis += isEN ? "🚀 STRONG BULLISH MOMENTUM: MACD positive on all timeframes. Buy momentum confirmed.\n\n" : "🚀 MOMENTUM HAUSSIER FORT : MACD positif sur tous les timeframes. Momentum d'achat confirmé.\n\n"
                } else if macd1h < 0 && macd4h < 0 && macd1d < 0 {
                    analysis += isEN ? "📉 STRONG BEARISH MOMENTUM: MACD negative on all timeframes. Sell momentum confirmed.\n\n" : "📉 MOMENTUM BAISSIER FORT : MACD négatif sur tous les timeframes. Momentum de vente confirmé.\n\n"
                }
            }
            
            if let volume24h = indicators.volume24h, let avgVolume = indicators.avgVolume, avgVolume > 0 {
                let volumeRatio = volume24h / avgVolume
                analysis += "📊 " + (isEN ? "Volume" : "Volume") + " (\(indicators.selectedTimeframe)) :\n"
                analysis += "• " + (isEN ? "Current volume: " : "Volume actuel : ") + "\(formatVolume(volume24h))\n"
                analysis += "• " + (isEN ? "Ratio vs average: " : "Ratio vs moyenne : ") + "\(String(format: "%.2fx", volumeRatio))\n"
                if volumeRatio > 1.5 {
                    analysis += isEN ? "🔥 HIGH VOLUME on \(indicators.selectedTimeframe): Strong interest. Trend confirmation.\n\n" : "🔥 VOLUME ÉLEVÉ sur \(indicators.selectedTimeframe) : Intérêt fort. Confirmation de la tendance.\n\n"
                } else if volumeRatio < 0.7 {
                    analysis += isEN ? "⚠️ LOW VOLUME on \(indicators.selectedTimeframe): Lack of interest. Caution.\n\n" : "⚠️ VOLUME FAIBLE sur \(indicators.selectedTimeframe) : Manque d'intérêt. Prudence.\n\n"
                } else {
                    analysis += isEN ? "✅ Normal volume on \(indicators.selectedTimeframe).\n\n" : "✅ Volume normal sur \(indicators.selectedTimeframe).\n\n"
                }
            }
            
            if let volatility = indicators.volatility {
                analysis += "📊 " + (isEN ? "Volatility" : "Volatilité") + " (\(indicators.selectedTimeframe)) : \(String(format: "%.2f%%", volatility))\n"
                let threshold = volatilityThreshold(for: selectedTimeframe)
                if volatility > threshold {
                    analysis += isEN ? "⚠️ HIGH VOLATILITY on \(indicators.selectedTimeframe): Agitated market. Widen your stops.\n\n" : "⚠️ VOLATILITÉ ÉLEVÉE sur \(indicators.selectedTimeframe) : Marché agité. Augmentez vos stops.\n\n"
                } else if volatility < threshold * 0.4 {
                    analysis += isEN ? "✅ Low volatility on \(indicators.selectedTimeframe). Calm market.\n\n" : "✅ Volatilité faible sur \(indicators.selectedTimeframe). Marché calme.\n\n"
                } else {
                    analysis += isEN ? "✅ Moderate volatility on \(indicators.selectedTimeframe).\n\n" : "✅ Volatilité modérée sur \(indicators.selectedTimeframe).\n\n"
                }
            }
        }
        
        if let sr = supportResistance {
            analysis += "🎯 " + (isEN ? "KEY LEVELS" : "NIVEAUX CLÉS") + " (\(selectedTimeframe.displayName)) :\n"
            analysis += "• " + (isEN ? "Resistance 2: $" : "Résistance 2 : $") + "\(String(format: "%.2f", sr.resistance2)) (+\(String(format: "%.2f", (sr.resistance2 - price) / price * 100))%)\n"
            analysis += "• " + (isEN ? "Resistance 1: $" : "Résistance 1 : $") + "\(String(format: "%.2f", sr.resistance1)) (+\(String(format: "%.2f", (sr.resistance1 - price) / price * 100))%)\n"
            analysis += "• " + (isEN ? "Current price: $" : "Prix actuel : $") + "\(String(format: "%.2f", price))\n"
            analysis += "• " + (isEN ? "Support 1: $" : "Support 1 : $") + "\(String(format: "%.2f", sr.support1)) (\(String(format: "%.2f", (sr.support1 - price) / price * 100))%)\n"
            analysis += "• " + (isEN ? "Support 2: $" : "Support 2 : $") + "\(String(format: "%.2f", sr.support2)) (\(String(format: "%.2f", (sr.support2 - price) / price * 100))%)\n\n"
            
            let distanceToResistance = (sr.resistance1 - price) / price * 100
            let distanceToSupport = (price - sr.support1) / price * 100
            let threshold = proximityThreshold(for: selectedTimeframe)
            
            if distanceToResistance < threshold {
                analysis += isEN ? "⚠️ NEAR RESISTANCE on \(selectedTimeframe.displayName): Rejection risk. Watch for sell signals.\n\n" : "⚠️ PROCHE DE LA RÉSISTANCE sur \(selectedTimeframe.displayName) : Risque de rejet. Surveillez les signaux de vente.\n\n"
            } else if distanceToSupport < threshold {
                analysis += isEN ? "📉 NEAR SUPPORT on \(selectedTimeframe.displayName): Possible bounce. Watch for buy signals.\n\n" : "📉 PROCHE DU SUPPORT sur \(selectedTimeframe.displayName) : Possible rebond. Surveillez les signaux d'achat.\n\n"
            } else {
                analysis += isEN ? "✅ Price in neutral zone on \(selectedTimeframe.displayName). Room to maneuver.\n\n" : "✅ Prix dans une zone neutre sur \(selectedTimeframe.displayName). Espace de manœuvre disponible.\n\n"
            }
        }
        
        if fundingRate > 0.1 {
            analysis += isEN ? "⚠️ VERY HIGH FUNDING RATE: Extreme bullish sentiment. Short-term correction risk.\n" : "⚠️ FUNDING RATE TRÈS ÉLEVÉ : Sentiment haussier extrême. Risque de correction à court terme.\n"
        } else if fundingRate < -0.1 {
            analysis += isEN ? "📉 VERY NEGATIVE FUNDING RATE: Bearish sentiment. Possible technical bounce.\n" : "📉 FUNDING RATE TRÈS NÉGATIF : Sentiment baissier. Possible rebond technique.\n"
        } else {
            analysis += isEN ? "✅ Neutral funding rate. Balanced conditions.\n" : "✅ Funding rate neutre. Conditions équilibrées.\n"
        }
        
        await MainActor.run {
            btcAnalysis = analysis
        }
    }
    
    private func rsiInterpretation(_ rsi: Double) -> String {
        if rsi > 70 { return isEN ? "Overbought" : "Surachat" }
        if rsi < 30 { return isEN ? "Oversold" : "Survente" }
        if rsi > 50 { return isEN ? "Bullish" : "Haussier" }
        return isEN ? "Bearish" : "Baissier"
    }
    
    private func macdInterpretation(_ macd: Double) -> String {
        if macd > 0 { return isEN ? "Bullish momentum" : "Momentum haussier" }
        return isEN ? "Bearish momentum" : "Momentum baissier"
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000_000 {
            return String(format: "%.2fB", volume / 1_000_000_000)
        } else if volume >= 1_000_000 {
            return String(format: "%.2fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.2fK", volume / 1_000)
        }
        return String(format: "%.2f", volume)
    }
    
    private func indicatorBadge(label: String, value: Double, type: IndicatorType) -> some View {
        let color: Color
        let interpretation: String
        
        switch type {
        case .rsi:
            if value > 70 {
                color = AppColors.error
                interpretation = isEN ? "Overbought" : "Surachat"
            } else if value < 30 {
                color = AppColors.success
                interpretation = isEN ? "Oversold" : "Survente"
            } else {
                color = AppColors.textSecondary
                interpretation = isEN ? "Neutral" : "Neutre"
            }
        case .macd:
            if value > 0 {
                color = AppColors.success
                interpretation = isEN ? "Bullish" : "Haussier"
            } else {
                color = AppColors.error
                interpretation = isEN ? "Bearish" : "Baissier"
            }
        }
        
        return VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
            Text(String(format: type == .rsi ? "%.0f" : "%.2f", value))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
            Text(interpretation)
                .font(.system(size: 7))
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func levelRow(label: String, value: Double, current: Double, type: LevelType) -> some View {
        let distance = abs(value - current) / current * 100
        let color: Color = type == .resistance ? AppColors.error : type == .support ? AppColors.success : AppColors.primary
        
        return HStack {
            Text(label)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
                Spacer()
            Text("$\(String(format: "%.2f", value))")
                .font(AppTypography.captionMedium)
                .foregroundColor(color)
            if type != .current {
                Text("(\(String(format: "%.2f", value > current ? distance : -distance))%)")
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textTertiary)
            }
        }
    }
    
    enum IndicatorType {
        case rsi, macd
    }
    
    enum LevelType {
        case support, resistance, current
    }
    
    // MARK: - Helper Functions
    private func volatilityThreshold(for timeframe: AnalysisTimeframe) -> Double {
        switch timeframe {
        case .m5, .m15: return 1.0
        case .h1, .h4: return 2.0
        case .daily: return 3.0
        case .weekly, .monthly: return 5.0
        }
    }
    
    private func proximityThreshold(for timeframe: AnalysisTimeframe) -> Double {
        switch timeframe {
        case .m5, .m15: return 0.5
        case .h1, .h4: return 1.0
        case .daily: return 2.0
        case .weekly, .monthly: return 3.0
        }
    }
}

private struct AssistantMarketCard: View {
    let section: AssistantAISection
    let accentColorHex: String
    let confluence: String
    let fundingRate: Double
    let recommendations: [String]
    
    @ObservedObject private var languageManager = LanguageManager.shared
    private var isEN: Bool { languageManager.currentLanguage == .english }
    
    private var accentColor: Color { Color(hex: accentColorHex) }
    
    private var fundingColor: Color {
        fundingRate >= 0 ? AppColors.success : AppColors.error
    }
    
    var body: some View {
        AssistantCardContainer(accentColor: accentColor) {
            AssistantCardHeader(section: section, accentColor: accentColor)
            Text(section.message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            Divider().background(AppColors.border.opacity(0.4))
            
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Label(confluence, systemImage: "point.fill.tip.down.left" )
                        .font(AppTypography.captionMedium)
                        .foregroundColor(accentColor)
                    Label(String(format: (isEN ? "Funding rate: %.3f%%" : "Funding rate : %.3f%%"), fundingRate * 100), systemImage: "dollarsign.circle")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(fundingColor)
                }
                Spacer()
            }
            
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(t("ai"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    ForEach(Array(recommendations.prefix(3)), id: \.self) { rec in
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Text("•") // TODO: Traduire avec clé appropriée
                                .foregroundColor(accentColor)
                            Text(rec)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

private struct AssistantDisciplineCard: View {
    let section: AssistantAISection
    let accentColorHex: String
    let riskScore: Int
    let trendRecommendation: String
    
    private var accentColor: Color { Color(hex: accentColorHex) }
    
    var body: some View {
        AssistantCardContainer(accentColor: accentColor) {
            AssistantCardHeader(section: section, accentColor: accentColor)
            Text(section.message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            Divider().background(AppColors.border.opacity(0.4))
            
            HStack(spacing: AppSpacing.sm) {
                ScoreBadge(label: "Risque", value: riskScore, color: accentColor)
                Text(trendRecommendation)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
        }
    }
}

private struct AssistantEmotionCard: View {
    let section: AssistantAISection
    let accentColorHex: String
    let emotionScore: Int
    
    private var accentColor: Color { Color(hex: accentColorHex) }
    
    var body: some View {
        AssistantCardContainer(accentColor: accentColor) {
            AssistantCardHeader(section: section, accentColor: accentColor)
            Text(section.message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            Divider().background(AppColors.border.opacity(0.4))
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(t("scoremotionnelemotionscore100"))
                    .font(AppTypography.captionMedium)
                    .foregroundColor(accentColor)
                ProgressView(value: Double(emotionScore) / 100)
                    .progressViewStyle(.linear)
                    .tint(accentColor)
            }
        }
    }
}

private struct AssistantPerformanceCard: View {
    let section: AssistantAISection
    let accentColorHex: String
    let indicatorSnapshots: [AssistantAIIndicatorSnapshot]
    let technicalSummary: String
    let riskScore: Int
    
    private var accentColor: Color { Color(hex: accentColorHex) }
    
    var body: some View {
        AssistantCardContainer(accentColor: accentColor) {
            AssistantCardHeader(section: section, accentColor: accentColor)
            Text(section.message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            Divider().background(AppColors.border.opacity(0.4))
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(technicalSummary)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                
                ScoreBadge(label: "Risk score", value: riskScore, color: accentColor)
                
                if !indicatorSnapshots.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(t("indicateurs"))
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                        ForEach(indicatorSnapshots) { snapshot in
                            AssistantIndicatorRow(snapshot: snapshot)
                        }
                    }
                }
            }
        }
    }
}

private struct AssistantPhotoCard: View {
    let section: AssistantAISection
    let accentColorHex: String
    
    private var accentColor: Color { Color(hex: accentColorHex) }
    
    var body: some View {
        AssistantCardContainer(accentColor: accentColor) {
            AssistantCardHeader(section: section, accentColor: accentColor)
            Text(section.message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
    }
}

private struct AssistantRecommendationsCard: View {
    let recommendations: [String]
    let accentColor: Color
    
    var body: some View {
        AssistantCardContainer(accentColor: accentColor) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "sparkles")
                    .foregroundColor(.white)
                    .padding(AppSpacing.sm)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small))
                Text(t("conseils"))
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            
            if recommendations.isEmpty {
                Text(t("ai"))
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { item in
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Text("•") // TODO: Traduire avec clé appropriée
                                .foregroundColor(accentColor)
                            Text(item.element)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

private struct PremiumLockedCard: View {
    let title: String
    let accentColorHex: String
    
    private var accentColor: Color { Color(hex: accentColorHex) }
    
    var body: some View {
        AssistantCardContainer(accentColor: accentColor.opacity(0.4)) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundColor(accentColor)
                Text(title)
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
            }
            Text(t("disponibleAvecLabonnementPremium"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Helper Components

private struct AssistantCardContainer<Content: View>: View {
    let accentColor: Color
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            content
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(accentColor.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: accentColor.opacity(0.08), radius: 10, x: 0, y: 4)
    }
}

private struct AssistantCardHeader: View {
    let section: AssistantAISection
    let accentColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: section.icon)
                .font(.title2)
                .foregroundColor(.white)
                .padding(AppSpacing.sm)
                .background(
                            LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                Text(section.type.rawValue.uppercased())
                    .font(AppTypography.captionSmall)
                    .foregroundColor(accentColor.opacity(0.8))
            }
            Spacer()
        }
    }
}

private struct ScoreBadge: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: "shield.fill")
            Text(t("labelvalue100"))
        }
        .font(AppTypography.captionMedium)
        .foregroundColor(color)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct AssistantIndicatorRow: View {
    let snapshot: AssistantAIIndicatorSnapshot
    
    private var biasColor: Color {
        switch snapshot.bias {
        case .bullish: return AppColors.success
        case .bearish: return AppColors.error
        case .neutral: return AppColors.textSecondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(snapshot.timeframe)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(snapshot.bias.rawValue.capitalized)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(biasColor)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 4)
                    .background(biasColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            HStack(spacing: AppSpacing.md) {
                indicatorColumn(title: "RSI", value: "\(snapshot.rsi)")
                indicatorColumn(title: "MACD", value: String(format: "%.2f", snapshot.macd))
                indicatorColumn(title: "TRIX", value: String(format: "%.2f", snapshot.trix))
                indicatorColumn(title: "VMC", value: String(format: "%.2f", snapshot.vmc))
                indicatorColumn(title: "ODP", value: String(format: "%.2f", snapshot.odp))
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }
    
    private func indicatorColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textPrimary)
        }
    }
}

enum AssistantTab: CaseIterable {
    case insights
    case conseils
    case analyse
    case indicateurs
    case photo
    case calendar
    
    func title(language: Localizable.Language) -> String {
        switch self {
        case .insights: return Localizable.text("insights", language: language)
        case .conseils: return Localizable.text("conseils", language: language)
        case .analyse: return Localizable.text("analyse", language: language)
        case .indicateurs: return Localizable.text("indicateurs", language: language)
        case .photo: return Localizable.text("photo", language: language)
        case .calendar: return Localizable.text("calendar", language: language)
        }
    }
    
    var icon: String {
        switch self {
        case .insights: return "lightbulb"
        case .conseils: return "sparkles"
        case .analyse: return "brain"
        case .indicateurs: return "chart.line.uptrend.xyaxis"
        case .photo: return "camera"
        case .calendar: return "calendar"
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .insights:
            return LinearGradient(colors: [Color(hex: "#0A85FF"), Color(hex: "#4E46DD")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .conseils:
            return LinearGradient(colors: [Color(hex: "#FF7E4C"), Color(hex: "#FF4D94")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .analyse:
            return LinearGradient(colors: [Color(hex: "#933CFF"), Color(hex: "#5A3BFF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .indicateurs:
            return LinearGradient(colors: [Color(hex: "#4CD964"), Color(hex: "#1CC8EE")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .photo:
            return LinearGradient(colors: [Color(hex: "#FF9F0A"), Color(hex: "#FF5E3A")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .calendar:
            return LinearGradient(colors: [Color(hex: "#00D9FF"), Color(hex: "#0A85FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

private struct AssistantTabButton: View {
    let tab: AssistantTab
    let isSelected: Bool
    let action: () -> Void
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(tab.title(language: languageManager.currentLanguage))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : AppColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? tab.gradient : LinearGradient(colors: [AppColors.cardBackground], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : AppColors.border.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: isSelected ? AppColors.primary.opacity(0.25) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
