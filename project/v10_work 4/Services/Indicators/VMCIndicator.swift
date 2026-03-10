import Foundation
import SwiftUI

struct VMCIndicatorCandle {
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

struct VMCSignalResult {
    let sig: Double
    let sigSignal: Double
    let momentum: Double
    let bullConfirm: Bool
    let bearConfirm: Bool
    let ribbonBull: Bool
    let ribbonBear: Bool
    let compression: Bool
    let status: String
    let summary: String
}

enum IndicatorPreset {
    case scalping, swing, position, custom(up: Double, lo: Double)
}

final class VMCIndicator {
    static func evaluate(candles: [VMCIndicatorCandle], preset: IndicatorPreset = .position) -> VMCSignalResult {
        guard candles.count >= 60 else {
            return VMCSignalResult(sig: 0, sigSignal: 0, momentum: 0, bullConfirm: false, bearConfirm: false, ribbonBull: false, ribbonBear: false, compression: false, status: "NEUTRAL", summary: "Données insuffisantes")
        }
        let close = candles.map { $0.close }
        let high  = candles.map { $0.high }
        let low   = candles.map { $0.low }
        let hlc3  = zip(zip(high, low).map { ($0 + $1) / 2.0 }, close).map { ($0 + $1) / 2.0 }
        
        let rsiLen = 14
        let smoothLen = 2
        let smoothMult = 1.75
        let mfiWeight = 0.40
        let stochWeight = 0.40
        
        let thresholds: (up: Double, lo: Double)
        switch preset {
        case .scalping: thresholds = (40, -30)
        case .swing: thresholds = (35, -25)
        case .position: thresholds = (30, -20)
        case .custom(let up, let lo): thresholds = (up, lo)
        }
        
        let rsi = computeRSI(hlc3, length: rsiLen)
        let mfi = computeMFI(high: high, low: low, close: close, volume: candles.map { $0.volume }, length: 7)
        let stoch = computeStoch(source: rsi, length: rsiLen)
        let denom = 1.0 + mfiWeight + stochWeight
        let core = zip(zip(rsi, mfi).map { $0 + mfiWeight * $1 }, stoch).map { ($0 + stochWeight * $1) / denom }
        
        let emaFast = ema(core, length: smoothLen)
        let emaSlow = ema(core, length: Int((Double(smoothLen) * smoothMult).rounded()))
        let sig = transform(emaFast)
        let sigSignal = transform(emaSlow)
        
        let momentum = zip(sig, sigSignal).map(-)
        
        let e1 = ema(close, length: 20), e2 = ema(close, length: 25), e3 = ema(close, length: 30), e4 = ema(close, length: 35)
        let e5 = ema(close, length: 40), e6 = ema(close, length: 45), e7 = ema(close, length: 50), e8 = ema(close, length: 55)
        let last = close.count - 1
        guard last >= 1 else { return VMCSignalResult(sig: 0, sigSignal: 0, momentum: 0, bullConfirm: false, bearConfirm: false, ribbonBull: false, ribbonBear: false, compression: false, status: "NEUTRAL", summary: "Données insuffisantes") }
        
        let ribbonBull = e1[last] > e2[last] && e2[last] > e3[last] && e3[last] > e4[last] && e4[last] > e5[last] && e5[last] > e6[last] && e6[last] > e7[last] && e7[last] > e8[last]
        let ribbonBear = e1[last] < e2[last] && e2[last] < e3[last] && e3[last] < e4[last] && e4[last] < e5[last] && e5[last] < e6[last] && e6[last] < e7[last] && e7[last] < e8[last]
        
        let crossUp = crossedAbove(sig, sigSignal)
        let crossDn = crossedBelow(sig, sigSignal)
        let lastSig = sig[last]
        let lastSigSignal = sigSignal[last]
        let bullConfirm = crossUp && lastSig < thresholds.lo
        let bearConfirm = crossDn && lastSig > thresholds.up
        
        let spreadPct = abs(e1[last] - e8[last]) / max(close[last], 1e-9) * 100.0
        let spreadFalling = last >= 1 && spreadPct < (abs(e1[last-1] - e8[last-1]) / max(close[last-1], 1e-9) * 100.0)
        let vmcUnderLo = lastSig <= thresholds.lo
        let compression = (spreadPct <= 0.30) && spreadFalling && vmcUnderLo
        
        var status = "NEUTRAL"
        if bullConfirm && (ribbonBull || compression) && momentum[last] >= 0 { status = "BUY" }
        else if bearConfirm && (ribbonBear || compression) && momentum[last] <= 0 { status = "SELL" }
        
        let summary = String(format: "sig:%.1f/%.1f  mom:%@  ribbon:%@  comp:%@", lastSig, lastSigSignal, momentum[last] >= 0 ? "+" : "-", ribbonBull ? "bull" : ribbonBear ? "bear" : "flat", compression ? "on" : "off")
        
        return VMCSignalResult(sig: lastSig, sigSignal: lastSigSignal, momentum: momentum[last], bullConfirm: bullConfirm, bearConfirm: bearConfirm, ribbonBull: ribbonBull, ribbonBear: ribbonBear, compression: compression, status: status, summary: summary)
    }
    
    private static func ema(_ values: [Double], length: Int) -> [Double] {
        guard length > 0, !values.isEmpty else { return Array(repeating: 0, count: values.count) }
        let k = 2.0 / (Double(length) + 1.0)
        var out = Array(repeating: 0.0, count: values.count)
        out[0] = values[0]
        for i in 1..<values.count { out[i] = values[i] * k + out[i-1] * (1 - k) }
        return out
    }
    
    private static func computeRSI(_ src: [Double], length: Int) -> [Double] {
        guard src.count > length else { return Array(repeating: 50, count: src.count) }
        var gains = Array(repeating: 0.0, count: src.count)
        var losses = Array(repeating: 0.0, count: src.count)
        for i in 1..<src.count {
            let diff = src[i] - src[i-1]
            gains[i] = max(diff, 0)
            losses[i] = max(-diff, 0)
        }
        let avgGain = ema(gains, length: length)
        let avgLoss = ema(losses, length: length)
        return zip(avgGain, avgLoss).map { g, l in
            if l == 0 { return 100 }
            let rs = g / l
            return 100 - (100 / (1 + rs))
        }
    }
    
    private static func computeMFI(high: [Double], low: [Double], close: [Double], volume: [Double], length: Int) -> [Double] {
        let n = min(high.count, min(low.count, min(close.count, volume.count)))
        guard n > length else { return Array(repeating: 50, count: n) }
        var tp = [Double](repeating: 0, count: n)
        for i in 0..<n { tp[i] = (high[i] + low[i] + close[i]) / 3.0 }
        var pmf = [Double](repeating: 0, count: n)
        var nmf = [Double](repeating: 0, count: n)
        for i in 1..<n {
            let raw = tp[i] * volume[i]
            if tp[i] > tp[i-1] { pmf[i] = raw } else if tp[i] < tp[i-1] { nmf[i] = raw }
        }
        let sumPMF = rollingSum(pmf, length: length)
        let sumNMF = rollingSum(nmf, length: length)
        return zip(sumPMF, sumNMF).map { p, n in
            let denom = p + n
            if denom == 0 { return 50 }
            let mfr = p / denom
            return mfr * 100
        }
    }
    
    private static func rollingSum(_ arr: [Double], length: Int) -> [Double] {
        guard length > 0, arr.count >= length else { return Array(repeating: 0, count: arr.count) }
        var out = [Double](repeating: 0, count: arr.count)
        var sum = 0.0
        for i in 0..<arr.count {
            sum += arr[i]
            if i >= length { sum -= arr[i - length] }
            out[i] = sum
        }
        return out
    }
    
    private static func computeStoch(source: [Double], length: Int) -> [Double] {
        guard source.count >= length else { return Array(repeating: 50, count: source.count) }
        var out = [Double](repeating: 0, count: source.count)
        for i in 0..<source.count {
            let a = max(0, i - length + 1)
            let window = source[a...i]
            guard let minV = window.min(), let maxV = window.max(), maxV - minV != 0 else { out[i] = 50; continue }
            out[i] = (source[i] - minV) / (maxV - minV) * 100.0
        }
        return ema(out, length: 2)
    }
    
    private static func transform(_ src: [Double]) -> [Double] {
        return src.map { v in
            let tmp = (v / 100.0 - 0.5) * 2.0
            let signed = (tmp >= 0 ? 1.0 : -1.0) * pow(abs(tmp), 0.75)
            return 100.0 * signed
        }
    }
    
    private static func crossedAbove(_ a: [Double], _ b: [Double]) -> Bool {
        guard a.count >= 2, b.count >= 2 else { return false }
        let i = a.count - 1
        return a[i-1] <= b[i-1] && a[i] > b[i]
    }
    
    private static func crossedBelow(_ a: [Double], _ b: [Double]) -> Bool {
        guard a.count >= 2, b.count >= 2 else { return false }
        let i = a.count - 1
        return a[i-1] >= b[i-1] && a[i] < b[i]
    }
    
    // MARK: - Series Evaluation (pour le graphique oscillateur)
    
    static func evaluateSeries(
        candles: [Candle],
        preset: IndicatorPreset = .swing,
        tailCount: Int = 100
    ) -> VMCOscillatorSnapshot? {
        let vmcCandles = candles.map {
            VMCIndicatorCandle(open: $0.open, high: $0.high, low: $0.low, close: $0.close, volume: $0.volume)
        }
        guard vmcCandles.count >= 60 else { return nil }
        
        let close = vmcCandles.map { $0.close }
        let high  = vmcCandles.map { $0.high }
        let low   = vmcCandles.map { $0.low }
        let hlc3  = zip(zip(high, low).map { ($0 + $1) / 2.0 }, close).map { ($0 + $1) / 2.0 }
        
        let rsiLen = 14
        let smoothLen = 2
        let smoothMult = 1.75
        let mfiWeight = 0.40
        let stochWeight = 0.40
        
        let thresholds: (up: Double, lo: Double)
        switch preset {
        case .scalping: thresholds = (40, -30)
        case .swing: thresholds = (35, -25)
        case .position: thresholds = (30, -20)
        case .custom(let up, let lo): thresholds = (up, lo)
        }
        
        let rsi = computeRSI(hlc3, length: rsiLen)
        let mfi = computeMFI(high: high, low: low, close: close, volume: vmcCandles.map { $0.volume }, length: 7)
        let stoch = computeStoch(source: rsi, length: rsiLen)
        let denom = 1.0 + mfiWeight + stochWeight
        let core = zip(zip(rsi, mfi).map { $0 + mfiWeight * $1 }, stoch).map { ($0 + stochWeight * $1) / denom }
        
        let emaFast = ema(core, length: smoothLen)
        let emaSlow = ema(core, length: Int((Double(smoothLen) * smoothMult).rounded()))
        let sig = transform(emaFast)
        let sigSignal = transform(emaSlow)
        let momentum = zip(sig, sigSignal).map(-)
        
        let e1 = ema(close, length: 20), e2 = ema(close, length: 25)
        let e3 = ema(close, length: 30), e4 = ema(close, length: 35)
        let e5 = ema(close, length: 40), e6 = ema(close, length: 45)
        let e7 = ema(close, length: 50), e8 = ema(close, length: 55)
        
        let count = sig.count
        let startIdx = max(1, count - tailCount)
        var readings: [VMCOscillatorReading] = []
        
        for i in startIdx..<count {
            let timestamp = Date(timeIntervalSince1970: candles[i].openTime)
            var signal: VMCOscillatorSignal? = nil
            
            if i >= 1 {
                let bullCross = sig[i-1] <= sigSignal[i-1] && sig[i] > sigSignal[i]
                let bearCross = sig[i-1] >= sigSignal[i-1] && sig[i] < sigSignal[i]
                let rBull = e1[i] > e2[i] && e2[i] > e3[i] && e3[i] > e4[i] && e4[i] > e5[i] && e5[i] > e6[i] && e6[i] > e7[i] && e7[i] > e8[i]
                let rBear = e1[i] < e2[i] && e2[i] < e3[i] && e3[i] < e4[i] && e4[i] < e5[i] && e5[i] < e6[i] && e6[i] < e7[i] && e7[i] < e8[i]
                
                if bullCross && sig[i] < thresholds.lo { signal = .buy }
                else if bearCross && sig[i] > thresholds.up { signal = .sell }
                else if bearCross && rBull { signal = .exitLong }
                else if bullCross && rBear { signal = .exitShort }
            }
            
            readings.append(VMCOscillatorReading(
                timestamp: timestamp, sig: sig[i], sigSignal: sigSignal[i],
                momentum: momentum[i], signal: signal
            ))
        }
        
        let last = count - 1
        let ribbonBull = e1[last] > e2[last] && e2[last] > e3[last] && e3[last] > e4[last] && e4[last] > e5[last] && e5[last] > e6[last] && e6[last] > e7[last] && e7[last] > e8[last]
        let ribbonBear = e1[last] < e2[last] && e2[last] < e3[last] && e3[last] < e4[last] && e4[last] < e5[last] && e5[last] < e6[last] && e6[last] < e7[last] && e7[last] < e8[last]
        let spreadPct = abs(e1[last] - e8[last]) / max(close[last], 1e-9) * 100.0
        let spreadFalling = last >= 1 && spreadPct < (abs(e1[last-1] - e8[last-1]) / max(close[last-1], 1e-9) * 100.0)
        let compression = (spreadPct <= 0.30) && spreadFalling && sig[last] <= thresholds.lo
        
        return VMCOscillatorSnapshot(
            readings: readings,
            currentSig: sig[last], currentSigSignal: sigSignal[last],
            currentMomentum: momentum[last], currentSignal: readings.last?.signal,
            ribbonBull: ribbonBull, ribbonBear: ribbonBear, compression: compression,
            upperThreshold: thresholds.up, lowerThreshold: thresholds.lo
        )
    }
}
