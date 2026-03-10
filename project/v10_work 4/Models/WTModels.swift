//
//  WTModels.swift
//  Journal de trading 2025
//
//  Modèles de données pour l'oscillateur Wave Trend
//

import Foundation
import SwiftUI

// MARK: - Wave Trend Signal

enum WTSignal: String, Codable {
    case bullishReversal = "BULLISH_REVERSAL"
    case bearishReversal = "BEARISH_REVERSAL"
    case bullishSmartReversal = "BULLISH_SMART_REVERSAL"
    case bearishSmartReversal = "BEARISH_SMART_REVERSAL"
    case neutral = "NEUTRAL"
    
    var displayName: String {
        switch self {
        case .bullishReversal: return "Bullish Reversal"
        case .bearishReversal: return "Bearish Reversal"
        case .bullishSmartReversal: return "Smart Bullish"
        case .bearishSmartReversal: return "Smart Bearish"
        case .neutral: return "Neutral"
        }
    }
    
    var color: Color {
        switch self {
        case .bullishReversal, .bullishSmartReversal: return .cyan
        case .bearishReversal, .bearishSmartReversal: return .pink
        case .neutral: return .gray
        }
    }
}

// MARK: - Divergence Type

enum WTDivergenceType: String, Codable {
    case regularBullish = "REGULAR_BULLISH"
    case regularBearish = "REGULAR_BEARISH"
    case hiddenBullish = "HIDDEN_BULLISH"
    case hiddenBearish = "HIDDEN_BEARISH"
    
    var displayName: String {
        switch self {
        case .regularBullish: return "Bull"
        case .regularBearish: return "Bear"
        case .hiddenBullish: return "cachée"
        case .hiddenBearish: return "cachée"
        }
    }
    
    var color: Color {
        switch self {
        case .regularBullish, .hiddenBullish: return Color(hex: "#2962ff")
        case .regularBearish, .hiddenBearish: return Color(hex: "#e91e62")
        }
    }
}

// MARK: - Market Bias (Heikin Ashi)

enum MarketBias: String, Codable {
    case bullish = "BULLISH"
    case bearish = "BEARISH"
    case neutral = "NEUTRAL"
    
    var displayName: String {
        switch self {
        case .bullish: return "Haussier"
        case .bearish: return "Baissier"
        case .neutral: return "Neutre"
        }
    }
    
    var color: Color {
        switch self {
        case .bullish: return Color(hex: "#18e0ff")
        case .bearish: return Color(hex: "#e91e62")
        case .neutral: return .gray
        }
    }
}

// MARK: - Momentum Direction

enum MomentumDirection: String, Codable {
    case growing = "GROWING"
    case falling = "FALLING"
    
    var displayName: String {
        switch self {
        case .growing: return "▲ Growing"
        case .falling: return "▼ Falling"
        }
    }
    
    var color: Color {
        switch self {
        case .growing: return Color(hex: "#1a7b24")
        case .falling: return Color(hex: "#be0606")
        }
    }
}

// MARK: - WT Reading (point de données)

struct WTReading: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    
    // Wave Trend values
    let wt1: Double
    let wt2: Double
    let histogram: Double // WT1 - WT2
    
    // Direction
    let direction: Int // 1 = up, -1 = down, 0 = neutral
    
    // Signals
    let signal: WTSignal?
    let hasDivergence: Bool
    let divergenceType: WTDivergenceType?
    
    // Market Bias (Heikin Ashi)
    let marketBias: MarketBias
    let biasStrength: Double // 0-100
    
    // Momentum MisterMota
    let momentum: Double
    let momentumDirection: MomentumDirection
    let momentumAngle: Double // Angle en degrés
}

// MARK: - Signal Quality (optionnel, léger)

struct WTSignalQuality: Equatable {
    let score: Double // 0-100
    let factors: [QualityFactor]
    
    enum QualityFactor: String, Equatable {
        case strongDivergence = "divergence"
        case extremeZone = "extreme"
        case trendAlignment = "trend"
    }
    
    var recommendation: String {
        switch score {
        case 80...100: return "Fort"
        case 60..<80: return "Modéré"
        case 40..<60: return "Faible"
        default: return "Très faible"
        }
    }
}

// MARK: - WT Snapshot (vue globale)

struct WTSnapshot: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let timestamp: Date
    
    // Readings (historique)
    let readings: [WTReading]
    
    // Valeurs actuelles
    let currentWT1: Double
    let currentWT2: Double
    let currentHistogram: Double
    
    // Signaux
    let currentSignal: WTSignal?
    let hasActiveDivergence: Bool
    let activeDivergenceType: WTDivergenceType?
    
    // Market Bias
    let currentMarketBias: MarketBias
    let biasStrength: Double
    
    // Momentum
    let currentMomentum: Double
    let momentumDirection: MomentumDirection
    let momentumAngle: Double
    
    // Zones
    let isOverbought: Bool
    let isOversold: Bool
    let overboughtLevel: Double
    let oversoldLevel: Double
    
    // Score de qualité (optionnel)
    let signalQuality: WTSignalQuality?
}

// MARK: - WT Timeframe

enum WTTimeframe: String, Codable, CaseIterable, Hashable, Identifiable {
    case m1 = "1m"
    case m3 = "3m"
    case m5 = "5m"
    case m15 = "15m"
    case m30 = "30m"
    case m45 = "45m"
    case h1 = "1h"
    case h2 = "2h"
    case h3 = "3h"
    case h4 = "4h"
    case h6 = "6h"
    case h8 = "8h"
    case h12 = "12h"
    case d1 = "1d"
    case d3 = "3d"
    case w1 = "1w"
    case month1 = "1M"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .m1: return "1m"
        case .m3: return "3m"
        case .m5: return "5m"
        case .m15: return "15m"
        case .m30: return "30m"
        case .m45: return "45m"
        case .h1: return "1h"
        case .h2: return "2h"
        case .h3: return "3h"
        case .h4: return "4h"
        case .h6: return "6h"
        case .h8: return "8h"
        case .h12: return "12h"
        case .d1: return "1d"
        case .d3: return "3d"
        case .w1: return "1w"
        case .month1: return "1M"
        }
    }
    
    var binanceInterval: String {
        // Mapper les timeframes vers les intervalles Binance supportés
        switch self {
        case .m1: return "1m"
        case .m3: return "3m" // Supporté par Binance
        case .m5: return "5m"
        case .m15: return "15m"
        case .m30: return "30m"
        case .m45: return "45m" // Supporté par Binance
        case .h1: return "1h"
        case .h2: return "2h"
        case .h3: return "3h" // Supporté par Binance
        case .h4: return "4h"
        case .h6: return "6h"
        case .h8: return "8h" // Supporté par Binance
        case .h12: return "12h"
        case .d1: return "1d"
        case .d3: return "3d" // Supporté par Binance
        case .w1: return "1w"
        case .month1: return "1M"
        }
    }
    
    var category: TimeframeCategory {
        switch self {
        case .m1, .m3, .m5, .m15, .m30, .m45:
            return .minutes
        case .h1, .h2, .h3, .h4, .h6, .h8, .h12:
            return .hours
        case .d1, .d3:
            return .days
        case .w1:
            return .weeks
        case .month1:
            return .months
        }
    }
    
    static let `default`: WTTimeframe = .h1
    
    // Timeframes disponibles pour les notifications (tous sont supportés par Binance)
    static let notificationTimeframes: [WTTimeframe] = allCases
}

enum TimeframeCategory: String {
    case minutes = "Minutes"
    case hours = "Heures"
    case days = "Jours"
    case weeks = "Semaines"
    case months = "Mois"
}

// MARK: - WT Config

struct WTConfig {
    let channelLength: Int // n1 (default: 10)
    let averageLength: Int // n2 (default: 21)
    let reactionWT: Int // reaction_wt (default: 1)
    let overboughtLevel1: Double // obLevel1 (default: 60)
    let overboughtLevel2: Double // obLevel2 (default: 53)
    let oversoldLevel1: Double // osLevel1 (default: -60)
    let oversoldLevel2: Double // osLevel2 (default: -53)
    let onlySmartBuyReversal: Bool // Buy_sales (default: true)
    let onlySmartSellReversal: Bool // Sell_sales (default: true)
    
    // Heikin Ashi
    let haPeriod: Int // ha_len (default: 7)
    let haSmoothing: Int // ha_len2 (default: 10)
    
    // Momentum MisterMota
    let momentumResponsiveness: Double // responsiveness (default: 0.9)
    let momentumPeriod: Int // periodd (default: 50)
    
    static let `default` = WTConfig(
        channelLength: 10,
        averageLength: 21,
        reactionWT: 1,
        overboughtLevel1: 60,
        overboughtLevel2: 53,
        oversoldLevel1: -60,
        oversoldLevel2: -53,
        onlySmartBuyReversal: true,
        onlySmartSellReversal: true,
        haPeriod: 7,
        haSmoothing: 10,
        momentumResponsiveness: 0.9,
        momentumPeriod: 50
    )
}
