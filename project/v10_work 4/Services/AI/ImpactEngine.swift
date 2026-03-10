//
//  ImpactEngine.swift
//  Journal de trading 2025
//
//  Moteur d'impact pour déterminer l'effet des événements économiques sur les marchés
//

import Foundation

final class ImpactEngine {
    static let shared = ImpactEngine()
    
    private init() {}
    
    /// Résout le profil d'impact d'un événement
    func resolveImpactProfile(event: CalendarEvent) -> EventImpactProfile {
        // Vérifier d'abord les exceptions par mots-clés dans le nom
        if let keywordProfile = resolveByKeyword(event.name) {
            return keywordProfile
        }
        
        // Sinon, utiliser categoryId
        if let categoryId = event.categoryId {
            return resolveByCategory(categoryId)
        }
        
        // Fallback: profil neutre
        return EventImpactProfile(
            higherIsBetter: nil,
            assessments: []
        )
    }
    
    /// Résout par mot-clé dans le nom (priorité)
    private func resolveByKeyword(_ name: String) -> EventImpactProfile? {
        let lowerName = name.lowercased()
        
        // Employment / Unemployment
        if lowerName.contains("unemployment") || lowerName.contains("jobless") || lowerName.contains("non-farm payroll") || lowerName.contains("nfp") {
            return EventImpactProfile(
                higherIsBetter: false, // Plus de chômage = mauvais
                assessments: [
                    ImpactAssessment(
                        market: .fx,
                        biasIfAbove: .bearish,
                        biasIfBelow: .bullish,
                        rationale: "Chômage élevé → faiblesse économique → monnaie↓"
                    ),
                    ImpactAssessment(
                        market: .equities,
                        biasIfAbove: .bearish,
                        biasIfBelow: .bullish,
                        rationale: "Chômage élevé → consommation↓ → indices↓"
                    ),
                    ImpactAssessment(
                        market: .rates,
                        biasIfAbove: .bullish, // Taux baissent
                        biasIfBelow: .bearish,
                        rationale: "Chômage élevé → banque centrale accommodante → taux↓"
                    )
                ]
            )
        }
        
        // CPI / Inflation
        if lowerName.contains("cpi") || lowerName.contains("inflation") || lowerName.contains("consumer price") {
            return EventImpactProfile(
                higherIsBetter: false, // Plus d'inflation = mauvais (sauf si déflation)
                assessments: [
                    ImpactAssessment(
                        market: .fx,
                        biasIfAbove: .mixed,
                        biasIfBelow: .mixed,
                        rationale: "Inflation élevée → hausse taux → monnaie↑ (mais risque récession)"
                    ),
                    ImpactAssessment(
                        market: .rates,
                        biasIfAbove: .bearish, // Taux montent
                        biasIfBelow: .bullish,
                        rationale: "Inflation élevée → banque centrale restrictive → taux↑"
                    ),
                    ImpactAssessment(
                        market: .equities,
                        biasIfAbove: .bearish,
                        biasIfBelow: .bullish,
                        rationale: "Inflation élevée → coûts↑ → marges↓ → indices↓"
                    )
                ]
            )
        }
        
        // GDP
        if lowerName.contains("gdp") || lowerName.contains("gross domestic product") {
            return EventImpactProfile(
                higherIsBetter: true, // Plus de PIB = bon
                assessments: [
                    ImpactAssessment(
                        market: .fx,
                        biasIfAbove: .bullish,
                        biasIfBelow: .bearish,
                        rationale: "PIB élevé → économie forte → monnaie↑"
                    ),
                    ImpactAssessment(
                        market: .equities,
                        biasIfAbove: .bullish,
                        biasIfBelow: .bearish,
                        rationale: "PIB élevé → croissance → indices↑"
                    ),
                    ImpactAssessment(
                        market: .rates,
                        biasIfAbove: .bearish, // Taux montent
                        biasIfBelow: .bullish,
                        rationale: "PIB élevé → surchauffe → banque centrale restrictive → taux↑"
                    )
                ]
            )
        }
        
        // Retail Sales
        if lowerName.contains("retail sales") || lowerName.contains("retail") {
            return EventImpactProfile(
                higherIsBetter: true,
                assessments: [
                    ImpactAssessment(
                        market: .fx,
                        biasIfAbove: .bullish,
                        biasIfBelow: .bearish,
                        rationale: "Ventes élevées → consommation↑ → économie↑ → monnaie↑"
                    ),
                    ImpactAssessment(
                        market: .equities,
                        biasIfAbove: .bullish,
                        biasIfBelow: .bearish,
                        rationale: "Ventes élevées → bénéfices↑ → indices↑"
                    )
                ]
            )
        }
        
        // PMI
        if lowerName.contains("pmi") || lowerName.contains("purchasing manager") {
            return EventImpactProfile(
                higherIsBetter: true,
                assessments: [
                    ImpactAssessment(
                        market: .fx,
                        biasIfAbove: .bullish,
                        biasIfBelow: .bearish,
                        rationale: "PMI > 50 → expansion → monnaie↑"
                    ),
                    ImpactAssessment(
                        market: .equities,
                        biasIfAbove: .bullish,
                        biasIfBelow: .bearish,
                        rationale: "PMI > 50 → activité↑ → indices↑"
                    )
                ]
            )
        }
        
        // Interest Rate
        if lowerName.contains("interest rate") || lowerName.contains("rate decision") || lowerName.contains("fed") {
            return EventImpactProfile(
                higherIsBetter: nil, // Dépend du contexte
                assessments: [
                    ImpactAssessment(
                        market: .fx,
                        biasIfAbove: .bullish,
                        biasIfBelow: .bearish,
                        rationale: "Taux élevés → rendement↑ → monnaie↑"
                    ),
                    ImpactAssessment(
                        market: .equities,
                        biasIfAbove: .bearish,
                        biasIfBelow: .bullish,
                        rationale: "Taux élevés → coût capital↑ → indices↓"
                    ),
                    ImpactAssessment(
                        market: .rates,
                        biasIfAbove: .bearish,
                        biasIfBelow: .bullish,
                        rationale: "Taux directeurs↑ → rendements obligataires↑"
                    )
                ]
            )
        }
        
        return nil
    }
    
    /// Résout par categoryId
    private func resolveByCategory(_ categoryId: String) -> EventImpactProfile {
        switch categoryId.lowercased() {
        case "employment", "jobs":
            return EventImpactProfile(
                higherIsBetter: false,
                assessments: [
                    ImpactAssessment(
                        market: .fx,
                        biasIfAbove: .bearish,
                        biasIfBelow: .bullish,
                        rationale: "Chômage élevé → faiblesse économique → monnaie↓"
                    )
                ]
            )
            
        case "inflation", "cpi", "ppi":
            return EventImpactProfile(
                higherIsBetter: false,
                assessments: [
                    ImpactAssessment(
                        market: .rates,
                        biasIfAbove: .bearish,
                        biasIfBelow: .bullish,
                        rationale: "Inflation élevée → banque centrale restrictive → taux↑"
                    )
                ]
            )
            
        case "gdp":
            return EventImpactProfile(
                higherIsBetter: true,
                assessments: [
                    ImpactAssessment(
                        market: .fx,
                        biasIfAbove: .bullish,
                        biasIfBelow: .bearish,
                        rationale: "PIB élevé → économie forte → monnaie↑"
                    )
                ]
            )
            
        case "interest rate", "rates":
            return EventImpactProfile(
                higherIsBetter: nil,
                assessments: [
                    ImpactAssessment(
                        market: .fx,
                        biasIfAbove: .bullish,
                        biasIfBelow: .bearish,
                        rationale: "Taux élevés → rendement↑ → monnaie↑"
                    )
                ]
            )
            
        default:
            return EventImpactProfile(
                higherIsBetter: nil,
                assessments: []
            )
        }
    }
    
    /// Construit les scénarios texte pour un événement
    func buildScenarioText(event: CalendarEvent, profile: EventImpactProfile) -> ScenarioPair {
        let parser = MacroValueParser.shared
        let _ = parser.parseMacroValue(event.consensus)
        
        var aboveParts: [String] = []
        var belowParts: [String] = []
        
        // Construire les scénarios selon les assessments
        for assessment in profile.assessments {
            switch assessment.market {
            case .fx:
                if assessment.biasIfAbove == .bullish {
                    aboveParts.append("\(event.currencyCode ?? "FX")↑")
                } else if assessment.biasIfAbove == .bearish {
                    aboveParts.append("\(event.currencyCode ?? "FX")↓")
                }
                
                if assessment.biasIfBelow == .bullish {
                    belowParts.append("\(event.currencyCode ?? "FX")↑")
                } else if assessment.biasIfBelow == .bearish {
                    belowParts.append("\(event.currencyCode ?? "FX")↓")
                }
                
            case .equities:
                if assessment.biasIfAbove == .bullish {
                    aboveParts.append("Indices↑")
                } else if assessment.biasIfAbove == .bearish {
                    aboveParts.append("Indices↓")
                }
                
                if assessment.biasIfBelow == .bullish {
                    belowParts.append("Indices↑")
                } else if assessment.biasIfBelow == .bearish {
                    belowParts.append("Indices↓")
                }
                
            case .rates:
                if assessment.biasIfAbove == .bearish {
                    aboveParts.append("Taux↑")
                } else if assessment.biasIfAbove == .bullish {
                    aboveParts.append("Taux↓")
                }
                
                if assessment.biasIfBelow == .bearish {
                    belowParts.append("Taux↑")
                } else if assessment.biasIfBelow == .bullish {
                    belowParts.append("Taux↓")
                }
            }
        }
        
        let aboveText = aboveParts.isEmpty ? "Impact limité" : aboveParts.joined(separator: " / ")
        let belowText = belowParts.isEmpty ? "Impact limité" : belowParts.joined(separator: " / ")
        
        return ScenarioPair(above: aboveText, below: belowText)
    }
}
