//
//  MTFCombiner.swift
//  Journal de trading 2025
//
//  Service pour combiner RSI et VMC en un modèle MTF unifié
//

import Foundation

final class MTFCombiner {
    
    // MARK: - Normalisation RSI
    
    /// Normalise RSI (0-100) vers [-100, +100]
    static func normalizeRSI(_ rsi: Double) -> Double {
        switch rsi {
        case ..<30:
            // Oversold : mapping linéaire 0-30 → -100 à -40
            return -100 + ((rsi - 0) / 30) * 60
        case 30..<50:
            // 30-50 : mapping linéaire -40 à 0
            return -40 + ((rsi - 30) / 20) * 40
        case 50..<70:
            // 50-70 : mapping linéaire 0 à +40
            return 0 + ((rsi - 50) / 20) * 40
        default:
            // Overbought : mapping linéaire 70-100 → +40 à +100
            return 40 + ((rsi - 70) / 30) * 60
        }
    }
    
    /// Détermine le statut RSI à partir de la valeur normalisée
    static func rsiStatus(normalized: Double) -> SignalStatus {
        switch normalized {
        case ..<(-40): return .buy
        case -40..<(-10): return .bullish
        case -10...10: return .neutral
        case 10..<40: return .bearish
        default: return .sell
        }
    }
    
    // MARK: - Score Combiné
    
    /// Calcule le score combiné (RSI 40%, VMC 60%)
    /// - Parameters:
    ///   - rsiNormalized: RSI normalisé [-100, +100]
    ///   - vmc: VMC brut [-100, +100]
    /// - Returns: Score combiné [-100, +100]
    static func combinedScore(rsiNormalized: Double, vmc: Double) -> Double {
        return (rsiNormalized * 0.4) + (vmc * 0.6)
    }
    
    /// Détermine le signal combiné à partir du score
    static func combinedSignal(score: Double) -> SignalStatus {
        switch score {
        case ..<(-40): return .buy
        case -40..<(-10): return .bullish
        case -10...10: return .neutral
        case 10..<40: return .bearish
        default: return .sell
        }
    }
    
    // MARK: - Conversion VMC Status
    
    /// Convertit VMCStatus en SignalStatus
    static func vmcStatusToSignal(_ vmcStatus: VMCStatus) -> SignalStatus {
        switch vmcStatus {
        case .strongBuy: return .buy
        case .buy: return .bullish
        case .neutral: return .neutral
        case .sell: return .bearish
        case .strongSell: return .sell
        }
    }
    
    /// Convertit RSIStatus en SignalStatus
    static func rsiStatusToSignal(_ rsiStatus: RSIStatus) -> SignalStatus {
        switch rsiStatus {
        case .strongBuy: return .buy
        case .buy: return .bullish
        case .neutral: return .neutral
        case .sell: return .bearish
        case .strongSell: return .sell
        }
    }
    
    // MARK: - Création MTF Reading
    
    /// Crée un MTFReading à partir d'un RSIReading et d'un VMCReading
    static func createMTFReading(
        timeframe: VMCTimeframe,
        rsiReading: RSIReading?,
        vmcReading: VMCReading?
    ) -> MTFReading? {
        // Au moins un des deux doit être présent
        guard rsiReading != nil || vmcReading != nil else { return nil }
        
        // RSI
        let rsiValue = rsiReading?.value ?? 50.0
        let rsiNormalized = normalizeRSI(rsiValue)
        let rsiStatus = rsiReading != nil ? rsiStatusToSignal(rsiReading!.status) : .neutral
        let isRSIOversold = rsiReading?.isOversold ?? false
        let isRSIOverbought = rsiReading?.isOverbought ?? false
        
        // VMC
        let vmcValue = vmcReading?.value ?? 0.0
        let vmcStatus = vmcReading != nil ? vmcStatusToSignal(vmcReading!.status) : .neutral
        let isVMCExtremeLow = vmcReading != nil && vmcValue < -25
        let isVMCExtremeHigh = vmcReading != nil && vmcValue > 35
        
        // Score combiné
        let combinedScore = combinedScore(rsiNormalized: rsiNormalized, vmc: vmcValue)
        let combinedSignal = combinedSignal(score: combinedScore)
        
        return MTFReading(
            timeframe: timeframe,
            rsiValue: rsiValue,
            rsiStatus: rsiStatus,
            rsiNormalized: rsiNormalized,
            vmcValue: vmcValue,
            vmcStatus: vmcStatus,
            combinedScore: combinedScore,
            combinedSignal: combinedSignal,
            isRSIOversold: isRSIOversold,
            isRSIOverbought: isRSIOverbought,
            isVMCExtremeLow: isVMCExtremeLow,
            isVMCExtremeHigh: isVMCExtremeHigh
        )
    }
    
    // MARK: - Création MTF Snapshot
    
    /// Combine un RSISnapshot et un VMCSnapshot en un MTFSnapshot
    static func createMTFSnapshot(
        symbol: String,
        rsiSnapshot: RSISnapshot,
        vmcSnapshot: VMCSnapshot
    ) -> MTFSnapshot {
        var readings: [VMCTimeframe: MTFReading] = [:]
        
        // Combiner les readings pour chaque timeframe
        for tf in VMCTimeframe.allCases {
            let rsiReading = rsiSnapshot.readings[tf]
            let vmcReading = vmcSnapshot.readings[tf]
            
            if let mtfReading = createMTFReading(
                timeframe: tf,
                rsiReading: rsiReading,
                vmcReading: vmcReading
            ) {
                readings[tf] = mtfReading
            }
        }
        
        // Calculer scores globaux
        let globalRSI = rsiSnapshot.globalRSI
        let globalVMC = vmcSnapshot.globalScore
        let globalRSINormalized = normalizeRSI(globalRSI)
        let globalCombinedScore = combinedScore(rsiNormalized: globalRSINormalized, vmc: globalVMC)
        let globalSignal = combinedSignal(score: globalCombinedScore)
        
        // Calculer pourcentages d'extrêmes (basé sur le score combiné)
        let activeCount = Double(readings.count)
        var extremeLowCount = 0
        var extremeHighCount = 0
        var alignedCount = 0 // RSI et VMC pointent dans la même direction
        
        for reading in readings.values {
            if reading.combinedScore < -40 {
                extremeLowCount += 1
            }
            if reading.combinedScore > 40 {
                extremeHighCount += 1
            }
            
            // Vérifier alignement RSI/VMC
            let rsiDirection = reading.rsiNormalized > 0
            let vmcDirection = reading.vmcValue > 0
            if rsiDirection == vmcDirection {
                alignedCount += 1
            }
        }
        
        let extremeLowPercent = activeCount > 0 ? (Double(extremeLowCount) / activeCount) * 100 : 0
        let extremeHighPercent = activeCount > 0 ? (Double(extremeHighCount) / activeCount) * 100 : 0
        let confluencePercent = activeCount > 0 ? (Double(alignedCount) / activeCount) * 100 : 0
        
        // Détecter tendance
        let isTurningUp = rsiSnapshot.isTurningUp || vmcSnapshot.isTurningUp
        let isTurningDown = rsiSnapshot.isTurningDown || vmcSnapshot.isTurningDown
        
        return MTFSnapshot(
            symbol: symbol,
            timestamp: Date(),
            readings: readings,
            globalRSI: globalRSI,
            globalVMC: globalVMC,
            globalCombinedScore: globalCombinedScore,
            globalSignal: globalSignal,
            extremeLowPercent: extremeLowPercent,
            extremeHighPercent: extremeHighPercent,
            isTurningUp: isTurningUp,
            isTurningDown: isTurningDown,
            confluencePercent: confluencePercent
        )
    }
}
