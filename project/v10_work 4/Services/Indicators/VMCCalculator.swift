//
//  VMCCalculator.swift
//  Journal de trading 2025
//
//  Service de calcul VMC (Volume Momentum Convergence) multi-timeframe
//

import Foundation

// MARK: - Extension Candle pour compatibilité

extension Candle {
    var toOHLC: OHLC {
        OHLC(
            open: self.open,
            high: self.high,
            low: self.low,
            close: self.close,
            volume: self.volume,
            timestamp: Date(timeIntervalSince1970: self.openTime)
        )
    }
}

// MARK: - OHLC Structure (pour compatibilité)

struct OHLC {
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
    let timestamp: Date
}

// MARK: - VMC Calculator

final class VMCCalculator {
    
    // MARK: - Configuration
    
    struct Config {
        var vmcLength: Int = 7
        var vmcSmoothing: Int = 3
        var upperThreshold: Double = 35
        var lowerThreshold: Double = -25
        var globalBuyThreshold: Double = -20
        var globalSellThreshold: Double = 30
        var minExtremeTFPercent: Double = 60
        var weightMethod: WeightMethod = .rawMinutes
    }
    
    // MARK: - Calcul VMC pour un timeframe
    
    /// Calcule la valeur VMC pour une série de prix OHLC (selon le Pine Script)
    static func calculateVMC(
        prices: [OHLC],
        length: Int = 7,
        smoothing: Int = 3
    ) -> Double? {
        guard prices.count >= length else { return nil }
        
        // Calculer hl2 pour toutes les bougies
        let hl2 = prices.map { ($0.high + $0.low) / 2.0 }
        
        // Calculer les valeurs VMC pour chaque barre
        var vmcValues: [Double] = []
        
        for i in (length - 1)..<prices.count {
            // Fenêtre glissante pour cette barre
            let window = Array(prices[(i - length + 1)...i])
            let windowHighs = window.map(\.high)
            let windowLows = window.map(\.low)
            let windowHL2 = Array(hl2[(i - length + 1)...i])
            
            // ta.highest(high, length) et ta.lowest(low, length)
            let hi = windowHighs.max() ?? 0
            let lo = windowLows.min() ?? 0
            
            // ta.sma(hl2, length)
            let av = windowHL2.reduce(0, +) / Double(windowHL2.count)
            
            // (close - math.avg(hi, lo, av)) / (hi - lo) * 100
            let currentClose = prices[i].close
            let denominator = hi - lo
            guard denominator != 0 else {
                vmcValues.append(0)
                continue
            }
            
            let rawValue = ((currentClose - (hi + lo + av) / 3.0) / denominator) * 100.0
            vmcValues.append(rawValue)
        }
        
        // Linear regression sur les valeurs brutes
        guard vmcValues.count >= length else { return nil }
        let linreg = linearRegression(source: vmcValues, length: length)
        
        // EMA smoothing
        let smoothed = ema(linreg, length: smoothing)
        
        return smoothed.last
    }
    
    // MARK: - Calcul VMC Global
    
    /// Calcule le score VMC global pondéré à partir des readings de chaque timeframe
    static func calculateGlobalVMC(
        readings: [VMCTimeframe: Double],
        method: WeightMethod = .rawMinutes
    ) -> Double {
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (tf, value) in readings {
            let weight = method == .rawMinutes 
                ? tf.minutes 
                : log(tf.minutes)
            weightedSum += value * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : 0
    }
    
    // MARK: - Création d'un VMCSnapshot complet
    
    /// Crée un snapshot VMC complet avec tous les timeframes (utilise Candle)
    static func createSnapshot(
        symbol: String,
        candlesByTimeframe: [VMCTimeframe: [Candle]],
        previousGlobalScore: Double? = nil,
        config: Config = Config()
    ) -> VMCSnapshot {
        // Convertir Candle en OHLC
        let ohlcByTimeframe = candlesByTimeframe.mapValues { $0.map { $0.toOHLC } }
        return createSnapshotFromOHLC(
            symbol: symbol,
            candlesByTimeframe: ohlcByTimeframe,
            previousGlobalScore: previousGlobalScore,
            config: config
        )
    }
    
    /// Crée un snapshot VMC complet avec tous les timeframes (utilise OHLC)
    private static func createSnapshotFromOHLC(
        symbol: String,
        candlesByTimeframe: [VMCTimeframe: [OHLC]],
        previousGlobalScore: Double? = nil,
        config: Config = Config()
    ) -> VMCSnapshot {
        var readings: [VMCTimeframe: VMCReading] = [:]
        var vmcValues: [VMCTimeframe: Double] = [:]
        var activeTFCount = 0
        var extremeLowCount = 0
        var extremeHighCount = 0
        
        // Calculer VMC pour chaque timeframe
        for tf in VMCTimeframe.allCases {
            guard let candles = candlesByTimeframe[tf],
                  !candles.isEmpty,
                  let vmcValue = calculateVMC(
                      prices: candles,
                      length: config.vmcLength,
                      smoothing: config.vmcSmoothing
                  ) else {
                continue
            }
            
            vmcValues[tf] = vmcValue
            activeTFCount += 1
            
            if vmcValue < config.lowerThreshold {
                extremeLowCount += 1
            }
            if vmcValue > config.upperThreshold {
                extremeHighCount += 1
            }
            
            readings[tf] = VMCReading(
                symbol: symbol,
                timeframe: tf,
                value: vmcValue,
                upperThreshold: config.upperThreshold,
                lowerThreshold: config.lowerThreshold
            )
        }
        
        // Calculer le score global
        let globalScore = calculateGlobalVMC(
            readings: vmcValues,
            method: config.weightMethod
        )
        
        // Calculer les pourcentages d'extrêmes
        let extremeLowPercent = activeTFCount > 0 
            ? (Double(extremeLowCount) / Double(activeTFCount)) * 100 
            : 0
        let extremeHighPercent = activeTFCount > 0 
            ? (Double(extremeHighCount) / Double(activeTFCount)) * 100 
            : 0
        
        // Détecter les changements de direction
        let isTurningUp = if let prev = previousGlobalScore {
            globalScore > prev
        } else { false }
        
        let isTurningDown = if let prev = previousGlobalScore {
            globalScore < prev
        } else { false }
        
        // Déterminer le signal global
        let globalSignal: VMCGlobalSignal
        if globalScore < config.globalBuyThreshold 
            && extremeLowPercent >= config.minExtremeTFPercent 
            && isTurningUp {
            globalSignal = .buy
        } else if globalScore > config.globalSellThreshold 
            && extremeHighPercent >= config.minExtremeTFPercent 
            && isTurningDown {
            globalSignal = .sell
        } else {
            globalSignal = .neutral
        }
        
        return VMCSnapshot(
            symbol: symbol,
            timestamp: Date(),
            readings: readings,
            globalScore: globalScore,
            globalSignal: globalSignal,
            extremeLowPercent: extremeLowPercent,
            extremeHighPercent: extremeHighPercent,
            isTurningUp: isTurningUp,
            isTurningDown: isTurningDown
        )
    }
    
    // MARK: - Helper Functions
    
    /// Linear regression
    private static func linearRegression(source: [Double], length: Int) -> [Double] {
        guard source.count >= length else { return source }
        
        var result: [Double] = []
        for i in (length-1)..<source.count {
            let window = Array(source[(i-length+1)...i])
            let n = Double(window.count)
            
            let sumX = n * (n + 1) / 2.0
            let sumY = window.reduce(0, +)
            let sumXY = window.enumerated().map { Double($0.offset + 1) * $0.element }.reduce(0, +)
            let sumX2 = n * (n + 1) * (2 * n + 1) / 6.0
            
            let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
            let intercept = (sumY - slope * sumX) / n
            
            result.append(slope * Double(length) + intercept)
        }
        return result
    }
    
    /// Exponential Moving Average
    private static func ema(_ values: [Double], length: Int) -> [Double] {
        guard length > 0, !values.isEmpty else { return values }
        let k = 2.0 / (Double(length) + 1.0)
        var result = [values[0]]
        for i in 1..<values.count {
            result.append(values[i] * k + result[i-1] * (1 - k))
        }
        return result
    }
}
