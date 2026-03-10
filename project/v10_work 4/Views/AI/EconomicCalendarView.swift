//
//  EconomicCalendarView.swift
//  Journal de trading 2025
//
//  Vue du calendrier économique avec analyse IA des risques
//

import SwiftUI

struct EconomicCalendarView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    // Store central (source de vérité)
    @StateObject private var store = EconomicCalendarStore.shared
    
    // État UI local
    @State private var selectedEvent: EconomicEvent? = nil
    @State private var timezones: [TimezoneInfo] = []
    @State private var selectedTimezone: String = "GMT+0"
    @State private var isLoadingTimezones = false
    @State private var selectedVolatility: String = "ALL" // ALL, HIGH, MEDIUM, LOW, NONE
    @State private var selectedPeriod: PeriodFilter = .week // Aujourd'hui, Demain, Semaine
    @State private var selectedMarket: String = "Crypto" // Crypto, Forex, Actions, Commodities
    
    // Événements filtrés (calculé localement, pas de refetch)
    private var filteredEvents: [EconomicEvent] {
        store.filteredEvents(volatility: selectedVolatility)
    }
    
    enum PeriodFilter: String, CaseIterable {
        case today = "today"
        case tomorrow = "tomorrow"
        case week = "week"
        
        var displayName: String {
            let lang = LanguageManager.shared.currentLanguage
            switch self {
            case .today:    return Localizable.text("periodToday", language: lang)
            case .tomorrow: return Localizable.text("periodTomorrow", language: lang)
            case .week:     return Localizable.text("periodWeek", language: lang)
            }
        }
    }
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Analyse des risques (toujours calculée sur données brutes)
            if let analysis = store.riskAnalysis {
                riskAnalysisCard(analysis: analysis)
            }
            
            // Calendrier des événements (filtrés localement)
            eventsList
        }
        .onAppear {
            // Charger les événements uniquement au premier affichage
            Task {
                try? await store.loadEvents(for: selectedPeriod, forceRefresh: false)
            }
        }
        .onChange(of: selectedPeriod) { oldPeriod, newPeriod in
            // Changement de période = refetch nécessaire
            Logger.default.info("🔄 Changement de période: \(oldPeriod.displayName) → \(newPeriod.displayName)")
            Task {
                try? await store.loadEvents(for: newPeriod, forceRefresh: false)
            }
        }
        .refreshable {
            // Pull-to-refresh = force refresh
            Logger.default.info("🔄 Pull-to-refresh déclenché")
            try? await store.loadEvents(for: selectedPeriod, forceRefresh: true)
        }
    }
    
    // MARK: - Risk Analysis Card
    
    private func riskAnalysisCard(analysis: MarketRiskAnalysis) -> some View {
        // Trouver l'analyse pour le marché sélectionné
        let marketAnalysis = analysis.marketRecommendations.first { $0.market == selectedMarket }
        
        return VStack(spacing: AppSpacing.md) {
            // 1. Analyse générale (en haut)
            generalAnalysisCard(analysis: analysis)
            
            // 2. Analyse par marché (bulle séparée en dessous)
            if let marketAnalysis = marketAnalysis {
                marketSpecificAnalysisCard(marketAnalysis: marketAnalysis, riskLevel: analysis.riskLevel)
            }
        }
    }
    
    // MARK: - General Analysis Card
    
    private func generalAnalysisCard(analysis: MarketRiskAnalysis) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header avec titre et sélecteur de période
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: analysis.riskLevel.color))
                
                Text(t("analyse"))
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                // Sélecteur de période (compact)
                periodSelectorCompact
            }
            
            // Sentiment de marché sur une seule ligne
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: analysis.marketSentiment.icon)
                    .font(.title3)
                    .foregroundColor(Color(hex: analysis.marketSentiment.color))
                Text(t("tuesday"))
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: analysis.marketSentiment.color))
            }
            
            // Argumentation du sentiment
            Text(analysis.sentimentArgumentation)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(2)
            
            // Résumé général
            Text(analysis.summary)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            // Recommandations générales
            if !analysis.recommendations.isEmpty {
                Divider().background(AppColors.border.opacity(0.4))
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(t("recommandationsGnrales"))
                        .font(AppTypography.captionMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    ForEach(analysis.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(Color(hex: analysis.riskLevel.color))
                            Text(recommendation)
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(Color(hex: analysis.riskLevel.color).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Market Specific Analysis Card (Bulle séparée)
    
    private func marketSpecificAnalysisCard(marketAnalysis: MarketRiskAnalysis.MarketRecommendation, riskLevel: MarketRiskAnalysis.RiskLevel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header avec titre et sélecteur de marché
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundColor(Color(hex: riskLevel.color))
                
                Text(t("tuesday"))
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                // Sélecteur de marché
                marketSelector
            }
            
            // Contenu de l'analyse spécifique au marché
            marketSpecificAnalysis(marketAnalysis: marketAnalysis, riskLevel: riskLevel)
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(Color(hex: riskLevel.color).opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Events List
    
    private var eventsList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(t("no"))
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                
                if store.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Sélecteur de volatilité uniquement (la période est dans le header de l'analyse)
            volatilitySelector
            
            if let error = store.errorMessage {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(AppColors.error)
                    Text(error)
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Réessayer") {
                        Task {
                            try? await store.loadEvents(for: selectedPeriod, forceRefresh: true)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            } else if filteredEvents.isEmpty && !store.isLoading {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.title)
                        .foregroundColor(AppColors.textTertiary)
                    Text(t("aucunvnementTrouv"))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                // Grouper les événements filtrés par date
                let groupedEvents = Dictionary(grouping: filteredEvents) { event in
                    calendar.startOfDay(for: event.dateValue ?? Date())
                }
                let sortedDates = groupedEvents.keys.sorted()
                
                ForEach(sortedDates, id: \.self) { date in
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(date, style: .date)
                            .font(AppTypography.captionMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.top, AppSpacing.sm)
                        
                        ForEach(groupedEvents[date] ?? []) { event in
                            eventCard(event: event)
                        }
                    }
                }
            }
        }
    }
    
    private func eventCard(event: EconomicEvent) -> some View {
        Button(action: {
            selectedEvent = event
        }) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    // Icône de catégorie
                    Image(systemName: (event.category ?? .other).icon)
                        .font(.title3)
                        .foregroundColor(Color(hex: event.impactValue.color))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color(hex: event.impactValue.color).opacity(0.2))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(AppTypography.bodySmall)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                        
                        HStack(spacing: AppSpacing.xs) {
                            Text(event.country)
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text("•") // TODO: Traduire avec clé appropriée
                                .foregroundColor(AppColors.textTertiary)
                            
                            Text((event.category ?? .other).displayName)
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        HStack(spacing: AppSpacing.xs) {
                            if let dateValue = event.dateValue {
                                Text(dateValue, style: .time)
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            
                            // Badge d'impact
                            Text(event.impactValue.displayName)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color(hex: event.impactValue.color))
                                )
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                }
                
                // Actual, Forecast, Previous (si disponibles)
                if event.actual != nil || event.forecast != nil || event.previous != nil {
                    Divider().background(AppColors.border.opacity(0.3))
                    
                    HStack(spacing: AppSpacing.md) {
                        // Previous
                        if let previous = event.previous {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("prcdent"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                                Text(previous)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Forecast
                        if let forecast = event.forecast {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("prvision"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                                Text(forecast)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Actual
                        if let actual = event.actual {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t("rel"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(AppColors.textTertiary)
                                Text(actual)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }
            }
            .padding()
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        }
        .buttonStyle(.plain)
        .sheet(item: $selectedEvent) { event in
            eventDetailView(event: event)
        }
    }
    
    // MARK: - Event Detail View
    
    private func eventDetailView(event: EconomicEvent) -> some View {
        let insight = AIEventAnalyzer.shared.analyzeEvent(event)
        
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(event.title)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        
                        HStack(spacing: AppSpacing.sm) {
                            Label(event.country, systemImage: "flag.fill")
                            Label((event.category ?? .other).displayName, systemImage: (event.category ?? .other).icon)
                            Label(event.impactValue.displayName, systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(hex: event.impactValue.color))
                        }
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Divider()
                    
                    // Analyse IA
                    aiInsightCard(insight: insight)
                    
                    Divider()
                    
                    // Date et heure
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(t("date"))
                            .font(AppTypography.captionMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        if let dateValue = event.dateValue {
                            Text(dateFormatter.string(from: dateValue))
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        } else {
                            Text(t("no"))
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    
                    // Valeurs
                    if let actual = event.actual, let forecast = event.forecast, let previous = event.previous {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(t("valeurs"))
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            HStack(spacing: AppSpacing.md) {
                                VStack(alignment: .leading) {
                                    Text(t("prcdent"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(AppColors.textTertiary)
                                    Text(previous)
                                        .font(AppTypography.bodySmall)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(t("prvision"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(AppColors.textTertiary)
                                    Text(forecast)
                                        .font(AppTypography.bodySmall)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text(t("rel"))
                                        .font(AppTypography.captionSmall)
                                        .foregroundColor(AppColors.textTertiary)
                                    Text(actual)
                                        .font(AppTypography.bodySmall)
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }
                        }
                    }
                    
                    // Description
                    if let description = event.description {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(t("description"))
                                .font(AppTypography.captionMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            Text(description)
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(t("details"))
            .navigationBarTitleDisplayMode(.inline)
            .background(AppColors.background)
        }
    }
    
    // MARK: - AI Insight Card
    
    private func aiInsightCard(insight: AIEventInsight) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title3)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Intensité: \(insight.intensity)")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // Badge de statut
                Text(insight.status == .preRelease ? "Pré-publication" : "Publié")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(insight.status == .preRelease ? Color.orange : Color.green)
                    )
            }
            
            // Sentiment de l'événement
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: insight.eventSentiment.icon)
                    .font(.title3)
                    .foregroundColor(Color(hex: insight.eventSentiment.color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(t("friday"))
                        .font(AppTypography.captionMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: insight.eventSentiment.color))
                    Text(insight.eventSentimentArgumentation)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(2)
                }
            }
            .padding(.vertical, AppSpacing.xs)
            
            Divider()
            
            // Résumé
            Text(insight.summary)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            // Scénarios (si pré-publication)
            if let scenarios = insight.scenarios, insight.status == .preRelease {
                Divider()
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(t("scnarios"))
                        .font(AppTypography.captionMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Text(t("siConsensus"))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textTertiary)
                            Text(scenarios.above)
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Text(t("siConsensus"))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textTertiary)
                            Text(scenarios.below)
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            
            // Surprise (si post-publication)
            if let surprise = insight.surprise, insight.status == .postRelease {
                Divider()
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(t("surprise"))
                        .font(AppTypography.captionMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    HStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading) {
                            Text(t("direction"))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textTertiary)
                            Text(surpriseDirectionText(surprise.direction))
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        if let pct = surprise.surprisePct {
                            VStack(alignment: .leading) {
                                Text(t("cart"))
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(AppColors.textTertiary)
                                Text(String(format: "%.2f%%", abs(pct) * 100))
                                    .font(AppTypography.bodySmall)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text(t("intensit"))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textTertiary)
                            Text(surpriseIntensityText(surprise.intensity))
                                .font(AppTypography.bodySmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func surpriseDirectionText(_ direction: SurpriseResult.SurpriseDirection) -> String {
        switch direction {
        case .above: return "Au-dessus"
        case .below: return "En-dessous"
        case .equal: return "Conforme"
        case .unknown: return "Inconnu"
        }
    }
    
    private func surpriseIntensityText(_ intensity: SurpriseResult.SurpriseIntensity) -> String {
        switch intensity {
        case .high: return "Élevée"
        case .medium: return "Modérée"
        case .low: return "Faible"
        case .none: return "Aucune"
        }
    }
    
    // MARK: - Volatility Selector
    
    private var volatilitySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(["ALL", "HIGH", "MEDIUM", "LOW", "NONE"], id: \.self) { volatility in
                    Button(action: {
                        HapticFeedback.selection()
                        // ✅ Filtre local uniquement - PAS de refetch réseau
                        Logger.default.info("🔍 Filtre volatilité changé: \(selectedVolatility) → \(volatility) (filtre local)")
                        selectedVolatility = volatility
                        // Pas de loadEvents() - le filtre est appliqué via filteredEvents computed property
                    }) {
                        Text(volatilityLabel(volatility))
                            .font(AppTypography.captionMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(selectedVolatility == volatility ? .white : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                Capsule()
                                    .fill(selectedVolatility == volatility ? Color.blue.opacity(0.8) : AppColors.cardBackground)
                                    .overlay(
                                        Capsule()
                                            .stroke(selectedVolatility == volatility ? Color.blue : AppColors.border.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
    }
    
    private func volatilityLabel(_ volatility: String) -> String {
        switch volatility {
        case "ALL": return "Tous"
        case "HIGH": return "Élevée"
        case "MEDIUM": return "Moyenne"
        case "LOW": return "Faible"
        case "NONE": return "Aucune"
        default: return volatility
        }
    }
    
    // MARK: - Period Selector (Compact pour header)
    
    private var periodSelectorCompact: some View {
        Menu {
            ForEach(PeriodFilter.allCases, id: \.self) { period in
                Button(action: {
                    HapticFeedback.selection()
                    selectedPeriod = period
                }) {
                    HStack {
                        Text(period.displayName)
                        if selectedPeriod == period {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(selectedPeriod.displayName)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AppColors.cardBackground.opacity(0.6))
                    .overlay(
                        Capsule()
                            .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Market Selector
    
    private var marketSelector: some View {
        Menu {
            ForEach(["Crypto", "Forex", "Actions", "Commodities"], id: \.self) { market in
                Button(action: {
                    HapticFeedback.selection()
                    selectedMarket = market
                }) {
                    HStack {
                        Text(market)
                        if selectedMarket == market {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2)
                Text(selectedMarket)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AppColors.cardBackground.opacity(0.6))
                    .overlay(
                        Capsule()
                            .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Market Specific Analysis (Format précis et directive)
    
    private func marketSpecificAnalysis(marketAnalysis: MarketRiskAnalysis.MarketRecommendation, riskLevel: MarketRiskAnalysis.RiskLevel) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Titre : "Crypto — CPI en hausse"
            Text(marketAnalysis.title)
                .font(AppTypography.titleSmall)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            // Sentiment et Intensité sur une seule ligne
            HStack(spacing: AppSpacing.md) {
                HStack(spacing: 4) {
                    Text(t("sentiment"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Text(marketAnalysis.sentiment.displayName)
                        .font(AppTypography.captionMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: marketAnalysis.sentiment.color))
                }
                
                HStack(spacing: 4) {
                    Text(t("intensit"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Text(marketAnalysis.intensity)
                        .font(AppTypography.captionMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: riskLevel.color))
                }
            }
            
            Divider().background(AppColors.border.opacity(0.4))
            
            // Explication détaillée
            Text(marketAnalysis.explanation)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            // Recommandations actionnables avec flèches
            if !marketAnalysis.actionableRecommendations.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(t("recommandation"))
                        .font(AppTypography.captionMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    ForEach(marketAnalysis.actionableRecommendations, id: \.self) { rec in
                        HStack(alignment: .top, spacing: AppSpacing.xs) {
                            Text("➡️") // TODO: Traduire avec clé appropriée
                                .font(.caption)
                            Text(rec)
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - General Market Analysis (Fallback)
    
    private func generalMarketAnalysis(analysis: MarketRiskAnalysis) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Sentiment de marché sur une seule ligne
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: analysis.marketSentiment.icon)
                    .font(.title3)
                    .foregroundColor(Color(hex: analysis.marketSentiment.color))
                Text(t("tuesday"))
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: analysis.marketSentiment.color))
            }
            
            Text(analysis.sentimentArgumentation)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(2)
            
            Text(analysis.summary)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
        }
    }
    
    // MARK: - Load Timezones
    
    private func loadTimezones() {
        Task {
            isLoadingTimezones = true
            defer { isLoadingTimezones = false }
            
            do {
                let fetchedTimezones = try await EconomicCalendarService.shared.fetchTimezones()
                await MainActor.run {
                    self.timezones = fetchedTimezones
                    // Définir le timezone par défaut si disponible
                    if let defaultTz = fetchedTimezones.first(where: { $0.timezone == "GMT+0" }) {
                        self.selectedTimezone = defaultTz.timezone
                    }
                }
            } catch {
                // En cas d'erreur, utiliser GMT+0 par défaut
                Logger.default.error("Failed to load timezones: \(error.localizedDescription)")
            }
        }
    }
}
