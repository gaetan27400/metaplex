//
//  MacroValueParser.swift
//  Journal de trading 2025
//
//  Service pour parser les valeurs macroéconomiques (String -> Double)
//

import Foundation

final class MacroValueParser {
    static let shared = MacroValueParser()
    
    private init() {}
    
    /// Parse une valeur macroéconomique depuis une String
    /// Gère: "216K", "-4,94B", "0,7 %", "110,5", "1 234,56", "—", "", null
    func parseMacroValue(_ input: String?) -> ParsedMacroValue {
        guard let input = input, !input.isEmpty else {
            return ParsedMacroValue(
                raw: input ?? "",
                numericValue: nil,
                unit: .number,
                magnitude: .none,
                isValid: false
            )
        }
        
        // Nettoyer la string
        var cleaned = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Gérer les cas spéciaux
        if cleaned == "—" || cleaned == "-" || cleaned == "N/A" || cleaned.lowercased() == "null" {
            return ParsedMacroValue(
                raw: input,
                numericValue: nil,
                unit: .number,
                magnitude: .none,
                isValid: false
            )
        }
        
        // Détecter si c'est un pourcentage
        let isPercent = cleaned.contains("%") || cleaned.hasSuffix(" %")
        if isPercent {
            cleaned = cleaned.replacingOccurrences(of: "%", with: "")
            cleaned = cleaned.replacingOccurrences(of: " %", with: "")
        }
        
        // Normaliser les séparateurs décimaux (virgule -> point)
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")
        
        // Supprimer les espaces (ex: "1 234,56" -> "1234.56")
        cleaned = cleaned.replacingOccurrences(of: " ", with: "")
        
        // Détecter la magnitude (K, M, B)
        var magnitude: ParsedMacroValue.Magnitude = .none
        var magnitudeMultiplier: Double = 1.0
        
        if cleaned.uppercased().hasSuffix("K") {
            magnitude = .k
            magnitudeMultiplier = 1_000.0
            cleaned = String(cleaned.dropLast())
        } else if cleaned.uppercased().hasSuffix("M") {
            magnitude = .m
            magnitudeMultiplier = 1_000_000.0
            cleaned = String(cleaned.dropLast())
        } else if cleaned.uppercased().hasSuffix("B") {
            magnitude = .b
            magnitudeMultiplier = 1_000_000_000.0
            cleaned = String(cleaned.dropLast())
        }
        
        // Parser le nombre
        let numericValue: Double?
        if let value = Double(cleaned) {
            numericValue = value * magnitudeMultiplier
        } else {
            numericValue = nil
        }
        
        return ParsedMacroValue(
            raw: input,
            numericValue: numericValue,
            unit: isPercent ? .percent : .number,
            magnitude: magnitude,
            isValid: numericValue != nil
        )
    }
}
