//
//  LiquidityHeatmapViewModel.swift
//  Journal de trading 2025
//
//  Heatmap de liquidation BTC style Coinglass
//  
//  Principe clé : les liquidations proches du prix DISPARAISSENT (déjà exécutées).
//  Seules les liquidations ÉLOIGNÉES du prix persistent comme bandes horizontales.
//  Quand le prix traverse un niveau → la bande est effacée.
//

import Foundation
import Combine

@MainActor
final class LiquidityHeatmapViewModel: ObservableObject {
    
    @Published var heatmapData: LiquidityHeatmapData = .empty
    @Published var selectedPeriod: LiqHeatmapPeriod = .h24
    @Published var currentPrice: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let symbol: String
    let priceBucketCount = 120
    private let leverages: [Int] = [5, 10, 25, 50, 100]
    private let leverageWeights: [Int: Double] = [
        5: 0.5, 10: 1.0, 25: 2.5, 50: 2.0, 100: 0.8
    ]
    
    init(symbol: String = "BTCUSDT") {
        self.symbol = symbol
    }
    
    func load() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let candles = try await fetchFuturesKlines()
            guard !candles.isEmpty else {
                errorMessage = "Aucune bougie"
                isLoading = false
                return
            }
            currentPrice = candles.last?.close ?? 0
            
            let depthProfile = try await fetchDepthProfile(candles: candles)
            let data = buildHeatmap(candles: candles, depthProfile: depthProfile)
            heatmapData = data
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func changePeriod(_ period: LiqHeatmapPeriod) {
        selectedPeriod = period
        Task { await load() }
    }
    
    // MARK: - Fetch
    
    private func fetchFuturesKlines() async throws -> [BinanceFuturesKline] {
        // Essayer d'abord Binance Futures (plus pertinent pour les liquidations)
        let futuresURL = "https://fapi.binance.com/fapi/v1/klines?symbol=\(symbol)&interval=\(selectedPeriod.klineInterval)&limit=\(selectedPeriod.klineLimit)"
        if let candles = try? await fetchKlines(from: futuresURL), !candles.isEmpty {
            return candles
        }
        
        // Fallback : Binance Spot (pour les cryptos sans futures)
        let spotURL = "https://api.binance.com/api/v3/klines?symbol=\(symbol)&interval=\(selectedPeriod.klineInterval)&limit=\(selectedPeriod.klineLimit)"
        return try await fetchKlines(from: spotURL)
    }
    
    private func fetchKlines(from urlStr: String) async throws -> [BinanceFuturesKline] {
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }
        let (data, _) = try await NetworkSession.market.data(from: url)
        guard let arrays = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            throw URLError(.cannotParseResponse)
        }
        return arrays.compactMap { arr -> BinanceFuturesKline? in
            guard arr.count >= 6,
                  let t = arr[0] as? Double,
                  let o = arr[1] as? String, let ov = Double(o),
                  let h = arr[2] as? String, let hv = Double(h),
                  let l = arr[3] as? String, let lv = Double(l),
                  let c = arr[4] as? String, let cv = Double(c),
                  let v = arr[5] as? String, let vv = Double(v)
            else { return nil }
            return BinanceFuturesKline(openTime: Date(timeIntervalSince1970: t / 1000),
                                       open: ov, high: hv, low: lv, close: cv, volume: vv)
        }
    }
    
    private func fetchDepthProfile(candles: [BinanceFuturesKline]) async throws -> [Double] {
        let (pMin, pMax, step) = priceRange(candles: candles)
        guard step > 0 else { return [Double](repeating: 0, count: priceBucketCount) }
        
        let futuresDepth = "https://fapi.binance.com/fapi/v1/depth?symbol=\(symbol)&limit=1000"
        let spotDepth = "https://api.binance.com/api/v3/depth?symbol=\(symbol)&limit=1000"
        
        var resp: BinanceDepthResponse
        if let url = URL(string: futuresDepth),
           let (d, _) = try? await NetworkSession.market.data(from: url),
           let r = try? JSONDecoder().decode(BinanceDepthResponse.self, from: d) {
            resp = r
        } else if let url = URL(string: spotDepth),
                  let (d, _) = try? await NetworkSession.market.data(from: url),
                  let r = try? JSONDecoder().decode(BinanceDepthResponse.self, from: d) {
            resp = r
        } else {
            return [Double](repeating: 0, count: priceBucketCount)
        }
        
        var profile = [Double](repeating: 0, count: priceBucketCount)
        for arr in resp.bids + resp.asks {
            guard arr.count >= 2, let p = Double(arr[0]), let q = Double(arr[1]) else { continue }
            let idx = Int((p - pMin) / step)
            if idx >= 0 && idx < priceBucketCount { profile[idx] += q * p }
        }
        let mx = profile.max() ?? 1
        if mx > 0 { profile = profile.map { $0 / mx } }
        return profile
    }
    
    private func priceRange(candles: [BinanceFuturesKline]) -> (min: Double, max: Double, step: Double) {
        let rawMin = candles.map(\.low).min() ?? 0
        let rawMax = candles.map(\.high).max() ?? 0
        let pad = (rawMax - rawMin) * 0.20
        let pMin = rawMin - pad
        let pMax = rawMax + pad
        let step = (pMax - pMin) / Double(priceBucketCount)
        return (pMin, pMax, step)
    }
    
    // MARK: - Build Heatmap
    
    private func buildHeatmap(
        candles: [BinanceFuturesKline],
        depthProfile: [Double]
    ) -> LiquidityHeatmapData {
        
        let (pMin, pMax, step) = priceRange(candles: candles)
        guard step > 0 else { return .empty }
        
        let colCount = candles.count
        
        // === Phase 1 : Calculer le swept range (zone traversée par le prix) ===
        // Pour chaque colonne, tracker le min/max historique du prix jusqu'à ce point
        // Les buckets dans cette zone sont "swept" → intensité = 0
        
        // D'abord, calculer pour chaque colonne la plage de prix couverte
        // par le mouvement du prix depuis le début
        var runningLow = candles.first?.low ?? 0
        var runningHigh = candles.first?.high ?? 0
        var sweptLows = [Double]()
        var sweptHighs = [Double]()
        
        for candle in candles {
            runningLow = min(runningLow, candle.low)
            runningHigh = max(runningHigh, candle.high)
            sweptLows.append(runningLow)
            sweptHighs.append(runningHigh)
        }
        
        // === Phase 2 : Pour chaque bougie, calculer les liquidations ===
        // Et les propager en avant, mais EFFACER quand le prix traverse
        
        var matrix = [[Double]](repeating: [Double](repeating: 0, count: priceBucketCount), count: colCount)
        
        for srcIdx in 0..<colCount {
            let src = candles[srcIdx]
            let refPrice = src.close
            
            // Calculer les niveaux de liq pour cette bougie
            for lev in leverages {
                let w = leverageWeights[lev] ?? 1.0
                let vol = src.volume * w
                
                let longLiq = refPrice * (1.0 - 1.0 / Double(lev))
                let shortLiq = refPrice * (1.0 + 1.0 / Double(lev))
                
                // Propager vers l'avant
                for destIdx in srcIdx..<colCount {
                    let age = Double(destIdx - srcIdx)
                    let decay = exp(-age * 0.005) // décroissance lente
                    
                    // Long liquidation (en dessous du prix)
                    let longBucket = Int((longLiq - pMin) / step)
                    if longBucket >= 0 && longBucket < priceBucketCount {
                        // Vérifier si ce niveau a été swept
                        let bucketPrice = pMin + Double(longBucket) * step + step / 2
                        let swept = bucketPrice >= sweptLows[destIdx] && bucketPrice <= sweptHighs[destIdx]
                        // MAIS : on veut savoir si swept APRÈS srcIdx
                        let sweptAfterSrc = wasSweptBetween(price: bucketPrice, candles: candles, from: srcIdx + 1, to: destIdx)
                        
                        if !sweptAfterSrc {
                            spreadGaussian(&matrix[destIdx], center: longBucket, volume: vol * decay, sigma: 1.2)
                        }
                    }
                    
                    // Short liquidation (au dessus du prix)
                    let shortBucket = Int((shortLiq - pMin) / step)
                    if shortBucket >= 0 && shortBucket < priceBucketCount {
                        let bucketPrice = pMin + Double(shortBucket) * step + step / 2
                        let sweptAfterSrc = wasSweptBetween(price: bucketPrice, candles: candles, from: srcIdx + 1, to: destIdx)
                        
                        if !sweptAfterSrc {
                            spreadGaussian(&matrix[destIdx], center: shortBucket, volume: vol * decay, sigma: 1.2)
                        }
                    }
                }
            }
        }
        
        // === Phase 3 : Ajouter depth profile aux dernières colonnes ===
        if colCount > 0 {
            let lastVol = candles.last?.volume ?? 1
            let depthStart = max(0, colCount - colCount / 4)
            for col in depthStart..<colCount {
                let fade = Double(col - depthStart) / Double(max(1, colCount - depthStart))
                for b in 0..<priceBucketCount {
                    matrix[col][b] += depthProfile[b] * lastVol * 0.5 * fade
                }
            }
        }
        
        // === Phase 4 : Normalisation globale ===
        var globalMax: Double = 0
        for col in 0..<colCount {
            globalMax = max(globalMax, matrix[col].max() ?? 0)
        }
        
        var snapshots: [HeatmapSnapshot] = []
        for (i, candle) in candles.enumerated() {
            let levels: [Double]
            if globalMax > 0 {
                levels = matrix[i].map { pow($0 / globalMax, 0.45) }
            } else {
                levels = matrix[i]
            }
            snapshots.append(HeatmapSnapshot(timestamp: candle.openTime, candle: candle, liquidationLevels: levels))
        }
        
        return LiquidityHeatmapData(
            period: selectedPeriod,
            priceMin: pMin, priceMax: pMax,
            priceBucketCount: priceBucketCount,
            snapshots: snapshots, candles: candles
        )
    }
    
    // MARK: - Helpers
    
    /// Vérifie si un prix a été traversé par une bougie entre from et to (inclusive)
    private func wasSweptBetween(price: Double, candles: [BinanceFuturesKline], from: Int, to: Int) -> Bool {
        guard from <= to else { return false }
        let safeFrom = max(0, from)
        let safeTo = min(candles.count - 1, to)
        for i in safeFrom...safeTo {
            if price >= candles[i].low && price <= candles[i].high {
                return true
            }
        }
        return false
    }
    
    private func spreadGaussian(_ buckets: inout [Double], center: Int, volume: Double, sigma: Double) {
        let range = Int(sigma * 2.5)
        for offset in -range...range {
            let idx = center + offset
            guard idx >= 0 && idx < buckets.count else { continue }
            let g = exp(-0.5 * pow(Double(offset) / sigma, 2))
            buckets[idx] += volume * g
        }
    }
}
