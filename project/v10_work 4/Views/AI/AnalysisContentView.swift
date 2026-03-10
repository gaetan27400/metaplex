//
//  AnalysisContentView.swift
//  Journal de trading 2025
//
//  Nouvelle vue refactorisée pour l'onglet Analyse IA

import SwiftUI

struct AnalysisContentView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var languageManager = LanguageManager.shared
    
    // States
    @State private var showScoreDetails = false
    @State private var showProbabilityDetails = false
    @State private var showBullExplanation = false
    @State private var showBearExplanation = false
    @State private var currentAdvice: TradingAdviceSummary?
    
    // Data
    let selectedSymbol: MarketSymbol
    let mtfSnapshot: MTFSnapshot?
    let wtSnapshot: WTSnapshot?
    let vmcOscSnapshot: VMCOscillatorSnapshot?
    let lastUpdate: Date?
    
    // Generated scenarios
    @State private var bullScenario: TradeScenario = .mockBull
    @State private var bearScenario: TradeScenario = .mockBear
    @State private var bullExplanation: ScenarioExplanation = .mockBull
    @State private var bearExplanation: ScenarioExplanation = .mockBear
    @State private var currentPrice: Double?
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AnalysisDesign.Spacing.lg) {
                // 1) HEADER COMPACT
                headerSection
                
                // 2) PLAN DE TRADE
                tradePlanSection
                
                // 3) GESTION DU RISQUE
                riskManagementSection
                
                // 4) TIMING & CONTEXTE
                timingSection
                
                // 5) ANALYSE TECHNIQUE (collapsible)
                technicalAnalysisSection
                
                // 6) INFORMATIONS IMPORTANTES (collapsible)
                importantInfoSection
            }
            .padding(.horizontal, AnalysisDesign.Spacing.lg)
            .padding(.top, AnalysisDesign.Spacing.xl)
            .padding(.bottom, AnalysisDesign.Spacing.lg)
        }
        .background(AnalysisDesign.Colors.background.ignoresSafeArea())
        .onAppear {
            loadAdvice()
            Task {
                await loadScenarios()
            }
        }
        .onChange(of: selectedSymbol) { _, _ in
            Task { await loadScenarios() }
        }
        .onChange(of: mtfSnapshot) { _, _ in
            Task { await loadScenarios() }
        }
        .onChange(of: wtSnapshot) { _, _ in
            Task { await loadScenarios() }
        }
        .onChange(of: vmcOscSnapshot) { _, _ in
            Task { await loadScenarios() }
        }
        // Reload scenarios when language changes so labels update immediately
        .onChange(of: languageManager.currentLanguage) { _, _ in
            Task { await loadScenarios() }
        }
    }
    
    // MARK: - 1) Header Section
    
    private var headerSection: some View {
        AnalysisHeader(
            symbol: selectedSymbol.displayName,
            score: calculatedScore,
            bullProbability: calculatedBullProbability,
            lastUpdate: lastUpdate,
            onScoreTap: {
                showScoreDetails = true
            },
            onProbabilityTap: {
                showProbabilityDetails = true
            }
        )
        .sheet(isPresented: $showScoreDetails) {
            if let advice = currentAdvice {
                ScoreDetailSheet(
                    advice: advice,
                    instrumentType: selectedSymbol.instrumentType
                )
            }
        }
        .sheet(isPresented: $showProbabilityDetails) {
            ProbabilityDetailSheet(
                bullProbability: calculatedBullProbability,
                bearProbability: 1 - calculatedBullProbability
            )
        }
    }
    
    // MARK: - 2) Trade Plan Section
    
    private var tradePlanSection: some View {
        VStack(alignment: .leading, spacing: AnalysisDesign.Spacing.md) {
            AnalysisSectionHeader(
                title: t("tradePlanTitle"),
                icon: "chart.line.uptrend.xyaxis",
                accentColor: AnalysisDesign.Colors.analysisPrimary
            )
            
            // Cartes Bull / Bear symétriques
            HStack(alignment: .top, spacing: 12) {
                TradeScenarioCard(
                    type: .bull,
                    scenario: bullScenario,
                    onInfoTap: {
                        showBullExplanation = true
                    }
                )
                
                TradeScenarioCard(
                    type: .bear,
                    scenario: bearScenario,
                    onInfoTap: {
                        showBearExplanation = true
                    }
                )
            }
        }
        .sheet(isPresented: $showBullExplanation) {
            TradeExplanationSheet(
                type: .bull,
                explanation: bullExplanation
            )
        }
        .sheet(isPresented: $showBearExplanation) {
            TradeExplanationSheet(
                type: .bear,
                explanation: bearExplanation
            )
        }
    }
    
    // MARK: - 3) Risk Management Section
    
    private var riskManagementSection: some View {
        VStack(alignment: .leading, spacing: AnalysisDesign.Spacing.md) {
            AnalysisSectionHeader(
                title: t("riskManagementTitle"),
                icon: "shield.lefthalf.filled",
                accentColor: .orange
            )
            
            VStack(spacing: 12) {
                riskCard(
                    title: t("recommendedRisk"),
                    value: recommendedRisk,
                    icon: "percent",
                    color: .orange
                )
                
                riskCard(
                    title: languageManager.currentLanguage == .english ? "Position Size" : "Position Size",
                    value: recommendedPositionSize,
                    icon: "chart.bar.fill",
                    color: .blue
                )
                
                riskCard(
                    title: languageManager.currentLanguage == .english ? "Max Loss / Trade" : "Max Loss / Trade",
                    value: maxLossPerTrade,
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
            .padding(AnalysisDesign.Spacing.lg)
            .analysisCardStyle(accentColor: .orange)
        }
    }
    
    private func riskCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 28)
            
            Text(title)
                .font(AnalysisDesign.Typography.labelMedium)
                .foregroundColor(AnalysisDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AnalysisDesign.Typography.scoreSmall)
                .foregroundColor(color)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AnalysisDesign.Radius.medium)
                .fill(color.opacity(0.08))
        )
    }
    
    // MARK: - 4) Timing Section
    
    private var timingSection: some View {
        let isEN = languageManager.currentLanguage == .english
        return VStack(alignment: .leading, spacing: AnalysisDesign.Spacing.md) {
            AnalysisSectionHeader(
                title: isEN ? "Timing & Context" : "Timing & Contexte",
                icon: "clock.badge.checkmark.fill",
                accentColor: .cyan
            )
            
            VStack(alignment: .leading, spacing: 12) {
                if let window = currentAdvice?.optimalWindow {
                    timingRow(
                        label: isEN ? "Optimal window" : "Fenêtre optimale",
                        value: window,
                        icon: "star.fill",
                        color: .green
                    )
                }
                
                if let focus = currentAdvice?.focus {
                    timingRow(
                        label: isEN ? "Daily focus" : "Focus du jour",
                        value: focus,
                        icon: "target",
                        color: .purple
                    )
                }
                
                timingRow(
                    label: isEN ? "Current session" : "Session actuelle",
                    value: currentSession,
                    icon: "globe",
                    color: .blue
                )
            }
            .padding(AnalysisDesign.Spacing.lg)
            .analysisCardStyle(accentColor: .cyan)
        }
    }
    
    private func timingRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AnalysisDesign.Typography.captionMedium)
                    .foregroundColor(AnalysisDesign.Colors.textSecondary)
                
                Text(value)
                    .font(AnalysisDesign.Typography.bodyRegular)
                    .foregroundColor(AnalysisDesign.Colors.textPrimary)
                    .lineSpacing(3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AnalysisDesign.Radius.medium)
                .fill(color.opacity(0.08))
        )
    }
    
    // MARK: - 5) Technical Analysis (Collapsible)
    
    private var technicalAnalysisSection: some View {
        CollapsibleSection(
            title: t("technicalAnalysisTitle"),
            icon: "chart.xyaxis.line",
            accentColor: .cyan,
            preview: technicalPreview
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if let support1 = technicalSupport1 {
                    AnalysisDataRow(
                        label: t("support1"),
                        value: support1,
                        valueColor: .green,
                        icon: "arrow.down.circle.fill"
                    )
                }
                
                if let resistance1 = technicalResistance1 {
                    AnalysisDataRow(
                        label: t("resistance1"),
                        value: resistance1,
                        valueColor: .red,
                        icon: "arrow.up.circle.fill"
                    )
                }
                
                AnalysisDivider()
                
                if let mtf = mtfSnapshot {
                    let isEN = languageManager.currentLanguage == .english
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isEN ? "MTF Confluence" : "Confluence MTF")
                            .font(AnalysisDesign.Typography.labelLarge)
                            .foregroundColor(AnalysisDesign.Colors.textPrimary)
                        
                        Text((isEN ? "Global signal: " : "Signal global : ") + mtf.globalSignal.displayName)
                            .font(AnalysisDesign.Typography.bodySmall)
                            .foregroundColor(AnalysisDesign.Colors.textSecondary)
                        
                        Text((isEN ? "Confluence: " : "Confluence : ") + "\(Int(mtf.confluencePercent))%")
                            .font(AnalysisDesign.Typography.bodySmall)
                            .foregroundColor(AnalysisDesign.Colors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 6) Important Info (Collapsible)
    
    private var importantInfoSection: some View {
        CollapsibleSection(
            title: t("importantInfoTitle"),
            icon: "exclamationmark.triangle.fill",
            accentColor: .orange,
            preview: importantInfoPreview
        ) {
            VStack(alignment: .leading, spacing: 10) {
                if let factors = currentAdvice?.negativeFactors, !factors.isEmpty {
                    ForEach(factors.prefix(3), id: \.self) { factor in
                        infoAlert(text: factor, color: .orange)
                    }
                }
                
                // Volatilité (basée sur le momentum)
                if let wt = wtSnapshot {
                    let volatilityHigh = abs(wt.currentMomentum) > 5.0
                    let volLabel = t("currentVolatility")
                    let volValue = volatilityHigh ? t("volatilityHigh") : t("volatilityNormal")
                    infoAlert(
                        text: "\(volLabel) : \(volValue)",
                        color: volatilityHigh ? .red : .green
                    )
                }
            }
        }
    }
    
    private func infoAlert(text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(text)
                .font(AnalysisDesign.Typography.bodySmall)
                .foregroundColor(AnalysisDesign.Colors.textSecondary)
                .lineSpacing(3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AnalysisDesign.Radius.medium)
                .fill(color.opacity(0.08))
        )
    }
    
    // MARK: - Helpers
    
    private func loadAdvice() {
        let advice = AdviceGenerator.generateAdvice(
            disciplineScore: appState.riskScore,
            emotionalLoad: appState.emotionScore,
            trades: appState.trades,
            appState: appState
        )
        currentAdvice = advice
    }
    
    private func loadScenarios() async {
        // Fetch current price
        let price = await TradeScenarioGenerator.getCurrentPrice(for: selectedSymbol.symbol)
            ?? estimateCurrentPrice()
        
        currentPrice = price
        
        // Generate scenarios with current app language
        let lang = LanguageManager.shared.currentLanguage
        let (bull, bear, bullExp, bearExp) = TradeScenarioGenerator.generateScenarios(
            symbol: selectedSymbol.symbol,
            currentPrice: price,
            mtfSnapshot: mtfSnapshot,
            wtSnapshot: wtSnapshot,
            vmcOscSnapshot: vmcOscSnapshot,
            language: lang
        )
        
        await MainActor.run {
            bullScenario = bull
            bearScenario = bear
            bullExplanation = bullExp
            bearExplanation = bearExp
        }
    }
    
    private func estimateCurrentPrice() -> Double {
        // Estimer le prix à partir des données disponibles
        // Pour crypto, on pourrait utiliser le dernier prix connu
        // Pour l'instant, retourner un prix fictif basé sur le symbole
        switch selectedSymbol.symbol {
        case "BTCUSDT":
            return 67000.0
        case "ETHUSDT":
            return 3500.0
        default:
            return 100.0
        }
    }
    
    private var calculatedScore: Int {
        guard let advice = currentAdvice else { return 5 }
        return advice.edgeScore / 10 // Convertir 0-100 en 0-10
    }
    
    private var calculatedBullProbability: Double {
        guard let mtf = mtfSnapshot else { return 0.5 }
        // Calculer la probabilité basée sur le score combiné MTF
        let normalizedScore = (mtf.globalCombinedScore + 100) / 200 // Convertir -100...+100 en 0...1
        return normalizedScore
    }
    
    // Support/Resistance dynamiques
    private var technicalSupport1: String? {
        guard let price = currentPrice else { return nil }
        let support = price * 0.98
        return formatPrice(support)
    }
    
    private var technicalResistance1: String? {
        guard let price = currentPrice else { return nil }
        let resistance = price * 1.02
        return formatPrice(resistance)
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price >= 1000 {
            return String(format: "%.0f", price)
        } else if price >= 1 {
            return String(format: "%.2f", price)
        } else {
            return String(format: "%.4f", price)
        }
    }
    
    private var recommendedRisk: String {
        guard let advice = currentAdvice else { return "1-2%" }
        return advice.edgeScore >= 75 ? "2-3%" : advice.edgeScore >= 50 ? "1-2%" : "0.5-1%"
    }
    
    private var recommendedPositionSize: String {
        guard let advice = currentAdvice else { return "Standard" }
        return advice.edgeScore >= 75 ? "Standard" : advice.edgeScore >= 50 ? "Réduite" : "Minimale"
    }
    
    private var maxLossPerTrade: String {
        // TODO: Calculer dynamiquement basé sur le capital et le risque%
        guard let advice = currentAdvice else { return "$100" }
        let riskPercent = advice.edgeScore >= 75 ? 3.0 : advice.edgeScore >= 50 ? 2.0 : 1.0
        // Exemple avec capital de $5000
        let maxLoss = 5000 * (riskPercent / 100)
        return String(format: "$%.0f", maxLoss)
    }
    
    private var currentSession: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<8: return "Session Asie"
        case 8..<16: return "Session Europe"
        case 16..<24: return "Session US"
        default: return "—"
        }
    }
    
    private var technicalPreview: String {
        var parts: [String] = []
        if let sup = technicalSupport1 {
            parts.append("Support \(sup)")
        }
        if let res = technicalResistance1 {
            parts.append("\(t("resistanceLabel")) \(res)")
        }
        if let mtf = mtfSnapshot {
            parts.append("\(mtf.globalSignal.displayName)")
        }
        return parts.isEmpty ? t("analysisPending") : parts.joined(separator: " • ")
    }
    
    private var importantInfoPreview: String {
        var parts: [String] = []
        if let factors = currentAdvice?.negativeFactors.prefix(2) {
            parts.append(contentsOf: factors)
        }
        return parts.isEmpty ? t("noAlert") : parts.joined(separator: " • ")
    }
}

// MARK: - Preview

#Preview {
    AnalysisContentView(
        selectedSymbol: .btcDefault,
        mtfSnapshot: nil,
        wtSnapshot: nil,
        vmcOscSnapshot: nil,
        lastUpdate: Date()
    )
    .environmentObject(AppState())
}
