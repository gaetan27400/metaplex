//
//  TradeScenarioGenerator.swift
//  Journal de trading 2025
//
//  Génération dynamique des scénarios de trade basés sur MTF/WT/VMC
//  Détection des cross WT et VMC en zones extrêmes pour signaux premium
//

import Foundation

class TradeScenarioGenerator {
    
    // MARK: - Generate Scenarios
    
    static func generateScenarios(
        symbol: String,
        currentPrice: Double?,
        mtfSnapshot: MTFSnapshot?,
        wtSnapshot: WTSnapshot?,
        vmcOscSnapshot: VMCOscillatorSnapshot? = nil,
        language: Localizable.Language = LanguageManager.shared.currentLanguage
    ) -> (bull: TradeScenario, bear: TradeScenario, bullExplanation: ScenarioExplanation, bearExplanation: ScenarioExplanation) {
        
        guard let price = currentPrice, price > 0 else {
            return (.empty(language: language), .empty(language: language), .empty, .empty)
        }
        
        let crossSignals = detectCrossSignals(wt: wtSnapshot, vmcOsc: vmcOscSnapshot)
        let context = analyzeTechnicalContext(mtf: mtfSnapshot, wt: wtSnapshot, vmcOsc: vmcOscSnapshot, crossSignals: crossSignals)
        let vol = estimateVolatility(price: price, context: context)
        let levels = calculateDynamicLevels(price: price, atr: vol.atr, context: context)
        let bull = generateBullScenario(price: price, levels: levels, atr: vol.atr, context: context, language: language)
        let bear = generateBearScenario(price: price, levels: levels, atr: vol.atr, context: context, language: language)
        let bullExp = generateBullExplanation(context: context, language: language)
        let bearExp = generateBearExplanation(context: context, language: language)
        
        return (bull, bear, bullExp, bearExp)
    }
    
    // MARK: - Cross Signal Detection
    
    struct CrossSignals {
        let wtBullishCross: Bool
        let wtBearishCross: Bool
        let wtBullInExtreme: Bool
        let wtBearInExtreme: Bool
        let vmcBullishCross: Bool
        let vmcBearishCross: Bool
        let vmcBullInExtreme: Bool
        let vmcBearInExtreme: Bool
        
        var doubleBullCross: Bool { wtBullInExtreme && vmcBullInExtreme }
        var doubleBearCross: Bool { wtBearInExtreme && vmcBearInExtreme }
        
        var bullSignalStrength: SignalStrength {
            if doubleBullCross { return .premium }
            if wtBullInExtreme || vmcBullInExtreme { return .strong }
            if wtBullishCross || vmcBullishCross { return .moderate }
            return .none
        }
        
        var bearSignalStrength: SignalStrength {
            if doubleBearCross { return .premium }
            if wtBearInExtreme || vmcBearInExtreme { return .strong }
            if wtBearishCross || vmcBearishCross { return .moderate }
            return .none
        }
        
        enum SignalStrength: Int {
            case none = 0
            case moderate = 1
            case strong = 2
            case premium = 3
        }
        
        static let none = CrossSignals(
            wtBullishCross: false, wtBearishCross: false,
            wtBullInExtreme: false, wtBearInExtreme: false,
            vmcBullishCross: false, vmcBearishCross: false,
            vmcBullInExtreme: false, vmcBearInExtreme: false
        )
    }
    
    private static func detectCrossSignals(wt: WTSnapshot?, vmcOsc: VMCOscillatorSnapshot?) -> CrossSignals {
        var wtBullCross = false, wtBearCross = false
        var wtBullExtreme = false, wtBearExtreme = false
        
        if let wt = wt {
            if wt.readings.count >= 2 {
                let prev = wt.readings[wt.readings.count - 2]
                let curr = wt.readings[wt.readings.count - 1]
                if prev.histogram <= 0 && curr.histogram > 0 {
                    wtBullCross = true
                    if curr.wt1 < wt.oversoldLevel || curr.wt2 < wt.oversoldLevel { wtBullExtreme = true }
                }
                if prev.histogram >= 0 && curr.histogram < 0 {
                    wtBearCross = true
                    if curr.wt1 > wt.overboughtLevel || curr.wt2 > wt.overboughtLevel { wtBearExtreme = true }
                }
            } else if let signal = wt.currentSignal {
                switch signal {
                case .bullishReversal, .bullishSmartReversal: wtBullCross = true; wtBullExtreme = wt.isOversold
                case .bearishReversal, .bearishSmartReversal: wtBearCross = true; wtBearExtreme = wt.isOverbought
                case .neutral: break
                }
            }
        }
        
        var vmcBullCross = false, vmcBearCross = false
        var vmcBullExtreme = false, vmcBearExtreme = false
        
        if let vmc = vmcOsc {
            if vmc.readings.count >= 2 {
                let prev = vmc.readings[vmc.readings.count - 2]
                let curr = vmc.readings[vmc.readings.count - 1]
                let prevDiff = prev.sig - prev.sigSignal
                let currDiff = curr.sig - curr.sigSignal
                if prevDiff <= 0 && currDiff > 0 { vmcBullCross = true; vmcBullExtreme = vmc.isOversold }
                if prevDiff >= 0 && currDiff < 0 { vmcBearCross = true; vmcBearExtreme = vmc.isOverbought }
            } else if let signal = vmc.currentSignal {
                switch signal {
                case .buy: vmcBullCross = true; vmcBullExtreme = vmc.isOversold
                case .sell: vmcBearCross = true; vmcBearExtreme = vmc.isOverbought
                case .exitLong, .exitShort: break
                }
            }
        }
        
        return CrossSignals(
            wtBullishCross: wtBullCross, wtBearishCross: wtBearCross,
            wtBullInExtreme: wtBullExtreme, wtBearInExtreme: wtBearExtreme,
            vmcBullishCross: vmcBullCross, vmcBearishCross: vmcBearCross,
            vmcBullInExtreme: vmcBullExtreme, vmcBearInExtreme: vmcBearExtreme
        )
    }
    
    // MARK: - Technical Context
    
    struct TechnicalContext {
        let isBullish: Bool
        let isBearish: Bool
        let strength: Double
        let momentum: Double
        let rsiOversold: Bool
        let rsiOverbought: Bool
        let vmcBullish: Bool
        let vmcBearish: Bool
        let confluence: Double
        let wtOverbought: Bool
        let wtOversold: Bool
        let globalRSI: Double
        let globalVMC: Double
        let crossSignals: CrossSignals
    }
    
    private static func analyzeTechnicalContext(
        mtf: MTFSnapshot?, wt: WTSnapshot?, vmcOsc: VMCOscillatorSnapshot?, crossSignals: CrossSignals
    ) -> TechnicalContext {
        var isBullish = false, isBearish = false
        var strength = 0.5, confluence = 0.0
        var rsiOversold = false, rsiOverbought = false
        var vmcBullish = false, vmcBearish = false
        var globalRSI = 50.0, globalVMC = 0.0
        
        if let mtf = mtf {
            isBullish = mtf.globalSignal == .buy || mtf.globalSignal == .bullish
            isBearish = mtf.globalSignal == .sell || mtf.globalSignal == .bearish
            strength = (mtf.globalCombinedScore + 100) / 200
            rsiOversold = mtf.globalRSI < 30
            rsiOverbought = mtf.globalRSI > 70
            vmcBullish = mtf.globalVMC < -20
            vmcBearish = mtf.globalVMC > 20
            confluence = mtf.confluencePercent / 100
            globalRSI = mtf.globalRSI
            globalVMC = mtf.globalVMC
        }
        
        return TechnicalContext(
            isBullish: isBullish, isBearish: isBearish, strength: strength,
            momentum: wt?.currentMomentum ?? 0,
            rsiOversold: rsiOversold, rsiOverbought: rsiOverbought,
            vmcBullish: vmcBullish, vmcBearish: vmcBearish, confluence: confluence,
            wtOverbought: wt?.isOverbought ?? false, wtOversold: wt?.isOversold ?? false,
            globalRSI: globalRSI, globalVMC: globalVMC, crossSignals: crossSignals
        )
    }
    
    // MARK: - Volatility
    
    private struct VolEstimate { let atr: Double; let percent: Double }
    
    private static func estimateVolatility(price: Double, context: TechnicalContext) -> VolEstimate {
        let absMom = abs(context.momentum)
        var pct: Double
        if absMom > 8 { pct = 3.5 }
        else if absMom > 5 { pct = 2.8 }
        else if absMom > 3 { pct = 2.2 }
        else if absMom > 1 { pct = 1.6 }
        else { pct = 1.2 }
        if context.wtOverbought || context.wtOversold { pct *= 1.25 }
        if context.confluence > 0.75 { pct *= 1.15 }
        else if context.confluence < 0.30 { pct *= 0.85 }
        if price > 50000 { pct *= 1.1 }
        else if price < 10 { pct *= 1.4 }
        return VolEstimate(atr: price * pct / 100, percent: pct)
    }
    
    // MARK: - Dynamic Levels
    
    private struct PriceLevels {
        let support1: Double; let support2: Double
        let resistance1: Double; let resistance2: Double
    }
    
    private static func calculateDynamicLevels(price: Double, atr: Double, context: TechnicalContext) -> PriceLevels {
        let bias: Double
        if context.isBullish && context.strength > 0.65 { bias = 0.3 }
        else if context.isBearish && context.strength < 0.35 { bias = -0.3 }
        else { bias = 0 }
        return PriceLevels(
            support1: tick(price - atr * (1.0 + bias), price: price),
            support2: tick(price - atr * (2.2 + bias), price: price),
            resistance1: tick(price + atr * (1.0 - bias), price: price),
            resistance2: tick(price + atr * (2.2 - bias), price: price)
        )
    }
    
    // MARK: - Bull Scenario
    
    private static func generateBullScenario(
        price: Double, levels: PriceLevels, atr: Double, context: TechnicalContext, language: Localizable.Language
    ) -> TradeScenario {
        let isEN = language == .english
        let cross = context.crossSignals
        let entryType: String
        let entry: Double
        let stop: Double
        
        if cross.doubleBullCross {
            entryType = isEN ? "⭐ Double cross oversold" : "⭐ Double cross survente"
            entry = tick(price, price: price)
            stop = tick(price - atr * 0.4, price: price)
        } else if cross.wtBullInExtreme {
            entryType = isEN ? "WT cross oversold" : "Cross WT survente"
            entry = tick(price + atr * 0.05, price: price)
            stop = tick(price - atr * 0.5, price: price)
        } else if cross.vmcBullInExtreme {
            entryType = isEN ? "VMC cross oversold" : "Cross VMC survente"
            entry = tick(price - atr * 0.1, price: price)
            stop = tick(price - atr * 0.6, price: price)
        } else if cross.wtBullishCross || cross.vmcBullishCross {
            let source = cross.wtBullishCross ? "WT" : "VMC"
            entryType = "Cross \(source)"
            entry = tick(price - atr * 0.15, price: price)
            stop = tick(price - atr * 0.7, price: price)
        } else if context.rsiOversold && context.vmcBullish {
            entryType = isEN ? "Support rejection" : "Rejet support"
            entry = tick(levels.support1, price: price)
            stop = tick(levels.support1 - atr * 0.5, price: price)
        } else if context.isBullish && context.strength > 0.65 && context.momentum > 2 {
            entryType = isEN ? "Breakout" : "Cassure"
            entry = tick(levels.resistance1 + atr * 0.05, price: price)
            stop = tick(price - atr * 0.6, price: price)
        } else if context.momentum > 0 && context.confluence > 0.5 {
            entryType = "Pullback"
            entry = tick(price - atr * 0.35, price: price)
            stop = tick(price - atr * 1.1, price: price)
        } else {
            entryType = "Retest"
            entry = tick(levels.support1 + atr * 0.15, price: price)
            stop = tick(levels.support2 + atr * 0.1, price: price)
        }
        
        let risk = abs(entry - stop)
        guard risk > 0 else { return .empty(language: language) }
        
        let rrBoost: Double
        switch cross.bullSignalStrength {
        case .premium: rrBoost = 1.5
        case .strong:  rrBoost = 1.25
        case .moderate: rrBoost = 1.1
        case .none:    rrBoost = 1.0
        }
        let baseRR1: Double = context.confluence > 0.6 ? 1.5 : 1.2
        let baseRR2: Double = context.confluence > 0.6 ? 2.8 : 2.0
        let baseRR3: Double = context.confluence > 0.6 ? 4.5 : 3.2
        let rr1 = baseRR1 * rrBoost
        let rr2 = baseRR2 * rrBoost
        let rr3 = baseRR3 * rrBoost
        let tp1 = tick(entry + risk * rr1, price: price)
        let tp2 = tick(entry + risk * rr2, price: price)
        let tp3 = tick(entry + risk * rr3, price: price)
        
        return TradeScenario(
            entryType: entryType, entry: entry, stop: stop,
            tp1: tp1, tp1RR: String(format: "%.1f", rr1),
            tp2: tp2, tp2RR: String(format: "%.1f", rr2),
            tp3: tp3, tp3RR: String(format: "%.1f", rr3),
            riskPercent: ((stop - entry) / entry) * 100,
            potentialTP2Percent: ((tp2 - entry) / entry) * 100
        )
    }
    
    // MARK: - Bear Scenario
    
    private static func generateBearScenario(
        price: Double, levels: PriceLevels, atr: Double, context: TechnicalContext, language: Localizable.Language
    ) -> TradeScenario {
        let isEN = language == .english
        let cross = context.crossSignals
        let entryType: String
        let entry: Double
        let stop: Double
        
        if cross.doubleBearCross {
            entryType = isEN ? "⭐ Double cross overbought" : "⭐ Double cross surachat"
            entry = tick(price, price: price)
            stop = tick(price + atr * 0.4, price: price)
        } else if cross.wtBearInExtreme {
            entryType = isEN ? "WT cross overbought" : "Cross WT surachat"
            entry = tick(price - atr * 0.05, price: price)
            stop = tick(price + atr * 0.5, price: price)
        } else if cross.vmcBearInExtreme {
            entryType = isEN ? "VMC cross overbought" : "Cross VMC surachat"
            entry = tick(price + atr * 0.1, price: price)
            stop = tick(price + atr * 0.6, price: price)
        } else if cross.wtBearishCross || cross.vmcBearishCross {
            let source = cross.wtBearishCross ? "WT" : "VMC"
            entryType = "Cross \(source)"
            entry = tick(price + atr * 0.15, price: price)
            stop = tick(price + atr * 0.7, price: price)
        } else if context.rsiOverbought && context.vmcBearish {
            entryType = isEN ? "Resistance rejection" : "Rejet résistance"
            entry = tick(levels.resistance1, price: price)
            stop = tick(levels.resistance1 + atr * 0.5, price: price)
        } else if context.isBearish && context.strength < 0.35 && context.momentum < -2 {
            entryType = isEN ? "Breakdown" : "Cassure"
            entry = tick(levels.support1 - atr * 0.05, price: price)
            stop = tick(price + atr * 0.6, price: price)
        } else if context.momentum < 0 && context.confluence > 0.5 {
            entryType = isEN ? "Bounce" : "Rebond"
            entry = tick(price + atr * 0.35, price: price)
            stop = tick(price + atr * 1.1, price: price)
        } else {
            entryType = isEN ? "Resistance test" : "Test résistance"
            entry = tick(levels.resistance1 - atr * 0.15, price: price)
            stop = tick(levels.resistance2 - atr * 0.1, price: price)
        }
        
        let risk = abs(stop - entry)
        guard risk > 0 else { return .empty(language: language) }
        
        let rrBoost: Double
        switch cross.bearSignalStrength {
        case .premium: rrBoost = 1.5
        case .strong:  rrBoost = 1.25
        case .moderate: rrBoost = 1.1
        case .none:    rrBoost = 1.0
        }
        let rr1 = (context.confluence > 0.6 ? 1.5 : 1.2) * rrBoost
        let rr2 = (context.confluence > 0.6 ? 2.8 : 2.0) * rrBoost
        let rr3 = (context.confluence > 0.6 ? 4.5 : 3.2) * rrBoost
        let tp1 = tick(entry - risk * rr1, price: price)
        let tp2 = tick(entry - risk * rr2, price: price)
        let tp3 = tick(entry - risk * rr3, price: price)
        
        return TradeScenario(
            entryType: entryType, entry: entry, stop: stop,
            tp1: tp1, tp1RR: String(format: "%.1f", rr1),
            tp2: tp2, tp2RR: String(format: "%.1f", rr2),
            tp3: tp3, tp3RR: String(format: "%.1f", rr3),
            riskPercent: ((stop - entry) / entry) * 100,
            potentialTP2Percent: ((entry - tp2) / entry) * 100
        )
    }
    
    // MARK: - Bull Explanation
    
    private static func generateBullExplanation(context: TechnicalContext, language: Localizable.Language) -> ScenarioExplanation {
        let isEN = language == .english
        var reasons: [String] = []
        var validation: [String] = []
        var invalidation: [String] = []
        var risks: [String] = []
        let cross = context.crossSignals
        
        if cross.doubleBullCross {
            reasons.insert(isEN
                ? "⭐ Double bullish cross in oversold zone (WT + VMC) — premium signal"
                : "⭐ Double cross haussier en zone de survente (WT + VMC) — signal premium", at: 0)
        } else {
            if cross.wtBullInExtreme {
                reasons.append(isEN
                    ? "Bullish Wave Trend cross in oversold zone — strong reversal signal"
                    : "Cross haussier Wave Trend en zone de survente — signal fort de retournement")
            } else if cross.wtBullishCross {
                reasons.append(isEN
                    ? "Bullish Wave Trend cross (WT1 > WT2) — momentum favoring buyers"
                    : "Cross haussier Wave Trend (WT1 > WT2) — momentum en faveur des acheteurs")
            }
            if cross.vmcBullInExtreme {
                reasons.append(isEN
                    ? "Bullish VMC Oscillator cross in oversold zone — reversal confirmation"
                    : "Cross haussier VMC Oscillator en zone de survente — confirmation du retournement")
            } else if cross.vmcBullishCross {
                reasons.append(isEN
                    ? "Bullish VMC Oscillator cross — growing buying pressure"
                    : "Cross haussier VMC Oscillator — pression acheteuse croissante")
            }
        }
        if context.rsiOversold {
            reasons.append(isEN
                ? "RSI in oversold zone (\(Int(context.globalRSI))), likely bounce"
                : "RSI en zone de survente (\(Int(context.globalRSI))), rebond probable")
        }
        if context.vmcBullish {
            reasons.append(isEN
                ? "VMC MTF in negative territory (\(Int(context.globalVMC))), buying pressure"
                : "VMC MTF en territoire négatif (\(Int(context.globalVMC))), pression acheteuse")
        }
        if context.isBullish && context.confluence > 0.5 {
            reasons.append(isEN
                ? "Bullish MTF signal, confluence \(Int(context.confluence * 100))%"
                : "Signal MTF haussier, confluence \(Int(context.confluence * 100))%")
        }
        if context.momentum > 2 {
            reasons.append(isEN
                ? "Positive momentum (\(String(format: "%.1f", context.momentum)))"
                : "Momentum positif (\(String(format: "%.1f", context.momentum)))")
        }
        if reasons.isEmpty {
            reasons.append(isEN ? "Technical scenario on support zone" : "Scénario technique sur zone de support")
        }
        
        if cross.bullSignalStrength.rawValue >= 2 {
            validation.append(isEN
                ? "Cross confirmed with close above signal on next candle"
                : "Cross confirmé avec clôture au-dessus du signal sur la bougie suivante")
        }
        validation.append(isEN ? "Confirmed bounce with increasing volume" : "Rebond confirmé avec volume croissant")
        if context.momentum > 0 {
            validation.append(isEN ? "WT held above its signal line" : "WT maintenu au-dessus de sa ligne de signal")
        }
        
        invalidation.append(isEN
            ? "H4 close below stop loss with high selling volume"
            : "Clôture H4 sous le stop loss avec volume vendeur élevé")
        if cross.bullSignalStrength.rawValue >= 2 {
            invalidation.append(isEN ? "Immediate bearish re-cross (false signal)" : "Re-cross baissier immédiat (faux signal)")
        }
        
        if context.confluence < 0.5 {
            risks.append(isEN
                ? "Low confluence (\(Int(context.confluence * 100))%), inter-TF divergences"
                : "Confluence faible (\(Int(context.confluence * 100))%), divergences inter-UT")
        }
        if context.wtOverbought {
            risks.append(isEN ? "WT already overbought, limited upside potential" : "WT déjà en surachat, potentiel limité")
        }
        if abs(context.momentum) > 6 {
            risks.append(isEN ? "High volatility, adjust position size" : "Volatilité élevée, ajuster la taille de position")
        }
        if cross.bullSignalStrength == .moderate {
            risks.append(isEN ? "Cross outside extreme zone — lower quality signal" : "Cross hors zone extrême — signal de moindre qualité")
        }
        if risks.isEmpty {
            risks.append(isEN ? "Monitor macro catalysts" : "Surveiller les catalyseurs macro")
        }
        
        return ScenarioExplanation(reasons: reasons, validationConditions: validation, invalidation: invalidation, risks: risks)
    }
    
    // MARK: - Bear Explanation
    
    private static func generateBearExplanation(context: TechnicalContext, language: Localizable.Language) -> ScenarioExplanation {
        let isEN = language == .english
        var reasons: [String] = []
        var validation: [String] = []
        var invalidation: [String] = []
        var risks: [String] = []
        let cross = context.crossSignals
        
        if cross.doubleBearCross {
            reasons.insert(isEN
                ? "⭐ Double bearish cross in overbought zone (WT + VMC) — premium signal"
                : "⭐ Double cross baissier en zone de surachat (WT + VMC) — signal premium", at: 0)
        } else {
            if cross.wtBearInExtreme {
                reasons.append(isEN
                    ? "Bearish Wave Trend cross in overbought zone — strong reversal signal"
                    : "Cross baissier Wave Trend en zone de surachat — signal fort de retournement")
            } else if cross.wtBearishCross {
                reasons.append(isEN
                    ? "Bearish Wave Trend cross (WT1 < WT2) — momentum favoring sellers"
                    : "Cross baissier Wave Trend (WT1 < WT2) — momentum en faveur des vendeurs")
            }
            if cross.vmcBearInExtreme {
                reasons.append(isEN
                    ? "Bearish VMC Oscillator cross in overbought zone — reversal confirmation"
                    : "Cross baissier VMC Oscillator en zone de surachat — confirmation du retournement")
            } else if cross.vmcBearishCross {
                reasons.append(isEN
                    ? "Bearish VMC Oscillator cross — growing selling pressure"
                    : "Cross baissier VMC Oscillator — pression vendeuse croissante")
            }
        }
        if context.rsiOverbought {
            reasons.append(isEN
                ? "RSI in overbought zone (\(Int(context.globalRSI))), correction expected"
                : "RSI en zone de surachat (\(Int(context.globalRSI))), correction attendue")
        }
        if context.vmcBearish {
            reasons.append(isEN
                ? "VMC MTF in positive territory (\(Int(context.globalVMC))), selling pressure"
                : "VMC MTF en territoire positif (\(Int(context.globalVMC))), pression vendeuse")
        }
        if context.isBearish && context.confluence > 0.5 {
            reasons.append(isEN
                ? "Bearish MTF signal, confluence \(Int(context.confluence * 100))%"
                : "Signal MTF baissier, confluence \(Int(context.confluence * 100))%")
        }
        if context.momentum < -2 {
            reasons.append(isEN
                ? "Negative momentum (\(String(format: "%.1f", context.momentum)))"
                : "Momentum négatif (\(String(format: "%.1f", context.momentum)))")
        }
        if reasons.isEmpty {
            reasons.append(isEN ? "Technical scenario on resistance zone" : "Scénario technique sur zone de résistance")
        }
        
        if cross.bearSignalStrength.rawValue >= 2 {
            validation.append(isEN
                ? "Cross confirmed with close below signal on next candle"
                : "Cross confirmé avec clôture sous le signal sur la bougie suivante")
        }
        validation.append(isEN ? "Confirmed rejection with increasing selling volume" : "Rejet confirmé avec volume vendeur accru")
        if context.momentum < 0 {
            validation.append(isEN ? "WT held below its signal line" : "WT maintenu sous sa ligne de signal")
        }
        
        invalidation.append(isEN ? "H4 close above stop loss" : "Clôture H4 au-dessus du stop loss")
        if cross.bearSignalStrength.rawValue >= 2 {
            invalidation.append(isEN ? "Immediate bullish re-cross (false signal)" : "Re-cross haussier immédiat (faux signal)")
        }
        
        if context.confluence < 0.5 {
            risks.append(isEN
                ? "Low confluence (\(Int(context.confluence * 100))%), conflicting signals"
                : "Confluence faible (\(Int(context.confluence * 100))%), signaux contradictoires")
        }
        if context.wtOversold {
            risks.append(isEN ? "WT already oversold, risk of violent bounce" : "WT déjà en survente, risque de rebond violent")
        }
        if abs(context.momentum) > 6 {
            risks.append(isEN ? "High volatility, risk of bullish squeeze" : "Forte volatilité, risque de squeeze haussier")
        }
        if cross.bearSignalStrength == .moderate {
            risks.append(isEN ? "Cross outside extreme zone — lower quality signal" : "Cross hors zone extrême — signal de moindre qualité")
        }
        if risks.isEmpty {
            risks.append(isEN ? "Unexpected news could reverse the trend" : "News imprévue pouvant inverser la tendance")
        }
        
        return ScenarioExplanation(reasons: reasons, validationConditions: validation, invalidation: invalidation, risks: risks)
    }
    
    // MARK: - Current Price Fetcher
    
    static func getCurrentPrice(for symbol: String) async -> Double? {
        do {
            let price = try await MarketPriceService.shared.getCurrentPrice(for: symbol)
            if price > 0 { return price }
        } catch { }
        do {
            let candles = try await MarketDataService.shared.fetchKlines(symbol: symbol, interval: "1h", limit: 1)
            if let last = candles.last, last.close > 0 { return last.close }
        } catch { }
        return nil
    }
    
    // MARK: - Tick Rounding
    
    private static func tick(_ value: Double, price: Double) -> Double {
        if price >= 10000      { return (value / 10).rounded() * 10 }
        else if price >= 1000  { return (value / 5).rounded() * 5 }
        else if price >= 100   { return (value * 2).rounded() / 2 }
        else if price >= 10    { return (value * 10).rounded() / 10 }
        else if price >= 1     { return (value * 100).rounded() / 100 }
        else                   { return (value * 10000).rounded() / 10000 }
    }
}

// MARK: - TradeScenario Extension

extension TradeScenario {
    /// Language-aware empty scenario
    static func empty(language: Localizable.Language) -> TradeScenario {
        let label = language == .english ? "Insufficient data" : "Données insuffisantes"
        return TradeScenario(
            entryType: label,
            entry: nil, stop: nil,
            tp1: nil, tp1RR: nil,
            tp2: nil, tp2RR: nil,
            tp3: nil, tp3RR: nil,
            riskPercent: nil, potentialTP2Percent: nil
        )
    }

    /// Backward-compatible static empty (uses localized label via LanguageManager)
    static var empty: TradeScenario {
        let isEN = LanguageManager.shared.currentLanguage == .english
        return TradeScenario(
            entryType: isEN ? "Insufficient data" : "Données insuffisantes",
            entry: nil, stop: nil,
            tp1: nil, tp1RR: nil,
            tp2: nil, tp2RR: nil,
            tp3: nil, tp3RR: nil,
            riskPercent: nil, potentialTP2Percent: nil
        )
    }
}
