//
//  AIAssistant.swift
//  Journal de trading 2025
//

import Foundation
import Combine
import SwiftUI

// MARK: - AI Models

struct AIInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let severity: InsightSeverity
    let category: InsightCategory
}

struct AIRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let priority: RecommendationPriority
    let category: InsightCategory
}

struct AIAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let title: String
    let message: String
    let severity: AIAlertSeverity
    let action: String
    
    // For backward compatibility with description
    var description: String { message }
}

enum InsightType {
    case performance
    case pattern
    case emotional
    case risk
}

enum RecommendationType {
    case performance
    case riskManagement
    case emotional
    case strategy
}

enum AlertType {
    case overTrading
    case emotional
    case performance
    case risk
}

enum InsightSeverity: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum AIAlertSeverity: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum RecommendationPriority: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

enum InsightCategory: String {
    case trading = "trading"
    case performance = "performance"
    case emotional = "emotional"
    case timing = "timing"
    case sizing = "sizing"
}

// MARK: - AI Assistant

@MainActor
class AIAssistant: ObservableObject {
    // Properties
    @Published var insights: [AIInsight] = []
    @Published var recommendations: [AIRecommendation] = []
    @Published var alerts: [AIAlert] = []
    @Published var isAnalyzing = false
    @Published var llmSummaryInsights: String? = nil
    @Published var llmSummaryRecommendations: String? = nil
    
    // Dependencies
    private let tradeStore: any TradeStore
    private let moodStore: any MoodStore
    private let systemStore: any SystemStore
    private var llmClient: OpenAIClient?
    
    init(tradeStore: any TradeStore, moodStore: any MoodStore, systemStore: any SystemStore, llmClient: OpenAIClient?) {
        self.tradeStore = tradeStore
        self.moodStore = moodStore
        self.systemStore = systemStore
        self.llmClient = llmClient
    }
    
    // Analysis methods
    func performFullAnalysis() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Load data
        let trades = try? await tradeStore.fetchAll()
        let moods = moodStore.moods
        let systems = try? await systemStore.fetchAll()
        
        // Generate insights and recommendations
        let genInsights = generateInsights(trades: trades ?? [], moods: moods, systems: systems ?? [])
        let genRecommendations = generateRecommendations(trades: trades ?? [], moods: moods, systems: systems ?? [])
        
        insights = genInsights
        recommendations = genRecommendations
        
        // LLM analysis
        if let llmClient = llmClient {
            let finalTrades = trades ?? []
            
            // Generate LLM summaries for insights
            let summaryForInsights = composeLLMInsightsSummary(
                trading: TradingPatterns(),
                emotional: EmotionalPatterns(),
                contextual: ContextualPerformance(),
                trades: finalTrades
            )
            
            if let insightsLLM = try? await llmClient.analyze(tradingSummary: summaryForInsights) {
                llmSummaryInsights = insightsLLM.summary
            }
            
            // Generate LLM summaries for recommendations
            let summaryForRecommendations = composeLLMRecommendationsSummary(
                trading: TradingPatterns(),
                emotional: EmotionalPatterns(),
                contextual: ContextualPerformance(),
                trades: finalTrades
            )
            
            if let recLLM = try? await llmClient.analyze(tradingSummary: summaryForRecommendations) {
                llmSummaryRecommendations = recLLM.summary
            }
        }
        
        print("✅ [AIAssistant] Analysis complete")
        print("  - Insights count: \(insights.count)")
        print("  - Recommendations count: \(recommendations.count)")
    }
    
    func fetchAndAnalyzeBTCWithLLM() async {
        // Placeholder for BTC analysis
        print("📊 Fetching BTC data and analyzing with LLM")
    }
    
    // Helper methods
    private func generateInsights(trades: [Trade], moods: [MoodEntry], systems: [TradingSystem]) -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Multiple insights
            insights.append(AIInsight(
            type: .performance,
            title: "Analyse des performances",
            description: "Analysez vos trades pour découvrir des patterns et améliorer vos performances.",
            severity: .medium,
            category: .performance
        ))
        
            insights.append(AIInsight(
            type: .pattern,
            title: "Pattern de trading détecté",
            description: "Un pattern récurrent a été identifié dans vos trades récents. Analysez ces opportunités.",
            severity: .high,
            category: .trading
        ))
        
            insights.append(AIInsight(
                type: .emotional,
            title: "Gestion émotionnelle",
            description: "Votre état émotionnel impacte vos décisions. Restez concentré et discipliné.",
                severity: .medium,
                category: .emotional
            ))
        
        insights.append(AIInsight(
            type: .risk,
            title: "Analyse des risques",
            description: "Votre ratio risque/rendement peut être optimisé. Revisitez votre gestion du risque.",
            severity: .medium,
            category: .sizing
        ))
        
        return insights
    }
    
    private func generateRecommendations(trades: [Trade], moods: [MoodEntry], systems: [TradingSystem]) -> [AIRecommendation] {
        var recommendations: [AIRecommendation] = []
        
        // Multiple recommendations
        recommendations.append(AIRecommendation(
            type: .performance,
            title: "Conseil de trading",
            description: "Suivez vos émotions et restez discipliné dans votre trading.",
            priority: .medium,
            category: .emotional
        ))
        
            recommendations.append(AIRecommendation(
            type: .riskManagement,
            title: "Gestion du risque",
            description: "N'engagez jamais plus de 2% de votre capital sur un seul trade.",
                priority: .high,
            category: .sizing
            ))
        
            recommendations.append(AIRecommendation(
            type: .strategy,
            title: "Optimisation de stratégie",
            description: "Votre stratégie montre des faiblesses sur certaines conditions de marché. Adaptez votre approche.",
                priority: .medium,
            category: .trading
            ))
        
            recommendations.append(AIRecommendation(
                type: .emotional,
            title: "Repos recommandé",
            description: "Après une série de pertes, prenez une pause pour récupérer mentalement.",
                priority: .high,
                category: .emotional
            ))
        
        return recommendations
    }
    
    private func composeLLMInsightsSummary(trading: TradingPatterns, emotional: EmotionalPatterns, contextual: ContextualPerformance, trades: [Trade]) -> String {
        var lines: [String] = []
        lines.append("📊 ANALYSE COMPLÈTE DES TRADES")
        lines.append("═══════════════════════════════════")
        lines.append("Total de trades: \(trades.count)")
        
        // Calculate key metrics
        let winCount = trades.filter { $0.pnl > 0 }.count
        let lossCount = trades.filter { $0.pnl < 0 }.count
        let winRate = trades.isEmpty ? 0.0 : Double(winCount) / Double(trades.count) * 100
        
        let totalPnL = trades.reduce(0.0) { $0 + $1.pnl }
        let avgWin = winCount > 0 ? trades.filter { $0.pnl > 0 }.reduce(0.0) { $0 + $1.pnl } / Double(winCount) : 0.0
        let avgLoss = lossCount > 0 ? abs(trades.filter { $0.pnl < 0 }.reduce(0.0) { $0 + $1.pnl } / Double(lossCount)) : 0.0
        
        lines.append("Trades gagnants: \(winCount) (\(String(format: "%.1f", winRate))%)")
        lines.append("Trades perdants: \(lossCount)")
        lines.append("P&L total: \(String(format: "%.2f", totalPnL))$")
        lines.append("Gain moyen: \(String(format: "%.2f", avgWin))$")
        lines.append("Perte moyenne: \(String(format: "%.2f", avgLoss))$")
        
        lines.append("\n🎯 OBJECTIF:")
        lines.append("Identifie et explique les patterns significatifs dans les données de trading. Pour chaque insight:")
        lines.append("1. DÉCRIS le pattern observé avec des chiffres concrets")
        lines.append("2. EXPLIQUE pourquoi c'est important (impact sur la performance)")
        lines.append("3. DONNE le contexte et la signification de ce pattern")
        lines.append("\nUtilise des phrases claires, convaincantes et basées sur les données réelles.")
        
        return lines.joined(separator: "\n")
    }
    
    private func composeLLMRecommendationsSummary(trading: TradingPatterns, emotional: EmotionalPatterns, contextual: ContextualPerformance, trades: [Trade]) -> String {
        var lines: [String] = []
        lines.append("📊 Historique complet des trades:")
        lines.append("Total: \(trades.count) trades")
        
        // Analyze trades data for context
        let winCount = trades.filter { $0.pnl > 0 }.count
        let lossCount = trades.filter { $0.pnl < 0 }.count
        let totalPnL = trades.reduce(0.0) { $0 + $1.pnl }
        
        lines.append("Trades gagnants: \(winCount)")
        lines.append("Trades perdants: \(lossCount)")
        lines.append("P&L total: \(String(format: "%.1f", totalPnL))")
        
        lines.append("\n🎯 Objectif:")
        lines.append("Fournis des recommandations basées sur cet historique. Pour chaque recommandation:")
        lines.append("1. EXPLIQUE le problème identifié avec des données concrètes")
        lines.append("2. POURQUOI c'est important de corriger (impact sur la performance)")
        lines.append("3. POURQUOI c'est pertinent selon l'historique")
        lines.append("Utilise des phrases claires et engageantes.")
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - Helper Structures

struct TradingPatterns { }
struct EmotionalPatterns { }
struct ContextualPerformance { }
