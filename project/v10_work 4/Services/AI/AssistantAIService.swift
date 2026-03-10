import Foundation

final class AssistantAIService {
    private let calendar: Calendar
    
    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }
    
    func makeDailyReport(
        trades: [Trade],
        moods: [MoodEntry],
        coachState: CoachIAState,
        emotionAnalysis: EmotionPerformanceAnalysis,
        language: Localizable.Language = .french
    ) -> AssistantAIReport {
        let indicators = generateIndicatorSnapshots(trades: trades)
        let fundingRate = computeFundingRate(for: trades)
        let confluence = computeConfluence(from: indicators, language: language)
        let recommendationBundle = generateRecommendations(
            indicators: indicators,
            coachState: coachState,
            emotionAnalysis: emotionAnalysis,
            fundingRate: fundingRate,
            marketConfluence: confluence,
            language: language
        )
        
        let headline = buildHeadline(
            trades: trades,
            coachState: coachState,
            emotionAnalysis: emotionAnalysis,
            recommendation: recommendationBundle.trend,
            language: language
        )
        
        let sections = buildSections(
            trades: trades,
            moods: moods,
            coachState: coachState,
            emotionAnalysis: emotionAnalysis,
            recommendationBundle: recommendationBundle,
            indicators: indicators,
            fundingRate: fundingRate,
            language: language
        )
        
        return AssistantAIReport(
            generatedAt: Date(),
            sections: sections,
            summaryHeadline: headline,
            trendRecommendation: recommendationBundle.trend,
            marketConfluence: confluence,
            fundingRate: fundingRate,
            technicalSummary: recommendationBundle.technicalSummary,
            riskScore: recommendationBundle.riskScore,
            emotionScore: recommendationBundle.emotionScore,
            recommendations: recommendationBundle.actionables,
            indicatorSnapshots: indicators
        )
    }
    
    private func buildHeadline(
        trades: [Trade],
        coachState: CoachIAState,
        emotionAnalysis: EmotionPerformanceAnalysis,
        recommendation: String,
        language: Localizable.Language = .french
    ) -> String {
        let winRate = computeWinRate(for: trades)
        if trades.isEmpty {
            return language == .french
                ? "Aucun trade récent — concentre-toi sur l’observation et la préparation."
                : "No recent trades — focus on observation and preparation."
        }
        let discipline = coachState.disciplineScore.value
        let impact = emotionAnalysis.impactPercentage
        return language == .french
            ? "WinRate \(Int(winRate * 100))%, discipline \(discipline)/100, impact émotionnel \(impact)% · \(recommendation)"
            : "WinRate \(Int(winRate * 100))%, discipline \(discipline)/100, emotional impact \(impact)% · \(recommendation)"
    }
    
    private func buildSections(
        trades: [Trade],
        moods: [MoodEntry],
        coachState: CoachIAState,
        emotionAnalysis: EmotionPerformanceAnalysis,
        recommendationBundle: RecommendationBundle,
        indicators: [AssistantAIIndicatorSnapshot],
        fundingRate: Double,
        language: Localizable.Language = .french
    ) -> [AssistantAISection] {
        var sections: [AssistantAISection] = []
        sections.append(summarySection(trades: trades, coachState: coachState, recommendation: recommendationBundle, language: language))
        sections.append(marketSection(
            trades: trades,
            recommendationBundle: recommendationBundle,
            fundingRate: fundingRate,
            language: language
        ))
        sections.append(disciplineSection(coachState: coachState, recommendationBundle: recommendationBundle, language: language))
        sections.append(emotionSection(
            emotionAnalysis: emotionAnalysis,
            coachState: coachState,
            moods: moods,
            recommendationBundle: recommendationBundle,
            language: language
        ))
        sections.append(performanceSection(trades: trades, indicators: indicators, recommendationBundle: recommendationBundle, language: language))
        if let photoSection = photoSection(language: language) {
            sections.append(photoSection)
        }
        return sections
    }
    
    private func summarySection(trades: [Trade], coachState: CoachIAState, recommendation: RecommendationBundle, language: Localizable.Language = .french) -> AssistantAISection {
        let winRate = computeWinRate(for: trades)
        let totalPnL = trades.reduce(0) { $0 + $1.pnl }
        let recentTrades = recentTradesDescription(trades: trades, language: language)
        let body: String
        if language == .french {
            body = """
Aujourd’hui : \(Int(winRate * 100))% de réussite et un P&L de \(formatCurrency(totalPnL)).
\(recentTrades)
Ton Coach IA note un score de discipline à \(coachState.disciplineScore.value) et un objectif : \(coachState.weeklyGoal.title).
\(recommendation.trend)
"""
        } else {
            body = """
Today: \(Int(winRate * 100))% win rate and a P&L of \(formatCurrency(totalPnL)).
\(recentTrades)
Your AI Coach notes a discipline score of \(coachState.disciplineScore.value) and a goal: \(coachState.weeklyGoal.title).
\(recommendation.trend)
"""
        }
        return AssistantAISection(
            type: .summary,
            title: language == .french ? "Résumé du jour" : "Daily Summary",
            icon: "sparkles",
            message: body,
            accentColorHex: "#0A85FF"
        )
    }
    
    private func marketSection(
        trades: [Trade],
        recommendationBundle: RecommendationBundle,
        fundingRate: Double,
        language: Localizable.Language = .french
    ) -> AssistantAISection {
        let calendar = Calendar.current
        let dayTrades = trades.filter { calendar.isDate($0.date, inSameDayAs: Date()) }
        let activity: String
        let fundingText: String
        if language == .french {
            activity = dayTrades.isEmpty ? "Aucun trade saisi aujourd’hui." : "\(dayTrades.count) trades aujourd’hui."
            fundingText = String(format: "Funding rate actuel : %.3f%%", fundingRate * 100)
        } else {
            activity = dayTrades.isEmpty ? "No trades entered today." : "\(dayTrades.count) trades today."
            fundingText = String(format: "Current funding rate: %.3f%%", fundingRate * 100)
        }
        let message = """
\(recommendationBundle.marketConfluence)
\(fundingText)
\(recommendationBundle.trend)
\(activity)
"""
        return AssistantAISection(
            type: .market,
            title: language == .french ? "Analyse Marché" : "Market Analysis",
            icon: "chart.line.uptrend.xyaxis",
            message: message,
            accentColorHex: "#34C759"
        )
    }
    
    private func disciplineSection(coachState: CoachIAState, recommendationBundle: RecommendationBundle, language: Localizable.Language = .french) -> AssistantAISection {
        let trendText: String
        if language == .french {
            if coachState.disciplineScore.trend > 0 {
                trendText = "Progression de +\(coachState.disciplineScore.trend) points cette semaine."
            } else if coachState.disciplineScore.trend < 0 {
                trendText = "Baisse de \(abs(coachState.disciplineScore.trend)) points, recentre-toi sur ton plan."
            } else {
                trendText = "Score stable, continue ta routine."
            }
        } else {
            if coachState.disciplineScore.trend > 0 {
                trendText = "Progress of +\(coachState.disciplineScore.trend) points this week."
            } else if coachState.disciplineScore.trend < 0 {
                trendText = "Down \(abs(coachState.disciplineScore.trend)) points, refocus on your plan."
            } else {
                trendText = "Stable score, keep your routine."
            }
        }
        let message: String
        if language == .french {
            message = """
\(coachState.message.body)
Score actuel : \(coachState.disciplineScore.value)/100 — \(trendText)
Objectif hebdo : \(coachState.weeklyGoal.title)
Recommandation IA : \(recommendationBundle.actionables.first ?? recommendationBundle.trend)
"""
        } else {
            message = """
\(coachState.message.body)
Current score: \(coachState.disciplineScore.value)/100 — \(trendText)
Weekly goal: \(coachState.weeklyGoal.title)
AI recommendation: \(recommendationBundle.actionables.first ?? recommendationBundle.trend)
"""
        }
        return AssistantAISection(
            type: .discipline,
            title: "Discipline & Coaching",
            icon: "target",
            message: message,
            accentColorHex: "#FFAF38"
        )
    }
    
    private func emotionSection(
        emotionAnalysis: EmotionPerformanceAnalysis,
        coachState: CoachIAState,
        moods: [MoodEntry],
        recommendationBundle: RecommendationBundle,
        language: Localizable.Language = .french
    ) -> AssistantAISection {
        let insight = emotionAnalysis.isEmpty
            ? (language == .french
                ? "Pas encore assez de données émotionnelles pour détecter un schéma. Note tes ressentis au moins 5 jours consécutifs."
                : "Not enough emotional data yet to detect a pattern. Record your feelings for at least 5 consecutive days.")
            : emotionAnalysis.interpretation
        
        let dominantEmotion = moods
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first?.emotionalState.displayName ?? (language == .french ? "non définie" : "undefined")
        
        let message: String
        if language == .french {
            message = """
\(insight)
Émotion dominante récente : \(dominantEmotion).
Conseil IA : \(recommendationBundle.emotionAdvice)
"""
        } else {
            message = """
\(insight)
Recent dominant emotion: \(dominantEmotion).
AI advice: \(recommendationBundle.emotionAdvice)
"""
        }
        return AssistantAISection(
            type: .emotion,
            title: language == .french ? "Émotion & Mental" : "Emotion & Mindset",
            icon: "brain.head.profile",
            message: message,
            accentColorHex: "#BF5AF2"
        )
    }
    
    private func performanceSection(
        trades: [Trade],
        indicators: [AssistantAIIndicatorSnapshot],
        recommendationBundle: RecommendationBundle,
        language: Localizable.Language = .french
    ) -> AssistantAISection {
        guard !trades.isEmpty else {
            return AssistantAISection(
                type: .performance,
                title: language == .french ? "Performance & Risque" : "Performance & Risk",
                icon: "chart.bar.doc.horizontal",
                message: language == .french
                    ? "Aucun trade pour générer des statistiques. Analyse tes setups avant de retourner sur le marché."
                    : "No trades to generate statistics. Analyze your setups before returning to the market.",
                accentColorHex: "#64D2FF"
            )
        }
        let sorted = trades.sorted(by: { $0.pnl > $1.pnl })
        let best = sorted.first
        let worst = sorted.last
        let averagePnL = trades.reduce(0) { $0 + $1.pnl } / Double(trades.count)
        var lines: [String] = []
        if let best {
            lines.append(language == .french
                ? "Meilleur trade: \(best.symbol) (\(formatCurrency(best.pnl)))"
                : "Best trade: \(best.symbol) (\(formatCurrency(best.pnl)))")
        }
        if let worst, worst.id != best?.id {
            lines.append(language == .french
                ? "Trade à surveiller: \(worst.symbol) (\(formatCurrency(worst.pnl)))"
                : "Trade to watch: \(worst.symbol) (\(formatCurrency(worst.pnl)))")
        }
        lines.append(language == .french
            ? "PnL moyen par trade: \(formatCurrency(averagePnL))"
            : "Average PnL per trade: \(formatCurrency(averagePnL))")
        return AssistantAISection(
            type: .performance,
            title: language == .french ? "Performance & Risque" : "Performance & Risk",
            icon: "chart.bar.doc.horizontal",
            message: lines.joined(separator: "\n"),
            accentColorHex: "#64D2FF"
        )
    }
    
    private func photoSection(language: Localizable.Language = .french) -> AssistantAISection? {
        AssistantAISection(
            type: .photo,
            title: language == .french ? "Analyse photo" : "Photo Analysis",
            icon: "camera.viewfinder",
            message: language == .french
                ? "Analyse tes captures d’écran de graphiques pour détecter les patterns automatiquement. Importer une image pour lancer l’analyse IA."
                : "Analyze your chart screenshots to automatically detect patterns. Import an image to start the AI analysis.",
            accentColorHex: "#FF9F0A"
        )
    }
    
    private func generateIndicatorSnapshots(trades: [Trade]) -> [AssistantAIIndicatorSnapshot] {
        let timeframes = ["M15", "H1", "H4", "Daily"]
        let basePnL = trades.reduce(0) { $0 + $1.pnl }
        return timeframes.map { timeframe in
            let noise = Double.random(in: -8...8)
            let rsi = max(20, min(80, Int(50 + Double(basePnL).sign() * 5 + noise)))
            let macd = Double.random(in: -1.5...1.5) + Double(basePnL).sign() * 0.3
            let trix = Double.random(in: -2.0...2.0) + Double(basePnL).sign() * 0.4
            let vmc = Double.random(in: -1.0...1.0)
            let odp = Double.random(in: -0.8...0.8)
            let bias: AssistantTrendBias
            if rsi >= 58 && macd > 0.2 {
                bias = .bullish
            } else if rsi <= 42 && macd < -0.2 {
                bias = .bearish
            } else {
                bias = .neutral
            }
            return AssistantAIIndicatorSnapshot(
                timeframe: timeframe,
                rsi: rsi,
                macd: macd,
                trix: trix,
                vmc: vmc,
                odp: odp,
                bias: bias
            )
        }
    }
    
    private func computeConfluence(from indicators: [AssistantAIIndicatorSnapshot], language: Localizable.Language = .french) -> String {
        let bullishIndicators = indicators.filter { $0.bias == .bullish }
        let bearishIndicators = indicators.filter { $0.bias == .bearish }
        let bullish = bullishIndicators.count
        let bearish = bearishIndicators.count
        
        if bullish >= 2 && bullish > bearish {
            let timeframes = bullishIndicators.map { $0.timeframe }.joined(separator: ", ")
            return language == .french
                ? "Confluence haussière détectée sur \(timeframes)."
                : "Bullish confluence detected on \(timeframes)."
        } else if bearish >= 2 && bearish > bullish {
            let timeframes = bearishIndicators.map { $0.timeframe }.joined(separator: ", ")
            return language == .french
                ? "Confluence baissière détectée sur \(timeframes)."
                : "Bearish confluence detected on \(timeframes)."
        } else {
            return language == .french
                ? "Confluence neutre : surveille les cassures clés."
                : "Neutral confluence: watch for key breakouts."
        }
    }
    
    private func computeFundingRate(for trades: [Trade]) -> Double {
        let base = Double.random(in: -0.03...0.03)
        let pnlImpact = trades.reduce(0) { $0 + $1.pnl }
        return max(-0.05, min(0.05, base + Double(pnlImpact).sign() * 0.005))
    }
    
    private func generateRecommendations(
        indicators: [AssistantAIIndicatorSnapshot],
        coachState: CoachIAState,
        emotionAnalysis: EmotionPerformanceAnalysis,
        fundingRate: Double,
        marketConfluence: String,
        language: Localizable.Language = .french
    ) -> RecommendationBundle {
        let bullish = indicators.filter { $0.bias == .bullish }.count
        let bearish = indicators.filter { $0.bias == .bearish }.count
        let dominantBias: AssistantTrendBias
        if bullish > bearish {
            dominantBias = .bullish
        } else if bearish > bullish {
            dominantBias = .bearish
        } else {
            dominantBias = .neutral
        }
        
        let trend: String
        switch dominantBias {
        case .bullish:
            trend = "Confluence haussière détectée — envisage des entrées longues en respectant tes critères."
        case .bearish:
            trend = "Confluence baissière détectée — privilégie les ventes ou reste en observation."
        case .neutral:
            trend = "Pas de confluence nette — attends une confirmation technique avant d’agir."
        }
        
        let riskScore = max(10, min(95, (coachState.disciplineScore.value + 2 * (100 - coachState.disciplineScore.value) / 3) - emotionAnalysis.impactPercentage / 2))
        let emotionScore = max(10, min(95, coachState.disciplineScore.value - emotionAnalysis.impactPercentage / 3 + 50))
        
        var actionables: [String] = []
        if fundingRate > 0.01 {
            actionables.append("Funding positif : attention au coût des positions longues.")
        } else if fundingRate < -0.01 {
            actionables.append("Funding négatif : avantage tactique pour les positions longues.")
        }
        if coachState.disciplineScore.value < 55 {
            actionables.append("Stabilise ton plan avant d’augmenter la taille de position.")
        } else {
            actionables.append("Discipline solide, poursuis ta routine actuelle.")
        }
        if emotionAnalysis.impactPercentage > 20 {
            actionables.append("Impact émotionnel élevé — impose-toi une pause ou diminue le levier.")
        } else {
            actionables.append("Émotions maîtrisées, profite-en pour exécuter ton setup clé.")
        }
        
        // Générer un résumé technique basé sur les indicateurs du tableau
        let technicalSummary: String = generateTechnicalSummaryFromIndicators(indicators: indicators, dominantBias: dominantBias, bullish: bullish, bearish: bearish)
        
        let emotionAdvice: String = {
            if emotionAnalysis.impactPercentage > 20 {
                return language == .french
                    ? "Réduis ton exposition et note tes sensations avant le prochain trade."
                    : "Reduce your exposure and note your feelings before the next trade."
            }
            if coachState.disciplineScore.trend < 0 {
                return language == .french
                    ? "Reviens à ton checklist avant entrée pour éviter la dérive émotionnelle."
                    : "Return to your entry checklist to avoid emotional drift."
            }
            return language == .french
                ? "Ton mental est aligné avec ton plan : conserve ton rituel pré-trade."
                : "Your mindset is aligned with your plan: maintain your pre-trade ritual."
        }()
        
        return RecommendationBundle(
            trend: trend,
            marketConfluence: marketConfluence,
            technicalSummary: technicalSummary,
            riskScore: riskScore,
            emotionScore: emotionScore,
            emotionAdvice: emotionAdvice,
            actionables: actionables
        )
    }
    
    private func computeWinRate(for trades: [Trade]) -> Double {
        guard !trades.isEmpty else { return 0 }
        let wins = trades.filter { $0.pnl > 0 }.count
        return Double(wins) / Double(trades.count)
    }
    
    private func recentTradesDescription(trades: [Trade], language: Localizable.Language = .french) -> String {
        let calendar = Calendar.current
        let todayTrades = trades.filter { calendar.isDate($0.date, inSameDayAs: Date()) }
        if todayTrades.isEmpty {
            return language == .english
                ? "No trades executed today."
                : "Aucun trade exécuté aujourd'hui."
        }
        let wins = todayTrades.filter { $0.pnl > 0 }.count
        return language == .english
            ? "\(todayTrades.count) trades today, including \(wins) winner(s)."
            : "\(todayTrades.count) trades aujourd'hui, dont \(wins) gagnant(s)."
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f$", value)
    }
    
    private func generateTechnicalSummaryFromIndicators(
        indicators: [AssistantAIIndicatorSnapshot],
        dominantBias: AssistantTrendBias,
        bullish: Int,
        bearish: Int
    ) -> String {
        guard !indicators.isEmpty else {
            return "Données insuffisantes pour l'analyse technique."
        }
        
        // Identifier les timeframes avec momentum haussier/baissier
        let bullishTimeframes = indicators.filter { $0.bias == .bullish }.map { $0.timeframe }
        let bearishTimeframes = indicators.filter { $0.bias == .bearish }.map { $0.timeframe }
        let neutralTimeframes = indicators.filter { $0.bias == .neutral }.map { $0.timeframe }
        
        var summary = ""
        
        // Analyser RSI
        let rsiValues = indicators.compactMap { ind -> (timeframe: String, rsi: Int)? in
            guard ind.rsi > 0 else { return nil }
            return (ind.timeframe, ind.rsi)
        }
        
        if !rsiValues.isEmpty {
            let overbought = rsiValues.filter { $0.rsi > 70 }
            let oversold = rsiValues.filter { $0.rsi < 30 }
            let neutralRSI = rsiValues.filter { $0.rsi >= 30 && $0.rsi <= 70 }
            
            if !overbought.isEmpty {
                summary += "RSI en surachat sur \(overbought.map { $0.timeframe }.joined(separator: ", ")). "
            }
            if !oversold.isEmpty {
                summary += "RSI en survente sur \(oversold.map { $0.timeframe }.joined(separator: ", ")). "
            }
            if !neutralRSI.isEmpty && overbought.isEmpty && oversold.isEmpty {
                summary += "RSI neutre sur tous les timeframes. "
            }
        }
        
        // Analyser MACD
        let macdValues = indicators.compactMap { ind -> (timeframe: String, macd: Double)? in
            guard ind.macd != 0 else { return nil }
            return (ind.timeframe, ind.macd)
        }
        
        if !macdValues.isEmpty {
            let positiveMACD = macdValues.filter { $0.macd > 0 }
            let negativeMACD = macdValues.filter { $0.macd < 0 }
            
            if positiveMACD.count > negativeMACD.count {
                summary += "MACD positif sur \(positiveMACD.map { $0.timeframe }.joined(separator: ", ")). "
            } else if negativeMACD.count > positiveMACD.count {
                summary += "MACD négatif sur \(negativeMACD.map { $0.timeframe }.joined(separator: ", ")). "
            }
        }
        
        // Analyser VMC
        let vmcValues = indicators.compactMap { ind -> (timeframe: String, vmc: Double)? in
            guard ind.vmc != 0 else { return nil }
            return (ind.timeframe, ind.vmc)
        }
        
        if !vmcValues.isEmpty {
            let positiveVMC = vmcValues.filter { $0.vmc > 0 }
            if positiveVMC.count >= 2 {
                summary += "VMC haussier sur \(positiveVMC.map { $0.timeframe }.joined(separator: ", ")). "
            }
        }
        
        // Synthèse du momentum
        if !bullishTimeframes.isEmpty || !bearishTimeframes.isEmpty {
            if dominantBias == .bullish {
                summary += "Momentum haussier confirmé sur \(bullishTimeframes.joined(separator: ", ")). "
                if bullishTimeframes.count >= 3 {
                    summary += "Confluence forte : privilégie les entrées longues sur replis vers supports."
                } else {
                    summary += "Confluence modérée : surveille les confirmations avant d'entrer."
                }
            } else if dominantBias == .bearish {
                summary += "Momentum baissier confirmé sur \(bearishTimeframes.joined(separator: ", ")). "
                if bearishTimeframes.count >= 3 {
                    summary += "Confluence forte : évite les positions longues, surveille les cassures."
                } else {
                    summary += "Confluence modérée : reste prudent et attends confirmation."
                }
            } else {
                summary += "Momentum mixte : \(bullishTimeframes.isEmpty ? "" : "haussier sur \(bullishTimeframes.joined(separator: ", "))")\(bullishTimeframes.isEmpty || bearishTimeframes.isEmpty ? "" : ", ")\(bearishTimeframes.isEmpty ? "" : "baissier sur \(bearishTimeframes.joined(separator: ", "))"). "
                summary += "Attends une convergence claire avant d'agir."
            }
        } else if !neutralTimeframes.isEmpty {
            summary += "Momentum neutre sur tous les timeframes. Place des alertes sur les niveaux clés."
        }
        
        return summary.isEmpty ? "Analyse des indicateurs en cours..." : summary
    }
    
    // MARK: - GPT Analysis via Firebase
// MARK: - GPT Analysis via Firebase (nouveau prompt)

/// Génère l'analyse complète via GPT-4o avec le prompt structuré premium
func generateGPTAnalysis(
    symbol: String,
    symbolType: String, // "crypto", "action", "forex"
    currentPrice: Double,
    mtfSnapshot: MTFSnapshot?,
    wtSnapshot: WTSnapshot?,
    vmcOscSnapshot: VMCOscillatorSnapshot?,
    liquidityZones: [(price: Double, volume: Double, side: String)]?,
    economicRiskAnalysis: MarketRiskAnalysis?,
    fundingRate: Double,
    language: Localizable.Language = LanguageManager.shared.currentLanguage
) async throws -> String {
    
    let isEN = language == .english
    
    // Construire le contexte technique disponible
    var contextLines: [String] = []
    contextLines.append(isEN ? "Asset analyzed: \(symbol)" : "Actif analysé : \(symbol)")
    contextLines.append(isEN ? "Type: \(symbolType)" : "Type : \(symbolType)")
    if currentPrice > 0 {
        let priceStr = currentPrice >= 1000
            ? String(format: "%.2f", currentPrice)
            : currentPrice >= 1
                ? String(format: "%.4f", currentPrice)
                : String(format: "%.6f", currentPrice)
        contextLines.append(isEN
            ? "⚠️ REAL CURRENT PRICE (required for levels): \(priceStr) USDT"
            : "⚠️ PRIX ACTUEL RÉEL (obligatoire pour les niveaux) : \(priceStr) USDT")
        contextLines.append(isEN
            ? "All levels (entry, stop, TP) must be consistent with this price."
            : "Tous les niveaux (entrée, stop, TP) doivent être cohérents avec ce prix.")
    }
    
    if let mtf = mtfSnapshot {
        contextLines.append("Signal MTF global : \(mtf.globalSignal.displayName)")
        contextLines.append("Score MTF : \(Int(mtf.globalCombinedScore))")
        contextLines.append("Confluence MTF : \(Int(mtf.confluencePercent))%")
        contextLines.append("")
        contextLines.append("Données techniques par unité de temps (utilise ces données pour adapter chaque plan de trade) :")
        
        let tfOrder: [VMCTimeframe] = [.m15, .h1, .h4, .d1]
        for tf in tfOrder {
            guard let reading = mtf.readings[tf] else { continue }
            var line = "  \(tf.displayName) — RSI: \(String(format: "%.1f", reading.rsiValue))"
            line += ", VMC: \(String(format: "%.1f", reading.vmcValue))"
            line += ", Signal: \(reading.combinedSignal.displayName)"
            if reading.isRSIOversold  { line += isEN ? ", RSI OVERSOLD"   : ", RSI SURVENDU" }
            if reading.isRSIOverbought { line += isEN ? ", RSI OVERBOUGHT" : ", RSI SURACHETÉ" }
            if reading.hasDivergence  { line += isEN ? ", DIVERGENCE"     : ", DIVERGENCE" }
            contextLines.append(line)
        }
        contextLines.append("")
    }
    
    if let wt = wtSnapshot {
        contextLines.append("")
        contextLines.append(isEN ? "=== WAVE TREND ===" : "=== WAVE TREND ===")
        contextLines.append("WT1: \(String(format: "%.1f", wt.currentWT1)), WT2: \(String(format: "%.1f", wt.currentWT2))")
        contextLines.append(isEN ? "Bias : \(wt.currentMarketBias.displayName)"    : "Biais : \(wt.currentMarketBias.displayName)")
        contextLines.append(isEN ? "Momentum : \(wt.momentumDirection.displayName) (\(String(format: "%.1f", wt.currentMomentum)))" : "Momentum : \(wt.momentumDirection.displayName) (\(String(format: "%.1f", wt.currentMomentum)))")
        if wt.isOverbought { contextLines.append(isEN ? "⚠️ WAVE TREND OVERBOUGHT" : "⚠️ WAVE TREND EN SURACHAT") }
        if wt.isOversold   { contextLines.append(isEN ? "⚠️ WAVE TREND OVERSOLD"   : "⚠️ WAVE TREND EN SURVENTE") }
        if let signal = wt.currentSignal {
            contextLines.append(isEN ? "WT Signal : \(signal.displayName)" : "Signal WT : \(signal.displayName)")
        }
        // Détecter cross
        let histogram = wt.currentWT1 - wt.currentWT2
        if histogram > 0 && histogram < 3 {
            contextLines.append("Cross haussier récent WT1 > WT2")
        } else if histogram < 0 && histogram > -3 {
            contextLines.append("Cross baissier récent WT1 < WT2")
        }
    }
    
    if let vmc = vmcOscSnapshot {
        contextLines.append("")
        contextLines.append("=== VMC OSCILLATOR ===")
        contextLines.append("Sig: \(String(format: "%.1f", vmc.currentSig)), Signal: \(String(format: "%.1f", vmc.currentSigSignal))")
        contextLines.append("Momentum VMC: \(String(format: "%.1f", vmc.currentMomentum))")
        if vmc.isOverbought { contextLines.append("⚠️ VMC EN SURACHAT") }
        if vmc.isOversold { contextLines.append("⚠️ VMC EN SURVENTE") }
        if let signal = vmc.currentSignal {
            contextLines.append("Signal VMC : \(signal.rawValue)")
        }
        if vmc.ribbonBull { contextLines.append("Ribbon VMC : BULL") }
        if vmc.ribbonBear { contextLines.append("Ribbon VMC : BEAR") }
        if vmc.compression { contextLines.append("VMC en compression → breakout imminent") }
        // Détecter cross VMC
        let vmcDiff = vmc.currentSig - vmc.currentSigSignal
        if vmcDiff > 0 && vmcDiff < 5 {
            contextLines.append("Cross haussier VMC (sig > sigSignal)")
        } else if vmcDiff < 0 && vmcDiff > -5 {
            contextLines.append("Cross baissier VMC (sig < sigSignal)")
        }
    }
    
    if let zones = liquidityZones, !zones.isEmpty {
        contextLines.append("")
        contextLines.append("=== ZONES DE LIQUIDITÉ (Heatmap) ===")
        contextLines.append("IMPORTANT : ces zones sont des MAGNETS pour le prix. Le prix a tendance à être attiré vers les plus grosses poches de liquidation.")
        contextLines.append("Utilise ces niveaux pour positionner les TP et anticiper les mouvements.")
        for zone in zones.prefix(8) {
            let volStr = zone.volume >= 1_000_000
                ? String(format: "%.1fM", zone.volume / 1_000_000)
                : String(format: "%.0fK", zone.volume / 1_000)
            contextLines.append("  \(zone.side) : \(String(format: "%.0f", zone.price)) USDT — Volume: \(volStr)")
        }
    }
    
    if fundingRate != 0 {
        contextLines.append(String(format: "Funding Rate : %.3f%%", fundingRate * 100))
    }
    
    if let eco = economicRiskAnalysis {
        contextLines.append("Risque macro : \(eco.riskLevel.displayName)")
        contextLines.append("Sentiment macro : \(eco.marketSentiment.displayName)")
        let criticalEvents = eco.events.filter {
            ($0.category ?? .other) == .interestRate ||
            ($0.category ?? .other) == .inflation ||
            ($0.category ?? .other) == .employment
        }
        if !criticalEvents.isEmpty {
            let names = criticalEvents.prefix(3).map { $0.name }.joined(separator: ", ")
            contextLines.append("Événements macro : \(names)")
        }
    }
    
    let context = contextLines.joined(separator: "\n")
    
    let systemPrompt = """
Tu es un moteur d'analyse de trading institutionnel intégré dans une application de trading premium.
Tu reçois les données indicateurs (WaveTrend, VMC), les données de liquidité (heatmap) et la structure multi-timeframe.
Ta mission : produire un plan de trade RÉALISTE et EXPLOITABLE basé sur la logique institutionnelle.
Tu dois raisonner comme un desk de trading professionnel.

==============================
HIÉRARCHIE DES TIMEFRAMES
==============================

Chaque timeframe correspond à un contexte DIFFÉRENT. Tu dois produire une analyse UNIQUE par UT.
Ne génère JAMAIS le même type de setup pour toutes les UT.
Les niveaux (entrée, stop, TP) doivent être DIFFÉRENTS entre chaque UT.

TYPE DE SETUP OBLIGATOIRE PAR TIMEFRAME :

M15 (scalping, micro-structure) :
  → Pullback court OU liquidity sweep
  → Amplitude TP : 0.1-0.5% du prix
  → Stop : 0.1-0.3% du prix
  → R:R minimum 1.5:1
  → Analyser les dernières bougies, FVG intraday, micro order blocks

H1 (intraday) :
  → Continuation intraday OU retest de structure
  → Amplitude TP : 0.5-1.5% du prix
  → Stop : 0.3-0.7% du prix
  → R:R minimum 2:1
  → Analyser la session en cours, les swings intraday, les zones de demand/supply

H4 (swing) :
  → Breakout majeur OU reversal de structure
  → Amplitude TP : 2-5% du prix
  → Stop : 1-2% du prix
  → R:R minimum 2.5:1
  → Analyser les BOS/MSS récents, les order blocks H4/Daily, les liquidity pools

Daily (macro) :
  → Biais macro et zones institutionnelles
  → Amplitude TP : 5-15% du prix
  → Stop : 2-5% du prix
  → R:R minimum 3:1
  → Analyser la tendance dominante, les zones weekly, les equal highs/lows

Si la structure est identique sur plusieurs UT, ADAPTER le setup à la logique de la timeframe.
Exemple : même tendance haussière → M15 = pullback sur micro OB, H1 = retest de BOS, H4 = breakout de range, Daily = continuation de swing.

==============================
SMART MONEY ANALYSIS
==============================

Pour CHAQUE timeframe, identifier :
- HH / HL (haussier) ou LH / LL (baissier)
- Break of Structure (BOS) récent — direction et niveau
- Market Structure Shift (MSS) potentiel
- Order Blocks (OB) — zones de forte activité institutionnelle
- Fair Value Gaps (FVG) — gaps non comblés
- Liquidity sweeps récents (stops chassés → retournement)
- Equal Highs / Equal Lows (pools de liquidité = magnets)

Identifier les zones où les stops du marché sont probablement placés.

==============================
INDICATEURS (CONFIRMATION)
==============================

Les indicateurs servent à CONFIRMER ou INVALIDER la structure. Pas à générer le setup.

WaveTrend (WT) :
- Croisement WT1/WT2 : direction et timing
- Zones extrêmes : surachat (>60) / survente (<-60)
- Cross en zone extrême = signal PREMIUM de retournement
- Momentum et accélération de WT1
- Divergence WT vs prix = retournement probable

VMC Oscillator :
- Direction du momentum (sig vs sigSignal)
- Cross sig/sigSignal récent → changement de biais
- Compression = expansion de volatilité imminente → breakout
- Ribbon bull/bear = biais directionnel
- Divergence VMC vs prix = affaiblissement de tendance

==============================
LIQUIDITÉ — HEATMAP (CRYPTO UNIQUEMENT)
==============================

Si des zones de liquidité sont fournies, les utiliser pour :
1. OBJECTIFS (TP) → viser les clusters de liquidation en priorité
2. STOPS → placer HORS des zones de liquidité (éviter stop hunts)
3. PROBABILITÉ DE SWEEP → si gros cluster proche du prix, le sweep est probable

Ordre de priorité pour les TP :
1. Clusters de liquidation (magnets naturels)
2. Equal Highs / Equal Lows (pools)
3. Résistances / Supports structurels
4. Extensions de structure

Ne place JAMAIS de TP arbitraire. Chaque TP doit avoir une justification structurelle ou de liquidité.

==============================
STRICT RESPONSE ORDER (use English labels if responding in English, French labels if responding in French)
==============================

1️⃣ AI GLOBAL SCORE / SCORE IA GLOBAL
2️⃣ SCENARIO PROBABILITY / PROBABILITÉ DES SCÉNARIOS
3️⃣ TRADE PLAN / PLAN DE TRADE (4 timeframes)
4️⃣ RISK MANAGEMENT / GESTION DU RISQUE
5️⃣ TIMING & MARKET CONTEXT / TIMING & CONTEXTE MARCHÉ
6️⃣ TECHNICAL ANALYSIS / ANALYSE TECHNIQUE
7️⃣ IMPORTANT INFORMATION / INFORMATIONS IMPORTANTES
8️⃣ FUNDAMENTAL ANALYSIS / ANALYSE FONDAMENTALE (stocks only)
9️⃣ SCORE EXPLANATION / EXPLICATION DU SCORE

---------------------------------------------------
1️⃣ AI SCORE / SCORE IA
---------------------------------------------------

AI SCORE: X.X / 10
Level: (Low / Neutral / Solid / High probability)
UI Color: (Red / Orange / Light green / Dark green)
Dominant bias: (Bullish / Bearish / Neutral)

Detailed sub-score:
- Structure: X/3
- WaveTrend: X/2
- VMC: X/2
- Liquidity: X/2
- Momentum: X/1

Scale: 0-3=Red(Low) 4-6=Orange(Neutral) 7-8=Light green(Solid) 9-10=Dark green(High probability)

---------------------------------------------------
2️⃣ SCENARIO PROBABILITY / PROBABILITÉ
---------------------------------------------------

Bullish probability: XX %
Bearish probability: XX %

---------------------------------------------------
3️⃣ TRADE PLAN / PLAN DE TRADE
---------------------------------------------------

MANDATORY CHECK BEFORE EACH TF:
☑ Is the setup type DIFFERENT from the previous TF?
☑ Are entry levels DIFFERENT from the previous TF?
☑ Is TP amplitude PROPORTIONAL to the timeframe?
☑ Does the stop correspond to a STRUCTURAL invalidation of this TF?
☑ Do TPs target liquidity zones or structural levels?

⏱️ TIMEFRAME M15
Structure M15: (HH/HL or LH/LL, latest BOS/MSS, micro OB, FVG)
🟢 BULLISH SCENARIO M15
Entry type:
Entry:
Stop:
TP1:
TP2:
TP3:
RR TP1:
RR TP2:

🔴 BEARISH SCENARIO M15
Entry type:
Entry:
Stop:
TP1:
TP2:
RR TP1:
RR TP2:

⏱️ TIMEFRAME H1
Structure H1: (HH/HL or LH/LL, latest BOS/MSS, demand/supply zone)
🟢 BULLISH SCENARIO H1
Entry type:
Entry:
Stop:
TP1:
TP2:
TP3:
RR TP1:
RR TP2:

🔴 BEARISH SCENARIO H1
Entry type:
Entry:
Stop:
TP1:
TP2:
RR TP1:
RR TP2:

⏱️ TIMEFRAME H4
Structure H4: (HH/HL or LH/LL, BOS/MSS, major OBs, liquidity pools)
🟢 BULLISH SCENARIO H4
Entry type:
Entry:
Stop:
TP1:
TP2:
TP3:
RR TP1:
RR TP2:

🔴 BEARISH SCENARIO H4
Entry type:
Entry:
Stop:
TP1:
TP2:
RR TP1:
RR TP2:

⏱️ TIMEFRAME DAILY
Structure Daily: (macro trend, weekly institutional zones, equal H/L)
🟢 BULLISH SCENARIO DAILY
Entry type:
Entry:
Stop:
TP1:
TP2:
TP3:
RR TP1:
RR TP2:

🔴 BEARISH SCENARIO DAILY
Entry type:
Entry:
Stop:
TP1:
TP2:
RR TP1:
RR TP2:

---------------------------------------------------
4️⃣ RISK MANAGEMENT / GESTION DU RISQUE
---------------------------------------------------

Max risk per trade:
Position sizing:
Inter-TF correlation:
Dynamic stop:
Global invalidation:

---------------------------------------------------
5️⃣ TIMING & CONTEXT / TIMING & CONTEXTE
---------------------------------------------------

Optimal session:
Expected volatility:
Upcoming catalysts:
Index correlation:

---------------------------------------------------
6️⃣ TECHNICAL ANALYSIS / ANALYSE TECHNIQUE
---------------------------------------------------

Key Indicators:
- Wave Trend: status, cross, momentum, divergences
- VMC: status, compression, ribbon, divergences
- If cross in extreme zone: PREMIUM SIGNAL

Support & Resistance:
- Major support:
- Key resistance:
- Order Blocks:
- FVG:

Liquidity Zones (crypto):
- Above price:
- Below price:

---------------------------------------------------
7️⃣ IMPORTANT INFORMATION / INFORMATIONS IMPORTANTES
---------------------------------------------------

[⚡BULLISH] Title — Impact (1 sentence)
[⚡NEUTRAL] Title — Impact (1 sentence)
[⚡BEARISH] Title — Impact (1 sentence)

Min 3 items, max 5. Sources: Bloomberg, Reuters, FT.

---------------------------------------------------
8️⃣ FUNDAMENTAL ANALYSIS / ANALYSE FONDAMENTALE (STOCKS ONLY)
---------------------------------------------------

If stock: P/E, growth, earnings, corporate news.
If crypto/forex: DO NOT include.

---------------------------------------------------
9️⃣ SCORE EXPLANATION / EXPLICATION DU SCORE
---------------------------------------------------

4 lines max, reference sub-scores.

---------------------------------------------------
STYLE: institutional, clear, no disclaimer. Each TF = UNIQUE analysis.
"""
    
    // Language enforcement: prepend directive to system prompt
    let languageDirective = isEN
        ? "\nCRITICAL LANGUAGE RULE: You MUST respond ONLY in English. Every single word — section titles, labels, analysis, values, descriptions — must be in English. Use the English labels from the template (RISK MANAGEMENT, TIMING & CONTEXT, TECHNICAL ANALYSIS, IMPORTANT INFORMATION, FUNDAMENTAL ANALYSIS, BULLISH SCENARIO, BEARISH SCENARIO, etc.).\n"
        : "\nRÈGLE DE LANGUE CRITIQUE : Tu DOIS répondre UNIQUEMENT en français. Chaque mot — titres de sections, étiquettes, analyses, valeurs, descriptions — doit être en français. Utilise les étiquettes françaises du template (GESTION DU RISQUE, TIMING & CONTEXTE, ANALYSE TECHNIQUE, INFORMATIONS IMPORTANTES, ANALYSE FONDAMENTALE, SCÉNARIO HAUSSIER, SCÉNARIO BAISSIER, etc.).\n"
    let finalSystemPrompt = languageDirective + systemPrompt
    
    let userMessage: String
    if isEN {
        userMessage = """
Here is the technical data available for \(symbol):

\(context)

CRITICAL REMINDER: each timeframe (M15, H1, H4, Daily) must have DIFFERENT entry levels, stops and TP.
- M15: amplitude 0.1-0.5%, very tight stops
- H1: amplitude 0.5-1.5%
- H4: amplitude 2-5%
- Daily: amplitude 5-15%

If liquidity zones are provided, use them as TP targets.
If WaveTrend or VMC are in extreme zone with cross, mention it as a premium signal.

Generate the complete analysis according to the strict order defined.
"""
    } else {
        userMessage = """
Voici les données techniques disponibles pour \(symbol) :

\(context)

RAPPEL CRITIQUE : chaque timeframe (M15, H1, H4, Daily) doit avoir des niveaux d'entrée, stops et TP DIFFÉRENTS.
- M15 : amplitude 0.1-0.5%, stops très serrés
- H1 : amplitude 0.5-1.5%
- H4 : amplitude 2-5%
- Daily : amplitude 5-15%

Si des zones de liquidité sont fournies, les utiliser comme objectifs de TP.
Si WaveTrend ou VMC sont en zone extrême avec cross, le mentionner comme signal premium.

Génère l'analyse complète selon l'ordre strict défini.
"""
    }
    
    let messages: [ChatMessagePayload] = [
        ChatMessagePayload(role: "system", content: finalSystemPrompt),
        ChatMessagePayload(role: "user", content: userMessage)
    ]
    
    return try await CloudFunctionService.shared.openAIChat(
        messages: messages,
        model: "gpt-4o",
        temperature: 0.2
    )
}


    // MARK: - Enriched Analysis (WT + MTF + Economic Calendar)
    
    /// Génère une analyse technique enrichie en tenant compte de WT, MTF et du calendrier économique
    /// Format professionnel et synthétique, axé sur les tendances et recommandations
    func generateEnrichedTechnicalAnalysis(
        indicators: [AssistantAIIndicatorSnapshot],
        mtfSnapshot: MTFSnapshot?,
        wtSnapshot: WTSnapshot?,
        economicRiskAnalysis: MarketRiskAnalysis?,
        language: Localizable.Language = LanguageManager.shared.currentLanguage
    ) -> String {
        let isEN = language == .english
        var sections: [String] = []
        
        // 1. TENDANCE GLOBALE (Synthèse des indicateurs techniques)
        var trendSection = "📈 TENDANCE GLOBALE\n"
        trendSection += "────────────────────\n"
        
        var technicalBias: String = isEN ? "Neutral" : "Neutre"
        var technicalStrength: String = isEN ? "Weak" : "Faible"
        var technicalDetails: [String] = []
        
        // Analyser MTF (prioritaire)
        if let mtf = mtfSnapshot {
            let signal = mtf.globalSignal
            let score = mtf.globalCombinedScore
            let confluence = mtf.confluencePercent
            
            switch signal {
            case .buy, .bullish:
                technicalBias = isEN ? "Bullish" : "Haussière"
                if score > 50 && confluence > 60 {
                    technicalStrength = isEN ? "Strong" : "Forte"
                } else {
                    technicalStrength = isEN ? "Moderate" : "Modérée"
                }
            case .sell, .bearish:
                technicalBias = isEN ? "Bearish" : "Baissière"
                if score < -50 && confluence > 60 {
                    technicalStrength = isEN ? "Strong" : "Forte"
                } else {
                    technicalStrength = isEN ? "Moderate" : "Modérée"
                }
            case .neutral:
                technicalBias = isEN ? "Neutral" : "Neutre"
                technicalStrength = isEN ? "Weak" : "Faible"
            }
            
            technicalDetails.append((isEN ? "MTF Signal: " : "Signal MTF: ") + signal.displayName)
            technicalDetails.append((isEN ? "Confluence: " : "Confluence: ") + "\(Int(confluence))%")
            
            // Divergences importantes
            let allReadings = Array(mtf.readings.values)
            let divergences = allReadings.filter { $0.hasDivergence }
            if !divergences.isEmpty {
                var divergenceText = "⚠️ Divergences: "
                if divergences.contains(where: { $0.divergenceType == .rsiBullishVMCBearish }) {
                    divergenceText += isEN ? "Possible bullish trap. " : "Piège haussier possible. "
                }
                if divergences.contains(where: { $0.divergenceType == .rsiBearishVMCBullish }) {
                    divergenceText += isEN ? "Possible absorption. " : "Absorption possible. "
                }
                technicalDetails.append(divergenceText)
            }
        }
        
        // Analyser Wave Trend (tendance et biais)
        if let wt = wtSnapshot {
            let bias = wt.currentMarketBias
            let momentumDir = wt.momentumDirection
            
            var wtBias = ""
            switch bias {
            case .bullish:
                wtBias = isEN ? "Bullish" : "Haussier"
            case .bearish:
                wtBias = isEN ? "Bearish" : "Baissier"
            case .neutral:
                wtBias = isEN ? "Neutral" : "Neutre"
            }
            
            technicalDetails.append((isEN ? "Wave Trend Bias: " : "Biais Wave Trend: ") + wtBias)
            
            if momentumDir == .growing {
                technicalDetails.append(isEN ? "Momentum: Growing" : "Momentum: Croissant")
            } else if momentumDir == .falling {
                technicalDetails.append(isEN ? "Momentum: Falling" : "Momentum: Décroissant")
            }
            
            // Signaux importants
            if let signal = wt.currentSignal {
                switch signal {
                case .bullishReversal, .bullishSmartReversal:
                    technicalDetails.append("🟢 Signal d'achat détecté")
                case .bearishReversal, .bearishSmartReversal:
                    technicalDetails.append("🔴 Signal de vente détecté")
                case .neutral:
                    break
                }
            }
        }
        
        trendSection += (isEN ? "Direction: " : "Direction: ") + "\(technicalBias) (\(technicalStrength))\n"
        if !technicalDetails.isEmpty {
            trendSection += technicalDetails.joined(separator: "\n") + "\n"
        }
        sections.append(trendSection)
        
        // 2. CONTEXTE MACROÉCONOMIQUE
        if let economic = economicRiskAnalysis {
            var macroSection = "🌍 CONTEXTE MACROÉCONOMIQUE\n"
            macroSection += "────────────────────\n"
            
            let riskLevel = economic.riskLevel
            let sentiment = economic.marketSentiment
            
            macroSection += (isEN ? "Risk level: " : "Niveau de risque: ") + "\(riskLevel.displayName)\n"
            macroSection += (isEN ? "Macro sentiment: " : "Sentiment macro: ") + "\(sentiment.displayName)\n"
            
            // Événements critiques à venir
            let criticalEvents = economic.events.filter {
                ($0.category ?? .other) == .interestRate ||
                ($0.category ?? .other) == .inflation ||
                ($0.category ?? .other) == .employment
            }
            
            if !criticalEvents.isEmpty {
                let eventNames = criticalEvents.prefix(3).map { $0.name }.joined(separator: ", ")
                macroSection += "⚠️ \(criticalEvents.count) " + (isEN ? "major event(s): " : "événement(s) majeur(s): ") + "\(eventNames)\n"
            }
            
            // Impact spécifique sur Crypto
            if let cryptoRec = economic.marketRecommendations.first(where: { $0.market == "Crypto" }) {
                macroSection += "\n💡 Impact Crypto:\n"
                macroSection += "• \(cryptoRec.title)\n"
                macroSection += "• " + (isEN ? "Sentiment: " : "Sentiment: ") + "\(cryptoRec.sentiment.displayName)\n"
                macroSection += "• " + (isEN ? "Intensity: " : "Intensité: ") + "\(cryptoRec.intensity)\n"
                
                if !cryptoRec.actionableRecommendations.isEmpty {
                    macroSection += "• " + (isEN ? "Actions: " : "Actions: ") + "\(cryptoRec.actionableRecommendations.prefix(2).joined(separator: ". "))\n"
                }
            }
            
            sections.append(macroSection)
        }
        
        // 3. BILAN GLOBAL & RECOMMANDATIONS
        var summarySection = "🎯 BILAN GLOBAL & RECOMMANDATIONS\n"
        summarySection += "────────────────────\n"
        
        // Compter les signaux
        var bullishSignals = 0
        var bearishSignals = 0
        var neutralSignals = 0
        
        if let mtf = mtfSnapshot {
            if mtf.globalSignal == .buy || mtf.globalSignal == .bullish {
                bullishSignals += 1
            } else if mtf.globalSignal == .sell || mtf.globalSignal == .bearish {
                bearishSignals += 1
            } else {
                neutralSignals += 1
            }
        }
        
        if let wt = wtSnapshot {
            if wt.currentMarketBias == .bullish {
                bullishSignals += 1
            } else if wt.currentMarketBias == .bearish {
                bearishSignals += 1
            } else {
                neutralSignals += 1
            }
            
            if let signal = wt.currentSignal {
                if signal == .bullishReversal || signal == .bullishSmartReversal {
                    bullishSignals += 1
                } else if signal == .bearishReversal || signal == .bearishSmartReversal {
                    bearishSignals += 1
                }
            }
        }
        
        if let economic = economicRiskAnalysis {
            if economic.marketSentiment == .bullish {
                bullishSignals += 1
            } else if economic.marketSentiment == .bearish {
                bearishSignals += 1
            } else {
                neutralSignals += 1
            }
        }
        
        // Synthèse du bilan
        let totalSignals = bullishSignals + bearishSignals + neutralSignals
        if totalSignals > 0 {
            let _ = Int((Double(bullishSignals) / Double(totalSignals)) * 100)
            let _ = Int((Double(bearishSignals) / Double(totalSignals)) * 100)
            
            summarySection += isEN
                ? "Confluence: \(bullishSignals) bullish vs \(bearishSignals) bearish\n"
                : "Confluence: \(bullishSignals) haussier(s) vs \(bearishSignals) baissier(s)\n"
            
            // Recommandation principale
            if bullishSignals > bearishSignals && bullishSignals >= 2 {
                if isEN {
                    summarySection += "\n✅ RECOMMENDATION: Favor long positions\n"
                    summarySection += "• Enter on pullbacks toward supports\n"
                    summarySection += "• Watch for technical confirmations\n"
                } else {
                    summarySection += "\n✅ RECOMMANDATION: Privilégier les positions longues\n"
                    summarySection += "• Entrer sur replis vers supports\n"
                    summarySection += "• Surveiller les confirmations techniques\n"
                }
            } else if bearishSignals > bullishSignals && bearishSignals >= 2 {
                if isEN {
                    summarySection += "\n⚠️ RECOMMENDATION: Caution on long positions\n"
                    summarySection += "• Avoid aggressive long entries\n"
                    summarySection += "• Watch for support breakdowns\n"
                } else {
                    summarySection += "\n⚠️ RECOMMANDATION: Prudence sur les positions longues\n"
                    summarySection += "• Éviter les entrées longues agressives\n"
                    summarySection += "• Surveiller les cassures de supports\n"
                }
            } else {
                if isEN {
                    summarySection += "\n⚖️ RECOMMENDATION: Wait for clear confluence\n"
                    summarySection += "• Mixed signals - caution required\n"
                    summarySection += "• Wait for confirmation before acting\n"
                } else {
                    summarySection += "\n⚖️ RECOMMANDATION: Attendre une convergence claire\n"
                    summarySection += "• Signaux mixtes - prudence requise\n"
                    summarySection += "• Surveiller les confirmations avant d'agir\n"
                }
            }
        }
        
        // Avertissement macro si nécessaire
        if let economic = economicRiskAnalysis {
            if economic.riskLevel == .critical || economic.riskLevel == .veryHigh {
                summarySection += "\n🚨 ATTENTION: Risque macro élevé\n"
                summarySection += "• Réduire l'exposition avant les annonces majeures\n"
                summarySection += "• Surveiller en temps réel les annonces de banques centrales\n"
            } else if economic.riskLevel == .high {
                summarySection += "\n⚠️ Risque macro modéré\n"
                summarySection += "• Surveiller les événements économiques à venir\n"
            }
        }
        
        sections.append(summarySection)
        
        return sections.joined(separator: "\n\n")
    }
}

private extension Double {
    func sign() -> Double {
        if self > 0 { return 1 }
        if self < 0 { return -1 }
        return 0
    }
}

private struct RecommendationBundle {
    let trend: String
    let marketConfluence: String
    let technicalSummary: String
    let riskScore: Int
    let emotionScore: Int
    let emotionAdvice: String
    let actionables: [String]
}
