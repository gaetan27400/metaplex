//
//  MTFReading.swift
//  Journal de trading 2025
//
//  Modèle commun pour lecture Multi-Timeframe combinant RSI et VMC
//

import Foundation
import SwiftUI

// MARK: - Signal Status (commun)

enum SignalStatus: String, Codable {
    case buy = "BUY"
    case bullish = "BULLISH"
    case neutral = "NEUTRAL"
    case bearish = "BEARISH"
    case sell = "SELL"
    
    var displayName: String {
        switch self {
        case .buy: return "ACHETER"
        case .bullish: return "BAISSIER"
        case .neutral: return "NEUTRE"
        case .bearish: return "HAUSSIER"
        case .sell: return "VENDRE"
        }
    }
    
    var color: Color {
        switch self {
        case .buy: return .green
        case .bullish: return Color.yellow.opacity(0.7)
        case .neutral: return .gray
        case .bearish: return .orange
        case .sell: return .red
        }
    }
}

// MARK: - MTF Reading (modèle commun)

struct MTFReading: Identifiable, Equatable {
    let id = UUID()
    let timeframe: VMCTimeframe
    
    // RSI (brut 0-100)
    let rsiValue: Double
    let rsiStatus: SignalStatus
    let rsiNormalized: Double // Normalisé [-100, +100]
    
    // VMC (brut -100 à +100)
    let vmcValue: Double
    let vmcStatus: SignalStatus
    
    // Score combiné (pondéré)
    let combinedScore: Double // [-100, +100]
    let combinedSignal: SignalStatus
    
    // Métadonnées
    let isRSIOversold: Bool
    let isRSIOverbought: Bool
    let isVMCExtremeLow: Bool
    let isVMCExtremeHigh: Bool
    
    // Divergence (important pour le trading)
    var hasDivergence: Bool {
        // RSI et VMC pointent dans des directions opposées
        let rsiDirection = rsiNormalized > 0
        let vmcDirection = vmcValue > 0
        return rsiDirection != vmcDirection
    }
    
    var divergenceType: DivergenceType? {
        guard hasDivergence else { return nil }
        if rsiNormalized > 0 && vmcValue < 0 {
            return .rsiBullishVMCBearish // Piège haussier
        } else if rsiNormalized < 0 && vmcValue > 0 {
            return .rsiBearishVMCBullish // Absorption / bottom building
        }
        return nil
    }
}

enum DivergenceType {
    case rsiBullishVMCBearish // Piège haussier
    case rsiBearishVMCBullish // Absorption / bottom building
}

// MARK: - MTF Snapshot (global)

struct MTFSnapshot: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let timestamp: Date
    let readings: [VMCTimeframe: MTFReading]
    
    // Scores globaux
    let globalRSI: Double
    let globalVMC: Double
    let globalCombinedScore: Double
    let globalSignal: SignalStatus
    
    // Statistiques
    let extremeLowPercent: Double
    let extremeHighPercent: Double
    let isTurningUp: Bool
    let isTurningDown: Bool
    
    // Confluence (combien de timeframes sont alignés)
    let confluencePercent: Double // % de timeframes avec RSI et VMC alignés
}
