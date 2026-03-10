//
//  ColorExtensions.swift
//  Journal de trading 2025
//
//  Extensions utilitaires pour Color
//

import SwiftUI

extension Color {
    /// Retourne une chaîne hexadécimale #RRGGBB pour la couleur
    func toHex() -> String? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        guard let components = uiColor.cgColor.components else { return nil }
        let r = Int((components.count > 0 ? components[0] : 0) * 255.0)
        let g = Int((components.count > 1 ? components[1] : 0) * 255.0)
        let b = Int((components.count > 2 ? components[2] : 0) * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return nil
        #endif
    }
    /// Initialise une couleur à partir d'une chaîne hexadécimale
    /// - Parameter hex: Chaîne hexadécimale (ex: "#FF0000", "FF0000", "#FF0000FF")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Couleurs prédéfinies pour l'application
    static let tradingGreen = Color(hex: "#4ECDC4")
    static let tradingRed = Color(hex: "#FF6B6B")
    // Accent conservé du thème initial
    static let tradingBlue = Color(hex: "#00D9FF")
    static let tradingYellow = Color(hex: "#FFE66D")
    static let tradingPurple = Color(hex: "#A8E6CF")

    // Surfaces pro (dark)
    static let surface1 = Color.black
    static let surface2 = Color.white.opacity(0.06)
    static let surface3 = Color.white.opacity(0.12)
    static let separator = Color.white.opacity(0.08)
}

// MARK: - Haptics
import UIKit
enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
