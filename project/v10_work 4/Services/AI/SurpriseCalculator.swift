//
//  SurpriseCalculator.swift
//  Journal de trading 2025
//
//  Service pour calculer la "surprise" d'un événement économique
//

import Foundation

final class SurpriseCalculator {
    static let shared = SurpriseCalculator()
    
    // Seuils configurables pour l'intensité
    var lowThreshold: Double = 0.05      // 5%
    var mediumThreshold: Double = 0.15   // 15%
    var highThreshold: Double = 0.30     // 30%
    
    private init() {}
    
    /// Calcule la surprise d'un événement économique
    func computeSurprise(event: CalendarEvent) -> SurpriseResult {
        let parser = MacroValueParser.shared
        
        let actualParsed = parser.parseMacroValue(event.actual)
        let consensusParsed = parser.parseMacroValue(event.consensus)
        let previousParsed = parser.parseMacroValue(event.previous)
        
        // Déterminer la baseline
        let baseline: SurpriseResult.BaselineType
        let baselineValue: Double?
        
        if let consensus = consensusParsed.numericValue, consensusParsed.isValid {
            baseline = .consensus
            baselineValue = consensus
        } else if let previous = previousParsed.numericValue, previousParsed.isValid {
            baseline = .previous
            baselineValue = previous
        } else {
            baseline = .none
            baselineValue = nil
        }
        
        // Calculer la surprise
        let surpriseValue: Double?
        let surprisePct: Double?
        let direction: SurpriseResult.SurpriseDirection
        
        if let actual = actualParsed.numericValue,
           actualParsed.isValid,
           let baseline = baselineValue {
            
            surpriseValue = actual - baseline
            
            if abs(baseline) > 1e-10 { // Éviter division par zéro
                surprisePct = (actual - baseline) / abs(baseline)
            } else {
                surprisePct = nil
            }
            
            // Déterminer la direction
            if let pct = surprisePct {
                if abs(pct) < 0.001 { // Égalité (tolérance 0.1%)
                    direction = .equal
                } else if pct > 0 {
                    direction = .above
                } else {
                    direction = .below
                }
            } else {
                direction = .unknown
            }
        } else {
            surpriseValue = nil
            surprisePct = nil
            direction = .unknown
        }
        
        // Déterminer l'intensité
        let intensity: SurpriseResult.SurpriseIntensity
        if let pct = surprisePct {
            let absPct = abs(pct)
            if absPct >= highThreshold {
                intensity = .high
            } else if absPct >= mediumThreshold {
                intensity = .medium
            } else if absPct >= lowThreshold {
                intensity = .low
            } else {
                intensity = .none
            }
        } else {
            intensity = .none
        }
        
        // Debug string
        var debugParts: [String] = []
        debugParts.append("Actual: \(actualParsed.isValid ? String(format: "%.2f", actualParsed.numericValue ?? 0) : "N/A")")
        if consensusParsed.isValid {
            debugParts.append("Consensus: \(String(format: "%.2f", consensusParsed.numericValue ?? 0))")
        }
        if previousParsed.isValid {
            debugParts.append("Previous: \(String(format: "%.2f", previousParsed.numericValue ?? 0))")
        }
        debugParts.append("Baseline: \(baseline)")
        if let pct = surprisePct {
            debugParts.append("Surprise: \(String(format: "%.2f%%", pct * 100))")
        }
        
        return SurpriseResult(
            baseline: baseline,
            surpriseValue: surpriseValue,
            surprisePct: surprisePct,
            direction: direction,
            intensity: intensity,
            debug: debugParts.joined(separator: " | ")
        )
    }
}
