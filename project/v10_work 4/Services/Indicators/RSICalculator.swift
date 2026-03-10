//
//  RSICalculator.swift
//  Journal de trading 2025
//
//  Service de calcul RSI (Relative Strength Index) multi-timeframe
//

import Foundation

// MARK: - RSI Calculator

final class RSICalculator {
    
    // MARK: - Configuration
    
    struct Config {
        var rsiLength: Int = 14
        var overboughtLevel: Double = 70
        var oversoldLevel: Double = 30
        var globalBuyThreshold: Double = 35
        var globalSellThreshold: Double = 65
        var minExtremeTFPercent: Double = 60
        var weightMethod: WeightMethod = .rawMinutes
    }
    
    // MARK: - Calcul RSI
    
    /// Calcule le RSI pour une série de prix (méthode de Wilder)
    static func calculateRSI(
        prices: [Double],
        length: Int = 14
    ) -> Double? {
        guard prices.count > length + 1 else { return nil }
        
        var gains: [Double] = []
        var losses: [Double] = []
        
        // Calculer les gains et pertes
        for i in 1..<prices.count {
            let change = prices[i] - prices[i-1]
            gains.append(max(change, 0))
            losses.append(max(-change, 0))
        }
        
        // Moyennes initiales (SMA)
        var avgGain = gains.prefix(length).reduce(0, +) / Double(length)
        var avgLoss = losses.prefix(length).reduce(0, +) / Double(length)
        
        // Appliquer le lissage de Wilder pour les valeurs suivantes
        for i in length..<gains.count {
            avgGain = (avgGain * Double(length - 1) + gains[i]) / Double(length)
            avgLoss = (avgLoss * Double(length - 1) + losses[i]) / Double(length)
        }
        
        guard avgLoss != 0 else { return 50.0 }
        
        let rs = avgGain / avgLoss
        return 100 - (100 / (1 + rs))
    }
    
    /// Calcule le RSI pour des bougies OHLC
    static func calculateRSI(
        candles: [OHLC],
        length: Int = 14
    ) -> Double? {
        let closes = candles.map(\.close)
        return calculateRSI(prices: closes, length: length)
    }
    
    /// Détecte un "Bottom Catch" (rebond depuis un bas)
    static func calculateBottomCatch(
        currentRSI: Double,
        previousRSI: Double,
        lowestRSI: Double,
        oversoldLevel: Double = 30
    ) -> Bool {
        let bc1 = currentRSI <= 40 && currentRSI > previousRSI
        let bc2 = currentRSI <= oversoldLevel && currentRSI > lowestRSI
        return bc1 || bc2
    }
    
    /// Calcule le RSI le plus bas sur N périodes
    static func lowestRSI(
        rsiValues: [Double],
        period: Int = 5
    ) -> Double? {
        guard rsiValues.count >= period else { return nil }
        return Array(rsiValues.suffix(period)).min()
    }
    
    // MARK: - Calcul Global RSI
    
    /// Calcule le RSI global pondéré à partir des readings multi-timeframe
    static func calculateGlobalRSI(
        readings: [VMCTimeframe: RSIReading],
        previousGlobalRSI: Double? = nil,
        weightMethod: WeightMethod = .rawMinutes
    ) -> Double {
        var weightedSum = 0.0
        var totalWeight = 0.0
        
        for (tf, reading) in readings {
            let weight = weightMethod == .rawMinutes ? tf.minutes : log(tf.minutes)
            weightedSum += reading.value * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : (previousGlobalRSI ?? 50.0)
    }
    
    /// Crée un snapshot RSI complet pour tous les timeframes
    static func createSnapshot(
        symbol: String,
        candlesByTimeframe: [VMCTimeframe: [Candle]],
        previousGlobalRSI: Double? = nil,
        config: Config = Config()
    ) -> RSISnapshot {
        var readings: [VMCTimeframe: RSIReading] = [:]
        var rsiValues: [VMCTimeframe: [Double]] = [:]
        
        // Calculer RSI pour chaque timeframe (comme le VMC calcule pour chaque timeframe)
        // Itérer sur tous les timeframes pour s'assurer qu'on calcule pour tous
        for tf in VMCTimeframe.allCases {
            guard let candles = candlesByTimeframe[tf],
                  !candles.isEmpty else {
                Logger.api.warning("No candles for timeframe \(tf.rawValue)")
                continue
            }
            
            let ohlc = candles.map { $0.toOHLC }
            let closes = ohlc.map(\.close)
            
            // Calculer RSI sur toute la série de prix
            guard closes.count > config.rsiLength + 1 else {
                Logger.api.warning("Not enough candles for RSI calculation on \(tf.rawValue): \(closes.count) < \(config.rsiLength + 1)")
                continue
            }
            
            // Calculer RSI progressivement pour avoir l'historique complet
            var timeframeRSIValues: [Double] = []
            for i in config.rsiLength..<closes.count {
                let slice = Array(closes[0...i]) // Depuis le début jusqu'à i (série croissante)
                if let rsi = calculateRSI(prices: slice, length: config.rsiLength) {
                    timeframeRSIValues.append(rsi)
                }
            }
            
            guard let currentRSI = timeframeRSIValues.last else {
                Logger.api.warning("Failed to calculate RSI for timeframe \(tf.rawValue)")
                continue
            }
            
            // Calculer bottom catch avec l'historique
            let previousRSI = timeframeRSIValues.count > 1 ? timeframeRSIValues[timeframeRSIValues.count - 2] : currentRSI
            let lowestRSI = lowestRSI(rsiValues: timeframeRSIValues, period: 5) ?? currentRSI
            let bottomCatch = calculateBottomCatch(
                currentRSI: currentRSI,
                previousRSI: previousRSI,
                lowestRSI: lowestRSI,
                oversoldLevel: config.oversoldLevel
            )
            
            // Créer reading
            let reading = RSIReading(
                symbol: symbol,
                timeframe: tf,
                value: currentRSI,
                overboughtLevel: config.overboughtLevel,
                oversoldLevel: config.oversoldLevel,
                bottomCatch: bottomCatch
            )
            
            readings[tf] = reading
            rsiValues[tf] = timeframeRSIValues
            
            Logger.api.info("RSI calculated for \(tf.rawValue): \(String(format: "%.1f", currentRSI))")
        }
        
        // Calculer RSI global
        let globalRSI = calculateGlobalRSI(
            readings: readings,
            previousGlobalRSI: previousGlobalRSI,
            weightMethod: config.weightMethod
        )
        
        // Calculer pourcentages d'extrêmes
        let activeCount = Double(readings.count)
        var extremeLowCount = 0
        var extremeHighCount = 0
        
        for reading in readings.values {
            if reading.isBottomCatch || reading.isOversold {
                extremeLowCount += 1
            }
            if reading.isOverbought {
                extremeHighCount += 1
            }
        }
        
        let extremeLowPercent = activeCount > 0 ? (Double(extremeLowCount) / activeCount) * 100 : 0
        let extremeHighPercent = activeCount > 0 ? (Double(extremeHighCount) / activeCount) * 100 : 0
        
        // Détecter tendance (simplifié : comparer avec la valeur précédente)
        let isTurningUp = previousGlobalRSI != nil && globalRSI > previousGlobalRSI!
        let isTurningDown = previousGlobalRSI != nil && globalRSI < previousGlobalRSI!
        
        // Déterminer signal global
        let globalSignal: RSIGlobalSignal
        if globalRSI < config.globalBuyThreshold && extremeLowPercent >= config.minExtremeTFPercent && isTurningUp {
            globalSignal = .buy
        } else if globalRSI > config.globalSellThreshold && extremeHighPercent >= config.minExtremeTFPercent && isTurningDown {
            globalSignal = .sell
        } else {
            globalSignal = .neutral
        }
        
        return RSISnapshot(
            symbol: symbol,
            readings: readings,
            globalRSI: globalRSI,
            globalSignal: globalSignal,
            extremeLowPercent: extremeLowPercent,
            extremeHighPercent: extremeHighPercent,
            isTurningUp: isTurningUp,
            isTurningDown: isTurningDown
        )
    }
}
