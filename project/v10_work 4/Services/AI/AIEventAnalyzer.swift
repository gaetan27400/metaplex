//
//  AIEventAnalyzer.swift
//  Journal de trading 2025
//
//  Service principal pour l'analyse IA des événements économiques
//

import Foundation

final class AIEventAnalyzer {
    static let shared = AIEventAnalyzer()
    
    private let surpriseCalculator = SurpriseCalculator.shared
    private let impactEngine = ImpactEngine.shared
    private let parser = MacroValueParser.shared
    
    private init() {}
    
    /// Génère une analyse IA complète pour un événement
    func analyzeEvent(_ event: CalendarEvent) -> AIEventInsight {
        let actualParsed = parser.parseMacroValue(event.actual)
        let isPostRelease = actualParsed.isValid
        
        let status: AIEventInsight.InsightStatus = isPostRelease ? .postRelease : .preRelease
        
        // Calculer la surprise si post-release
        let surprise: SurpriseResult? = isPostRelease ? surpriseCalculator.computeSurprise(event: event) : nil
        
        // Résoudre le profil d'impact
        let profile = impactEngine.resolveImpactProfile(event: event)
        let scenarios = impactEngine.buildScenarioText(event: event, profile: profile)
        
        // Générer le titre
        let title = generateTitle(event: event, status: status, surprise: surprise)
        
        // Générer le résumé
        let summary = generateSummary(event: event, status: status, surprise: surprise, profile: profile)
        
        // Déterminer l'intensité
        let intensity = determineIntensity(event: event, surprise: surprise)
        
        // Calculer le sentiment individuel de l'événement
        let (eventSentiment, sentimentArgumentation) = calculateEventSentiment(event: event, surprise: surprise, profile: profile)
        
        return AIEventInsight(
            title: title,
            status: status,
            surprise: surprise,
            scenarios: scenarios,
            summary: summary,
            intensity: intensity,
            eventSentiment: eventSentiment,
            eventSentimentArgumentation: sentimentArgumentation
        )
    }
    
    /// Génère le titre de l'analyse
    private func generateTitle(event: CalendarEvent, status: AIEventInsight.InsightStatus, surprise: SurpriseResult?) -> String {
        if status == .preRelease {
            return "Analyse pré-publication: \(event.name)"
        }
        
        guard let surprise = surprise else {
            return "Analyse: \(event.name)"
        }
        
        switch surprise.direction {
        case .above:
            return "Surprise haussière: \(event.name)"
        case .below:
            return "Surprise baissière: \(event.name)"
        case .equal:
            return "Conforme aux attentes: \(event.name)"
        case .unknown:
            return "Analyse: \(event.name)"
        }
    }
    
    /// Génère le résumé de l'analyse
    private func generateSummary(event: CalendarEvent, status: AIEventInsight.InsightStatus, surprise: SurpriseResult?, profile: EventImpactProfile) -> String {
        if status == .preRelease {
            let consensusParsed = parser.parseMacroValue(event.consensus)
            if consensusParsed.isValid, let consensus = consensusParsed.numericValue {
                return "Attente: \(formatValue(consensus, unit: consensusParsed.unit, magnitude: consensusParsed.magnitude)). Surveiller la volatilité autour de la publication."
            }
            return "Publication imminente. Surveiller la volatilité sur \(event.currencyCode ?? "les marchés")."
        }
        
        guard let surprise = surprise else {
            return "Données disponibles mais analyse incomplète."
        }
        
        var parts: [String] = []
        
        // Ajouter la surprise
        if let pct = surprise.surprisePct {
            let pctStr = String(format: "%.1f%%", abs(pct) * 100)
            switch surprise.direction {
            case .above:
                parts.append("Résultat supérieur de \(pctStr) aux attentes")
            case .below:
                parts.append("Résultat inférieur de \(pctStr) aux attentes")
            case .equal:
                parts.append("Résultat conforme aux attentes")
            case .unknown:
                break
            }
        }
        
        // Ajouter l'intensité
        switch surprise.intensity {
        case .high:
            parts.append("Impact majeur attendu")
        case .medium:
            parts.append("Impact modéré")
        case .low:
            parts.append("Impact limité")
        case .none:
            break
        }
        
        // Ajouter le biais de marché
        if let firstAssessment = profile.assessments.first {
            switch surprise.direction {
            case .above:
                switch firstAssessment.biasIfAbove {
                case .bullish:
                    parts.append("Biais haussier")
                case .bearish:
                    parts.append("Biais baissier")
                default:
                    break
                }
            case .below:
                switch firstAssessment.biasIfBelow {
                case .bullish:
                    parts.append("Biais haussier")
                case .bearish:
                    parts.append("Biais baissier")
                default:
                    break
                }
            default:
                break
            }
        }
        
        return parts.isEmpty ? "Analyse disponible" : parts.joined(separator: ". ")
    }
    
    /// Détermine l'intensité textuelle
    private func determineIntensity(event: CalendarEvent, surprise: SurpriseResult?) -> String {
        // Intensité basée sur la volatilité
        let volatilityWeight: Int
        switch event.volatility.uppercased() {
        case "HIGH": volatilityWeight = 3
        case "MEDIUM": volatilityWeight = 2
        case "LOW": volatilityWeight = 1
        default: volatilityWeight = 0
        }
        
        // Intensité basée sur la surprise
        let surpriseWeight: Int
        if let surprise = surprise {
            switch surprise.intensity {
            case .high: surpriseWeight = 3
            case .medium: surpriseWeight = 2
            case .low: surpriseWeight = 1
            case .none: surpriseWeight = 0
            }
        } else {
            surpriseWeight = 0
        }
        
        let totalWeight = volatilityWeight + surpriseWeight
        
        switch totalWeight {
        case 5...6:
            return "Très élevée"
        case 3...4:
            return "Élevée"
        case 1...2:
            return "Modérée"
        default:
            return "Faible"
        }
    }
    
    /// Formate une valeur pour l'affichage
    private func formatValue(_ value: Double, unit: ParsedMacroValue.UnitType, magnitude: ParsedMacroValue.Magnitude) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        
        var displayValue = value
        
        // Ajuster selon la magnitude
        var suffix = ""
        switch magnitude {
        case .k:
            displayValue = value / 1_000.0
            suffix = "K"
        case .m:
            displayValue = value / 1_000_000.0
            suffix = "M"
        case .b:
            displayValue = value / 1_000_000_000.0
            suffix = "B"
        case .none:
            break
        }
        
        let number = NSNumber(value: displayValue)
        let formatted = formatter.string(from: number) ?? String(displayValue)
        
        if unit == .percent {
            return "\(formatted)%\(suffix)"
        } else {
            return "\(formatted)\(suffix)"
        }
    }
}

// MARK: - Risk Aggregator

extension AIEventAnalyzer {
    /// Calcule les résumés de risque par devise
    func computeRiskSummaries(events: [CalendarEvent]) -> [RiskSummary] {
        // Grouper par currencyCode
        let grouped = Dictionary(grouping: events) { $0.currencyCode ?? "UNKNOWN" }
        
        var summaries: [RiskSummary] = []
        
        for (currencyCode, currencyEvents) in grouped {
            // Calculer le score du jour (événements aujourd'hui)
            let today = Calendar.current.startOfDay(for: Date())
            let dayEvents = currencyEvents.filter { event in
                guard let date = event.dateValue else { return false }
                return Calendar.current.isDate(date, inSameDayAs: today)
            }
            
            let dayScore = calculateRiskScore(events: dayEvents)
            
            // Calculer le score de la semaine (événements dans les 7 prochains jours)
            let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? Date()
            let weekEvents = currencyEvents.filter { event in
                guard let date = event.dateValue else { return false }
                return date >= today && date <= weekEnd
            }
            
            let weekScore = calculateRiskScore(events: weekEvents)
            
            // Top événements (triés par score)
            let topEvents = weekEvents.sorted { event1, event2 in
                let score1 = calculateEventScore(event1)
                let score2 = calculateEventScore(event2)
                return score1 > score2
            }.prefix(5)
            
            summaries.append(RiskSummary(
                currencyCode: currencyCode,
                dayScore: dayScore,
                weekScore: weekScore,
                topEvents: Array(topEvents)
            ))
        }
        
        return summaries.sorted { $0.weekScore > $1.weekScore }
    }
    
    /// Calcule le score de risque pour une liste d'événements
    private func calculateRiskScore(events: [CalendarEvent]) -> Double {
        let totalScore = events.reduce(0.0) { sum, event in
            return sum + calculateEventScore(event)
        }
        return totalScore
    }
    
    /// Calcule le score d'un événement individuel
    // MARK: - Event Sentiment Calculation
    
    private func calculateEventSentiment(event: CalendarEvent, surprise: SurpriseResult?, profile: EventImpactProfile) -> (AIEventInsight.EventSentiment, String) {
        let category = event.category ?? .other
        
        // Helper pour déterminer le bias principal du profil
        let primaryBias: ImpactBias = {
            guard let firstAssessment = profile.assessments.first else { return .unknown }
            // Utiliser le bias "above" comme référence principale
            return firstAssessment.biasIfAbove
        }()
        
        // Si post-release, utiliser la surprise
        if let surprise = surprise {
            switch surprise.direction {
            case .above:
                // Surprise positive
                if primaryBias == .bullish {
                    return (.bullish, "Résultat supérieur aux attentes avec une surprise de \(String(format: "%.1f%%", abs(surprise.surprisePct ?? 0) * 100)). Cet événement \(category.displayName.lowercased()) est favorable aux marchés, suggérant une dynamique économique positive.")
                } else if primaryBias == .bearish {
                    return (.bearish, "Résultat supérieur aux attentes mais dans un contexte défavorable. L'événement \(category.displayName.lowercased()) peut créer de la volatilité négative malgré la surprise positive.")
                } else {
                    return (.neutral, "Résultat supérieur aux attentes sans impact directionnel clair. La surprise de \(String(format: "%.1f%%", abs(surprise.surprisePct ?? 0) * 100)) nécessite une analyse contextuelle approfondie.")
                }
            case .below:
                // Surprise négative
                if primaryBias == .bearish {
                    return (.bearish, "Résultat inférieur aux attentes avec une surprise négative de \(String(format: "%.1f%%", abs(surprise.surprisePct ?? 0) * 100)). Cet événement \(category.displayName.lowercased()) est défavorable aux marchés, indiquant des tensions économiques.")
                } else if primaryBias == .bullish {
                    return (.neutral, "Résultat inférieur aux attentes dans un contexte généralement positif. L'impact peut être limité mais nécessite une vigilance accrue.")
                } else {
                    return (.bearish, "Résultat inférieur aux attentes. La surprise négative de \(String(format: "%.1f%%", abs(surprise.surprisePct ?? 0) * 100)) crée un environnement défavorable pour les marchés.")
                }
            case .equal:
                return (.neutral, "Résultat conforme aux attentes. L'événement \(category.displayName.lowercased()) n'apporte pas de surprise, limitant l'impact directionnel sur les marchés.")
            case .unknown:
                return (.neutral, "Données disponibles mais analyse de surprise incomplète. Nécessite une évaluation contextuelle pour déterminer l'impact.")
            }
        }
        
        // Pré-release : analyser selon la catégorie et le profil d'impact
        switch category {
        case .gdp:
            return (.bullish, "Publication du PIB imminente. Les données de croissance économique sont généralement positives pour les marchés actions et le forex. Surveiller si le résultat dépasse les attentes pour un signal haussier fort.")
        case .inflation:
            return (.bearish, "Publication de l'inflation imminente. Des données d'inflation élevées sont généralement négatives pour les marchés, pouvant entraîner des hausses de taux d'intérêt et une pression baissière.")
        case .interestRate:
            return (.bearish, "Décision de taux d'intérêt imminente. Les hausses de taux sont généralement négatives pour les actions mais positives pour la devise. La volatilité sera élevée autour de l'annonce.")
        case .employment:
            if primaryBias == .bullish {
                return (.bullish, "Publication de l'emploi imminente. Des données d'emploi solides sont positives pour l'économie et les marchés, indiquant une croissance saine.")
            } else {
                return (.bearish, "Publication de l'emploi imminente. Des données d'emploi faibles sont négatives pour l'économie et peuvent créer une pression baissière sur les marchés.")
            }
        default:
            return (.neutral, "Événement économique à surveiller. L'impact dépendra des résultats publiés et du contexte macroéconomique global.")
        }
    }
    
    private func calculateEventScore(_ event: CalendarEvent) -> Double {
        var score: Double = 0.0
        
        // Poids de la volatilité
        switch event.volatility.uppercased() {
        case "HIGH": score += 3.0
        case "MEDIUM": score += 2.0
        case "LOW": score += 1.0
        default: break
        }
        
        // Bonus si surprise élevée
        let surprise = surpriseCalculator.computeSurprise(event: event)
        switch surprise.intensity {
        case .high: score += 2.0
        case .medium: score += 1.0
        case .low: score += 0.5
        case .none: break
        }
        
        return score
    }
}
