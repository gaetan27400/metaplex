//
//  VMCOscillatorModels.swift
//  Journal de trading 2025
//
//  Modèles pour le VMC Oscillator (graphique série temporelle)
//

import SwiftUI

// MARK: - VMC Oscillator Reading

struct VMCOscillatorReading: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let sig: Double
    let sigSignal: Double
    let momentum: Double
    let signal: VMCOscillatorSignal?
}

// MARK: - Signal VMC Oscillator

enum VMCOscillatorSignal: String, Equatable {
    case buy = "BUY"
    case sell = "SELL"
    case exitLong = "EXIT_LONG"
    case exitShort = "EXIT_SHORT"
    
    var color: Color {
        switch self {
        case .buy: return .green
        case .sell: return .red
        case .exitLong: return .orange
        case .exitShort: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .buy: return "arrowtriangle.up.fill"
        case .sell: return "arrowtriangle.down.fill"
        case .exitLong: return "xmark.circle.fill"
        case .exitShort: return "xmark.circle.fill"
        }
    }
}

// MARK: - VMC Oscillator Snapshot

struct VMCOscillatorSnapshot: Identifiable, Equatable {
    let id = UUID()
    let readings: [VMCOscillatorReading]
    let currentSig: Double
    let currentSigSignal: Double
    let currentMomentum: Double
    let currentSignal: VMCOscillatorSignal?
    let ribbonBull: Bool
    let ribbonBear: Bool
    let compression: Bool
    let upperThreshold: Double
    let lowerThreshold: Double
    
    var isOverbought: Bool { currentSig > upperThreshold }
    var isOversold: Bool { currentSig < lowerThreshold }
    
    var statusText: String {
        if let signal = currentSignal { return signal.rawValue }
        if isOverbought { return "OVERBOUGHT" }
        if isOversold { return "OVERSOLD" }
        return "NEUTRAL"
    }
    
    var statusColor: Color {
        if let signal = currentSignal { return signal.color }
        if isOverbought { return .red }
        if isOversold { return .green }
        return .gray
    }
}
