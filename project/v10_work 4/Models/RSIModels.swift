//
//  RSIModels.swift
//  Journal de trading 2025
//
//  Modèles de données pour l'indicateur RSI Dashboard MTF
//

import Foundation
import SwiftUI

// MARK: - RSI Status

enum RSIStatus: String, Codable {
    case strongBuy = "ACHETER"
    case buy = "BAISSIER"
    case neutral = "NEUTRE"
    case sell = "HAUSSIER"
    case strongSell = "VENDRE"
    
    var color: Color {
        switch self {
        case .strongBuy: return .green
        case .buy: return Color.yellow.opacity(0.7)
        case .neutral: return .gray
        case .sell: return .orange
        case .strongSell: return .red
        }
    }
    
    static func from(
        value: Double,
        overboughtLevel: Double = 70,
        oversoldLevel: Double = 30,
        bottomCatch: Bool = false
    ) -> RSIStatus {
        if bottomCatch || value < oversoldLevel {
            return value < oversoldLevel ? .strongBuy : .buy
        } else if value > overboughtLevel {
            return .strongSell
        } else if value > 50 {
            return .sell
        } else if value < 50 {
            return .buy
        } else {
            return .neutral
        }
    }
}

// MARK: - RSI Reading

struct RSIReading: Codable, Identifiable, Equatable {
    let id: UUID
    let symbol: String
    let timestamp: Date
    let timeframe: VMCTimeframe // Réutiliser les mêmes timeframes
    let value: Double // 0-100
    let status: RSIStatus
    let isBottomCatch: Bool
    let isOverbought: Bool
    let isOversold: Bool
    
    init(
        id: UUID = UUID(),
        symbol: String,
        timestamp: Date = Date(),
        timeframe: VMCTimeframe,
        value: Double,
        overboughtLevel: Double = 70,
        oversoldLevel: Double = 30,
        bottomCatch: Bool = false
    ) {
        self.id = id
        self.symbol = symbol
        self.timestamp = timestamp
        self.timeframe = timeframe
        self.value = value
        self.isBottomCatch = bottomCatch
        self.isOverbought = value > overboughtLevel
        self.isOversold = value < oversoldLevel
        self.status = RSIStatus.from(
            value: value,
            overboughtLevel: overboughtLevel,
            oversoldLevel: oversoldLevel,
            bottomCatch: bottomCatch
        )
    }
}

// MARK: - RSI Global Signal

enum RSIGlobalSignal: String, Codable {
    case buy = "BUY"
    case sell = "SELL"
    case neutral = "NEUTRAL"
    
    var color: Color {
        switch self {
        case .buy: return .green
        case .sell: return .red
        case .neutral: return .gray
        }
    }
    
    var displayName: String {
        switch self {
        case .buy: return "ACHETER"
        case .sell: return "VENDRE"
        case .neutral: return "NEUTRE"
        }
    }
}

// MARK: - RSI Snapshot

struct RSISnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    let symbol: String
    let timestamp: Date
    let readings: [VMCTimeframe: RSIReading]
    let globalRSI: Double // 0-100
    let globalSignal: RSIGlobalSignal
    let extremeLowPercent: Double
    let extremeHighPercent: Double
    let isTurningUp: Bool
    let isTurningDown: Bool
    
    init(
        id: UUID = UUID(),
        symbol: String,
        timestamp: Date = Date(),
        readings: [VMCTimeframe: RSIReading],
        globalRSI: Double,
        globalSignal: RSIGlobalSignal,
        extremeLowPercent: Double = 0,
        extremeHighPercent: Double = 0,
        isTurningUp: Bool = false,
        isTurningDown: Bool = false
    ) {
        self.id = id
        self.symbol = symbol
        self.timestamp = timestamp
        self.readings = readings
        self.globalRSI = globalRSI
        self.globalSignal = globalSignal
        self.extremeLowPercent = extremeLowPercent
        self.extremeHighPercent = extremeHighPercent
        self.isTurningUp = isTurningUp
        self.isTurningDown = isTurningDown
    }
}
