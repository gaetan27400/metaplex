//
//  NumberFormatting.swift
//  Journal de trading 2025
//
//  Extensions pour le formatage des nombres (P&L, etc.)
//

import Foundation

extension Double {
    /// Formatage P&L avec unité (k pour milliers)
    /// - Returns: String formaté (ex: "10k", "1.5k", "500")
    var formattedPnL: String {
        if abs(self) >= 10000 {
            return String(format: "%.0fk", self / 1000)
        } else if abs(self) >= 1000 {
            return String(format: "%.1fk", self / 1000)
        } else {
            return String(format: "%.0f", self)
        }
    }
    
    /// Formatage P&L avec signe
    /// - Returns: String formaté avec signe (ex: "+10k", "-1.5k")
    var formattedPnLWithSign: String {
        let formatted = formattedPnL
        return self >= 0 ? "+\(formatted)" : formatted
    }
    
    /// Formatage pourcentage
    /// - Parameter decimals: Nombre de décimales (défaut: 2)
    /// - Returns: String formaté (ex: "15.50%")
    func formattedPercentage(decimals: Int = 2) -> String {
        return String(format: "%.\(decimals)f%%", self)
    }
    
    /// Formatage monétaire
    /// - Parameter currency: Symbole de devise (défaut: "€")
    /// - Returns: String formaté (ex: "1 234.56 €")
    func formattedCurrency(currency: String = "€") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = " "
        formatter.usesGroupingSeparator = true
        
        if let formatted = formatter.string(from: NSNumber(value: self)) {
            return "\(formatted) \(currency)"
        }
        return String(format: "%.2f %@", self, currency)
    }
}

extension Int {
    /// Formatage avec séparateur de milliers
    /// - Returns: String formaté (ex: "1 234")
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
