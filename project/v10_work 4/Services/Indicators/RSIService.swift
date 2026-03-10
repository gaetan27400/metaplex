//
//  RSIService.swift
//  Journal de trading 2025
//
//  Service pour récupérer et calculer les snapshots RSI
//

import Foundation

actor RSIService {
    static let shared = RSIService()
    private let calculator = RSICalculator.self
    
    private init() {}
    
    /// Récupère un snapshot RSI complet pour un symbole
    func fetchRSISnapshot(
        symbol: String,
        previousGlobalRSI: Double? = nil,
        config: RSICalculator.Config = RSICalculator.Config()
    ) async throws -> RSISnapshot {
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
                            limit: 200
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
        
        // Calculer le snapshot RSI
        return calculator.createSnapshot(
            symbol: symbol,
            candlesByTimeframe: candlesByTimeframe,
            previousGlobalRSI: previousGlobalRSI,
            config: config
        )
    }
    
    /// Récupère un snapshot RSI avec cache (pour éviter les appels répétés)
    private var snapshotCache: [String: (snapshot: RSISnapshot, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 60 // 1 minute
    
    func fetchRSISnapshotCached(
        symbol: String,
        previousGlobalRSI: Double? = nil,
        config: RSICalculator.Config = RSICalculator.Config()
    ) async throws -> RSISnapshot {
        // Vérifier le cache
        if let cached = snapshotCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            return cached.snapshot
        }
        
        // Récupérer un nouveau snapshot
        let snapshot = try await fetchRSISnapshot(
            symbol: symbol,
            previousGlobalRSI: previousGlobalRSI,
            config: config
        )
        
        // Mettre en cache
        snapshotCache[symbol] = (snapshot, Date())
        
        return snapshot
    }
    
    /// Nettoie le cache
    func clearCache() {
        snapshotCache.removeAll()
    }
}
