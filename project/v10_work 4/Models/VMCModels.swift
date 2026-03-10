//
//  VMCModels.swift
//  Journal de trading 2025
//
//  Modèles de données pour l'indicateur VMC Dashboard MTF
//

import Foundation
import SwiftUI

// MARK: - Timeframes VMC

enum VMCTimeframe: String, Codable, CaseIterable, Hashable {
    case m1 = "1"
    case m5 = "5"
    case m15 = "15"
    case m30 = "30"
    case h1 = "60"
    case h2 = "120"
    case h4 = "240"
    case h12 = "720"
    case d1 = "D"
    case w1 = "W"
    case month1 = "M"
    
    var displayName: String {
        switch self {
        case .m1: return "1Min"
        case .m5: return "5Min"
        case .m15: return "15Min"
        case .m30: return "30Min"
        case .h1: return "1H"
        case .h2: return "2H"
        case .h4: return "4H"
        case .h12: return "12H"
        case .d1: return "1J"
        case .w1: return "1S"
        case .month1: return "1M"
        }
    }
    
    var minutes: Double {
        switch self {
        case .m1: return 1
        case .m5: return 5
        case .m15: return 15
        case .m30: return 30
        case .h1: return 60
        case .h2: return 120
        case .h4: return 240
        case .h12: return 720
        case .d1: return 1440
        case .w1: return 10080
        case .month1: return 43200
        }
    }
    
    var binanceInterval: String {
        switch self {
        case .m1: return "1m"
        case .m5: return "5m"
        case .m15: return "15m"
        case .m30: return "30m"
        case .h1: return "1h"
        case .h2: return "2h"
        case .h4: return "4h"
        case .h12: return "12h"
        case .d1: return "1d"
        case .w1: return "1w"
        case .month1: return "1M"
        }
    }
}

// MARK: - Status VMC

enum VMCStatus: String, Codable {
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
    
    static func from(value: Double, upperThreshold: Double = 35, lowerThreshold: Double = -25) -> VMCStatus {
        if value > upperThreshold {
            return .strongSell
        } else if value < lowerThreshold {
            return .strongBuy
        } else if value > 0 {
            return .sell
        } else if value < 0 {
            return .buy
        } else {
            return .neutral
        }
    }
}

// MARK: - VMC Reading

struct VMCReading: Codable, Identifiable, Equatable {
    let id: UUID
    let symbol: String
    let timestamp: Date
    let timeframe: VMCTimeframe
    let value: Double // -100 to +100
    let status: VMCStatus
    
    init(id: UUID = UUID(), symbol: String, timestamp: Date = Date(), timeframe: VMCTimeframe, value: Double, upperThreshold: Double = 35, lowerThreshold: Double = -25) {
        self.id = id
        self.symbol = symbol
        self.timestamp = timestamp
        self.timeframe = timeframe
        self.value = value
        self.status = VMCStatus.from(value: value, upperThreshold: upperThreshold, lowerThreshold: lowerThreshold)
    }
}

// MARK: - VMC Global Signal

enum VMCGlobalSignal: String, Codable {
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

// MARK: - VMC Snapshot

struct VMCSnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    let symbol: String
    let timestamp: Date
    let readings: [VMCTimeframe: VMCReading]
    let globalScore: Double
    let globalSignal: VMCGlobalSignal
    let extremeLowPercent: Double
    let extremeHighPercent: Double
    let isTurningUp: Bool
    let isTurningDown: Bool
    
    init(
        id: UUID = UUID(),
        symbol: String,
        timestamp: Date = Date(),
        readings: [VMCTimeframe: VMCReading],
        globalScore: Double,
        globalSignal: VMCGlobalSignal,
        extremeLowPercent: Double = 0,
        extremeHighPercent: Double = 0,
        isTurningUp: Bool = false,
        isTurningDown: Bool = false
    ) {
        self.id = id
        self.symbol = symbol
        self.timestamp = timestamp
        self.readings = readings
        self.globalScore = globalScore
        self.globalSignal = globalSignal
        self.extremeLowPercent = extremeLowPercent
        self.extremeHighPercent = extremeHighPercent
        self.isTurningUp = isTurningUp
        self.isTurningDown = isTurningDown
    }
}

// MARK: - Weight Method

enum WeightMethod: String, Codable {
    case rawMinutes = "Raw Minutes"
    case logarithmic = "Logarithmic"
}
