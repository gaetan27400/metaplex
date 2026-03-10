//
//  VMCService.swift
//  Journal de trading 2025
//
//  Service pour récupérer et calculer les snapshots VMC
//

import Foundation
import SwiftUI

actor VMCService {
    static let shared = VMCService()
    private let calculator = VMCCalculator.self
    
    private init() {}
    
    /// Récupère un snapshot VMC complet pour un symbole
    private static func candleLimit(for tf: VMCTimeframe) -> Int {
        switch tf {
        case .m1:           return 60
        case .m5:           return 80
        case .m15, .m30:    return 100
        case .h1, .h2:      return 150
        case .h4, .h12, .d1, .w1, .month1: return 200
        }
    }

    func fetchVMCSnapshot(
        symbol: String,
        previousGlobalScore: Double? = nil,
        config: VMCCalculator.Config = VMCCalculator.Config()
    ) async throws -> VMCSnapshot {
        // Récupérer les bougies pour tous les timeframes
        var candlesByTimeframe: [VMCTimeframe: [Candle]] = [:]
        
        // Pour les non-crypto, utiliser un sous-ensemble de TF pour limiter les appels API
        // Finnhub = 60 req/min, TwelveData = 8 req/min
        let activeSymbol = MarketDataService.shared.activeMarketSymbol
        let timeframes: [VMCTimeframe] = activeSymbol.isCrypto
            ? VMCTimeframe.allCases
            : [.m5, .m15, .h1, .h4, .d1, .w1]
        
        // Récupérer les données en parallèle pour les timeframes sélectionnés
        await withTaskGroup(of: (VMCTimeframe, [Candle]?).self) { group in
            for tf in timeframes {
                group.addTask {
                    do {
                        let candles = try await MarketDataService.shared.fetchKlines(
                            symbol: symbol,
                            interval: tf.binanceInterval,
                            limit: Self.candleLimit(for: tf)
                        )
                        return (tf, candles)
                    } catch {
                        Logger.api.warning("Failed to fetch candles for \(tf.rawValue): \(error.localizedDescription)")
                        return (tf, nil)
                    }
                }
            }
            
            for await (tf, candles) in group {
                if let candles = candles {
                    candlesByTimeframe[tf] = candles
                }
            }
        }
        
        // Calculer le snapshot VMC
        return calculator.createSnapshot(
            symbol: symbol,
            candlesByTimeframe: candlesByTimeframe,
            previousGlobalScore: previousGlobalScore,
            config: config
        )
    }
    
    /// Récupère un snapshot VMC avec cache (pour éviter les appels répétés)
    private var snapshotCache: [String: (snapshot: VMCSnapshot, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 120 // 2 minutes
    
    func fetchVMCSnapshotCached(
        symbol: String,
        previousGlobalScore: Double? = nil,
        config: VMCCalculator.Config = VMCCalculator.Config()
    ) async throws -> VMCSnapshot {
        // Vérifier le cache
        if let cached = snapshotCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            return cached.snapshot
        }
        
        // Récupérer un nouveau snapshot
        let snapshot = try await fetchVMCSnapshot(
            symbol: symbol,
            previousGlobalScore: previousGlobalScore,
            config: config
        )
        
        // Mettre en cache
        snapshotCache[symbol] = (snapshot, Date())
        
        return snapshot
    }
    
    /// Nettoie le cache
    func clearCache() {
        snapshotCache.removeAll()
        oscillatorCache.removeAll()
    }
    
    // MARK: - VMC Oscillator (single timeframe, time series)
    
    private var oscillatorCache: [String: (snapshot: VMCOscillatorSnapshot, timestamp: Date)] = [:]
    
    private func oscillatorCacheValidity(for interval: String) -> TimeInterval {
        switch interval {
        case "1m", "3m", "5m": return 60   // 1 minute
        case "15m", "30m":     return 120  // 2 minutes
        case "1h", "2h", "4h": return 600  // 10 minutes
        default:               return 900  // 15 minutes
        }
    }
    
    func fetchVMCOscillatorSnapshot(
        symbol: String,
        interval: String = "1h",
        limit: Int = 200,
        preset: IndicatorPreset = .swing
    ) async throws -> VMCOscillatorSnapshot {
        let cacheKey = "\(symbol)_\(interval)"
        if let cached = oscillatorCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < oscillatorCacheValidity(for: interval) {
            return cached.snapshot
        }
        
        let candles = try await MarketDataService.shared.fetchKlines(
            symbol: symbol, interval: interval, limit: limit
        )
        
        guard let snapshot = VMCIndicator.evaluateSeries(
            candles: candles, preset: preset, tailCount: 100
        ) else {
            throw APIError.invalidResponse
        }
        
        oscillatorCache[cacheKey] = (snapshot, Date())
        return snapshot
    }
}
