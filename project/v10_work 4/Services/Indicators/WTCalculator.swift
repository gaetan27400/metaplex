//
//  WTCalculator.swift
//  Journal de trading 2025
//
//  Calculateur pour l'oscillateur Wave Trend
//

import Foundation

struct WTCalculator {
    let config: WTConfig
    
    init(config: WTConfig = .default) {
        self.config = config
    }
    
    // MARK: - Wave Trend Calculation
    
    /// Calcule WT1 et WT2 à partir des prix OHLC
    func calculateWaveTrend(prices: [OHLC]) -> (wt1: [Double], wt2: [Double]) {
        guard prices.count >= config.channelLength else {
            return ([], [])
        }
        
        var wt1Values: [Double] = []
        var wt2Values: [Double] = []
        
        // Calculer ap (hlc3) pour chaque barre
        let ap = prices.map { ($0.high + $0.low + $0.close) / 3.0 }
        
        // Calculer esa (EMA de ap)
        var esa: [Double] = []
        var d: [Double] = []
        var ci: [Double] = []
        var tci: [Double] = []
        
        for i in 0..<ap.count {
            // ESA (EMA de ap)
            if i == 0 {
                esa.append(ap[i])
            } else {
                let alpha = 2.0 / Double(config.channelLength + 1)
                esa.append(alpha * ap[i] + (1 - alpha) * esa[i - 1])
            }
            
            // D (EMA de abs(ap - esa))
            if i == 0 {
                d.append(abs(ap[i] - esa[i]))
            } else {
                let alpha = 2.0 / Double(config.channelLength + 1)
                d.append(alpha * abs(ap[i] - esa[i]) + (1 - alpha) * d[i - 1])
            }
            
            // CI
            if d[i] != 0 {
                ci.append((ap[i] - esa[i]) / (0.015 * d[i]))
            } else {
                ci.append(0)
            }
            
            // TCI (EMA de CI)
            if tci.isEmpty {
                tci.append(ci[i])
            } else {
                let alpha = 2.0 / Double(config.averageLength + 1)
                tci.append(alpha * ci[i] + (1 - alpha) * tci[i - 1])
            }
            
            // WT1 = TCI
            wt1Values.append(tci[i])
        }
        
        // WT2 = SMA de WT1 sur 4 périodes
        for i in 0..<wt1Values.count {
            if i < 3 {
                wt2Values.append(wt1Values[i])
            } else {
                let sum = wt1Values[(i-3)...i].reduce(0, +)
                wt2Values.append(sum / 4.0)
            }
        }
        
        return (wt1Values, wt2Values)
    }
    
    // MARK: - Direction Calculation
    
    /// Calcule la direction du Wave Trend
    func calculateDirection(wt1: [Double], reactionWT: Int) -> [Int] {
        var directions: [Int] = []
        var lastDirection = 0
        
        for i in 0..<wt1.count {
            if i < reactionWT {
                directions.append(0)
                continue
            }
            
            // Vérifier si WT1 monte ou descend
            let isRising = wt1[i] > wt1[i - reactionWT]
            let isFalling = wt1[i] < wt1[i - reactionWT]
            
            if isRising {
                lastDirection = 1
            } else if isFalling {
                lastDirection = -1
            }
            
            directions.append(lastDirection)
        }
        
        return directions
    }
    
    // MARK: - Signal Detection
    
    /// Détecte les signaux Smart Reversal
    func detectSignals(
        wt1: [Double],
        wt2: [Double],
        directions: [Int]
    ) -> [WTSignal?] {
        var signals: [WTSignal?] = Array(repeating: nil, count: wt1.count)
        
        for i in 1..<wt1.count {
            let prevWT1 = wt1[i - 1]
            let prevWT2 = wt2[i - 1]
            let currWT1 = wt1[i]
            let currWT2 = wt2[i]
            
            // Crossover (WT1 croise au-dessus de WT2)
            let crossover = prevWT1 <= prevWT2 && currWT1 > currWT2
            // Crossunder (WT1 croise en-dessous de WT2)
            let crossunder = prevWT1 >= prevWT2 && currWT1 < currWT2
            
            // Smart Bullish Reversal (crossover en zone de survente)
            if crossover && currWT1 <= config.oversoldLevel2 && config.onlySmartSellReversal {
                signals[i] = .bullishSmartReversal
            }
            // Bullish Reversal (crossover normal)
            else if crossover && config.onlySmartSellReversal == false {
                signals[i] = .bullishReversal
            }
            // Smart Bearish Reversal (crossunder en zone de surachat)
            else if crossunder && currWT1 >= config.overboughtLevel2 && config.onlySmartBuyReversal {
                signals[i] = .bearishSmartReversal
            }
            // Bearish Reversal (crossunder normal)
            else if crossunder && config.onlySmartBuyReversal == false {
                signals[i] = .bearishReversal
            }
        }
        
        return signals
    }
    
    // MARK: - Divergence Detection
    
    /// Détecte les divergences basées sur les fractales
    func detectDivergences(
        wt1: [Double],
        prices: [OHLC],
        showRegularBullish: Bool = true,
        showRegularBearish: Bool = true,
        showHiddenBullish: Bool = true,
        showHiddenBearish: Bool = true
    ) -> [(hasDivergence: Bool, type: WTDivergenceType?)] {
        var divergences: [(Bool, WTDivergenceType?)] = Array(repeating: (false, nil), count: wt1.count)
        
        // Détecter les fractales (pics et creux)
        for i in 4..<(wt1.count - 2) {
            // Fractale top (pic)
            let isTopFractal = wt1[i - 2] > wt1[i - 4] &&
                               wt1[i - 2] > wt1[i - 3] &&
                               wt1[i - 2] > wt1[i - 1] &&
                               wt1[i - 2] > wt1[i]
            
            // Fractale bottom (creux)
            let isBotFractal = wt1[i - 2] < wt1[i - 4] &&
                               wt1[i - 2] < wt1[i - 3] &&
                               wt1[i - 2] < wt1[i - 1] &&
                               wt1[i - 2] < wt1[i]
            
            if isTopFractal {
                // Chercher le précédent pic
                var prevTopIndex = -1
                for j in stride(from: i - 6, through: 4, by: -1) {
                    if wt1[j - 2] > wt1[j - 4] &&
                       wt1[j - 2] > wt1[j - 3] &&
                       wt1[j - 2] > wt1[j - 1] &&
                       wt1[j - 2] > wt1[j] {
                        prevTopIndex = j - 2
                        break
                    }
                }
                
                if prevTopIndex >= 0 {
                    let currWT = wt1[i - 2]
                    let prevWT = wt1[prevTopIndex]
                    let currPrice = prices[i - 2].high
                    let prevPrice = prices[prevTopIndex].high
                    
                    // Regular Bearish Divergence
                    if currPrice > prevPrice && currWT < prevWT && showRegularBearish {
                        divergences[i - 2] = (true, .regularBearish)
                    }
                    // Hidden Bearish Divergence
                    else if currPrice < prevPrice && currWT > prevWT && showHiddenBearish {
                        divergences[i - 2] = (true, .hiddenBearish)
                    }
                }
            }
            
            if isBotFractal {
                // Chercher le précédent creux
                var prevBotIndex = -1
                for j in stride(from: i - 6, through: 4, by: -1) {
                    if wt1[j - 2] < wt1[j - 4] &&
                       wt1[j - 2] < wt1[j - 3] &&
                       wt1[j - 2] < wt1[j - 1] &&
                       wt1[j - 2] < wt1[j] {
                        prevBotIndex = j - 2
                        break
                    }
                }
                
                if prevBotIndex >= 0 {
                    let currWT = wt1[i - 2]
                    let prevWT = wt1[prevBotIndex]
                    let currPrice = prices[i - 2].low
                    let prevPrice = prices[prevBotIndex].low
                    
                    // Regular Bullish Divergence
                    if currPrice < prevPrice && currWT > prevWT && showRegularBullish {
                        divergences[i - 2] = (true, .regularBullish)
                    }
                    // Hidden Bullish Divergence
                    else if currPrice > prevPrice && currWT < prevWT && showHiddenBullish {
                        divergences[i - 2] = (true, .hiddenBullish)
                    }
                }
            }
        }
        
        return divergences
    }
    
    // MARK: - Heikin Ashi (Market Bias)
    
    /// Calcule le Market Bias basé sur Heikin Ashi
    func calculateMarketBias(prices: [OHLC]) -> (bias: [MarketBias], strength: [Double]) {
        guard prices.count >= config.haPeriod else {
            return ([], [])
        }
        
        var biases: [MarketBias] = []
        var strengths: [Double] = []
        
        // Calculer Heikin Ashi
        var haOpen: [Double] = []
        var haClose: [Double] = []
        var haHigh: [Double] = []
        var haLow: [Double] = []
        
        for i in 0..<prices.count {
            let p = prices[i]
            
            // HA Close
            let haC = (p.high + p.low + p.close + p.open) / 4.0
            
            // HA Open
            let haO: Double
            if i == 0 {
                haO = (p.open + p.close) / 2.0
            } else {
                haO = (haOpen[i - 1] + haClose[i - 1]) / 2.0
            }
            
            // HA High/Low
            let haH = max(p.high, max(haO, haC))
            let haL = min(p.low, min(haO, haC))
            
            haOpen.append(haO)
            haClose.append(haC)
            haHigh.append(haH)
            haLow.append(haL)
        }
        
        // Lisser avec EMA
        var smoothedOpen: [Double] = []
        var smoothedClose: [Double] = []
        
        for i in 0..<haOpen.count {
            if i == 0 {
                smoothedOpen.append(haOpen[i])
                smoothedClose.append(haClose[i])
            } else {
                let alpha = 2.0 / Double(config.haSmoothing + 1)
                smoothedOpen.append(alpha * haOpen[i] + (1 - alpha) * smoothedOpen[i - 1])
                smoothedClose.append(alpha * haClose[i] + (1 - alpha) * smoothedClose[i - 1])
            }
        }
        
        // Calculer bias et strength
        for i in 0..<smoothedClose.count {
            let oscBias = 100 * (smoothedClose[i] - smoothedOpen[i])
            
            // Normaliser la force (0-100)
            let strength = min(100, max(0, abs(oscBias) * 2))
            
            if oscBias > 0 {
                biases.append(.bullish)
            } else if oscBias < 0 {
                biases.append(.bearish)
            } else {
                biases.append(.neutral)
            }
            
            strengths.append(strength)
        }
        
        return (biases, strengths)
    }
    
    // MARK: - Momentum MisterMota
    
    /// Calcule le momentum MisterMota
    func calculateMomentum(prices: [OHLC]) -> (momentum: [Double], direction: [MomentumDirection], angle: [Double]) {
        guard prices.count >= config.momentumPeriod else {
            return ([], [], [])
        }
        
        var directions: [MomentumDirection] = []
        var angles: [Double] = []
        
        let source = prices.map(\.close)
        let sd = calculateStandardDeviation(source, period: config.momentumPeriod) * config.momentumResponsiveness
        
        var worm = source[0]
        var smoothedValues: [Double] = []
        
        // Calculer "worm" (valeur lissée)
        for i in 0..<source.count {
            let diff = source[i] - worm
            let delta = abs(diff) > sd ? (diff > 0 ? sd : -sd) : diff
            worm = worm + delta
            smoothedValues.append(worm)
        }
        
        // Calculer la moyenne mobile
        var maValues: [Double] = []
        for i in 0..<source.count {
            if i < config.momentumPeriod {
                let sum = source[0...i].reduce(0, +)
                maValues.append(sum / Double(i + 1))
            } else {
                let sum = source[(i - config.momentumPeriod + 1)...i].reduce(0, +)
                maValues.append(sum / Double(config.momentumPeriod))
            }
        }
        
        // Calculer raw momentum
        var rawMomentum: [Double] = []
        for i in 0..<smoothedValues.count {
            if smoothedValues[i] != 0 {
                rawMomentum.append((smoothedValues[i] - maValues[i]) / smoothedValues[i])
            } else {
                rawMomentum.append(0)
            }
        }
        
        // Normaliser et calculer momentum final
        var momentumValues: [Double] = []
        var prevMomentum = 0.0
        
        for i in 0..<rawMomentum.count {
            let currentMed = rawMomentum[i]
            
            // Trouver min/max sur la période
            let startIdx = max(0, i - config.momentumPeriod + 1)
            let range = rawMomentum[startIdx...i]
            let minMed = range.min() ?? 0
            let maxMed = range.max() ?? 1
            
            // Normaliser
            let temp = maxMed != minMed ? (currentMed - minMed) / (maxMed - minMed) : 0.5
            // CORRECTION BUG: value doit être calculé à partir de temp, pas fixé à 1.0
            var value = temp * 2.0
            value = value * (temp - 0.5 + 0.5 * prevMomentum)
            value = min(0.9999, max(-0.9999, value))
            
            // Calculer momentum
            let temp2 = (1 + value) / (1 - value)
            var momentum = 0.25 * log(temp2)
            momentum = momentum + 0.5 * prevMomentum
            
            momentumValues.append(momentum)
            prevMomentum = momentum
            
            // Direction
            if i > 0 {
                directions.append(momentum > momentumValues[i - 1] ? .growing : .falling)
            } else {
                directions.append(.growing)
            }
            
            // Angle (simplifié)
            if i > 0 {
                let change = momentum - momentumValues[i - 1]
                let angle = atan(change) * 180.0 / .pi
                angles.append(angle)
            } else {
                angles.append(0)
            }
        }
        
        return (momentumValues, directions, angles)
    }
    
    // MARK: - Helper Functions
    
    private func calculateStandardDeviation(_ values: [Double], period: Int) -> Double {
        guard values.count >= period else { return 0 }
        
        let recent = Array(values.suffix(period))
        let mean = recent.reduce(0, +) / Double(period)
        let variance = recent.map { pow($0 - mean, 2) }.reduce(0, +) / Double(period)
        return sqrt(variance)
    }
    
    // MARK: - Create Snapshot
    
    /// Crée un snapshot complet du Wave Trend
    func createSnapshot(
        symbol: String,
        prices: [OHLC],
        showRegularBullish: Bool = true,
        showRegularBearish: Bool = true,
        showHiddenBullish: Bool = true,
        showHiddenBearish: Bool = true
    ) -> WTSnapshot {
        // Calculer Wave Trend
        let (wt1, wt2) = calculateWaveTrend(prices: prices)
        guard !wt1.isEmpty else {
            return WTSnapshot.empty(symbol: symbol)
        }
        
        // Calculer direction
        let directions = calculateDirection(wt1: wt1, reactionWT: config.reactionWT)
        
        // Détecter signaux
        let signals = detectSignals(wt1: wt1, wt2: wt2, directions: directions)
        
        // Détecter divergences
        let divergences = detectDivergences(
            wt1: wt1,
            prices: prices,
            showRegularBullish: showRegularBullish,
            showRegularBearish: showRegularBearish,
            showHiddenBullish: showHiddenBullish,
            showHiddenBearish: showHiddenBearish
        )
        
        // Calculer Market Bias
        let (biases, biasStrengths) = calculateMarketBias(prices: prices)
        
        // Calculer Momentum
        let (momentumValues, momentumDirs, momentumAngles) = calculateMomentum(prices: prices)
        
        // Créer les readings
        var readings: [WTReading] = []
        for i in 0..<wt1.count {
            let histogram = wt1[i] - wt2[i]
            let timestamp = i < prices.count ? prices[i].timestamp : Date()
            
            readings.append(WTReading(
                timestamp: timestamp,
                wt1: wt1[i],
                wt2: wt2[i],
                histogram: histogram,
                direction: i < directions.count ? directions[i] : 0,
                signal: i < signals.count ? signals[i] : nil,
                hasDivergence: i < divergences.count ? divergences[i].hasDivergence : false,
                divergenceType: i < divergences.count ? divergences[i].type : nil,
                marketBias: i < biases.count ? biases[i] : .neutral,
                biasStrength: i < biasStrengths.count ? biasStrengths[i] : 0,
                momentum: i < momentumValues.count ? momentumValues[i] : 0,
                momentumDirection: i < momentumDirs.count ? momentumDirs[i] : .growing,
                momentumAngle: i < momentumAngles.count ? momentumAngles[i] : 0
            ))
        }
        
        // Valeurs actuelles
        let lastIdx = readings.count - 1
        guard lastIdx >= 0 else {
            return WTSnapshot.empty(symbol: symbol)
        }
        
        let current = readings[lastIdx]
        
        // Calculer le score de qualité (optionnel, léger)
        let signalQuality = calculateSignalQuality(
            signal: current.signal,
            hasDivergence: current.hasDivergence,
            isOverbought: current.wt1 >= config.overboughtLevel2,
            isOversold: current.wt1 <= config.oversoldLevel2,
            marketBias: current.marketBias
        )
        
        return WTSnapshot(
            symbol: symbol,
            timestamp: Date(),
            readings: readings,
            currentWT1: current.wt1,
            currentWT2: current.wt2,
            currentHistogram: current.histogram,
            currentSignal: current.signal,
            hasActiveDivergence: current.hasDivergence,
            activeDivergenceType: current.divergenceType,
            currentMarketBias: current.marketBias,
            biasStrength: current.biasStrength,
            currentMomentum: current.momentum,
            momentumDirection: current.momentumDirection,
            momentumAngle: current.momentumAngle,
            isOverbought: current.wt1 >= config.overboughtLevel2,
            isOversold: current.wt1 <= config.oversoldLevel2,
            overboughtLevel: config.overboughtLevel2,
            oversoldLevel: config.oversoldLevel2,
            signalQuality: signalQuality
        )
    }
    
    // MARK: - Signal Quality Calculation (léger, optionnel)
    
    /// Calcule un score de qualité simple pour le signal (0-100)
    private func calculateSignalQuality(
        signal: WTSignal?,
        hasDivergence: Bool,
        isOverbought: Bool,
        isOversold: Bool,
        marketBias: MarketBias
    ) -> WTSignalQuality? {
        // Ne calculer que si on a un signal non-neutral
        guard let signal = signal, signal != .neutral else {
            return nil
        }
        
        var score = 50.0 // Score de base
        var factors: [WTSignalQuality.QualityFactor] = []
        
        // 1. Divergence active (+20 points)
        if hasDivergence {
            score += 20
            factors.append(.strongDivergence)
        }
        
        // 2. Zone extrême (surachat/survente) (+15 points)
        if isOverbought || isOversold {
            score += 15
            factors.append(.extremeZone)
        }
        
        // 3. Alignement avec le biais de marché (+10 points)
        let isBullishSignal = signal == .bullishReversal || signal == .bullishSmartReversal
        let isBearishSignal = signal == .bearishReversal || signal == .bearishSmartReversal
        
        if (isBullishSignal && marketBias == .bullish) || (isBearishSignal && marketBias == .bearish) {
            score += 10
            factors.append(.trendAlignment)
        }
        
        // Normaliser entre 0 et 100
        score = min(100, max(0, score))
        
        return WTSignalQuality(score: score, factors: factors)
    }
}

// MARK: - WTSnapshot Extension

extension WTSnapshot {
    static func empty(symbol: String) -> WTSnapshot {
        WTSnapshot(
            symbol: symbol,
            timestamp: Date(),
            readings: [],
            currentWT1: 0,
            currentWT2: 0,
            currentHistogram: 0,
            currentSignal: nil,
            hasActiveDivergence: false,
            activeDivergenceType: nil,
            currentMarketBias: .neutral,
            biasStrength: 0,
            currentMomentum: 0,
            momentumDirection: .growing,
            momentumAngle: 0,
            isOverbought: false,
            isOversold: false,
            overboughtLevel: 53,
            oversoldLevel: -53,
            signalQuality: nil
        )
    }
}
