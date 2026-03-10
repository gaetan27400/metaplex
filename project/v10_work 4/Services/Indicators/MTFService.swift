//
//  MTFService.swift
//  Journal de trading 2025
//
//  Service pour récupérer et combiner RSI + VMC en MTF Snapshot
//  Optimisation : un seul fetch de bougies par TF, partagé entre RSI et VMC
//

import Foundation

final class MTFService {
    static let shared = MTFService()
    private let combiner = MTFCombiner.self
    
    private init() {}
    
    /// Récupère un snapshot MTF combiné (RSI + VMC) en mutualisant les appels API
    /// Nombre de bougies adapté au timeframe — les TF longs n'ont pas besoin de 200 bougies
    /// RSI et VMC convergent en ~50-100 bougies, 200 est excessif pour m1/m5
    private static func candleLimit(for tf: VMCTimeframe) -> Int {
        switch tf {
        case .m1:           return 60   // 1h d'historique suffit
        case .m5:           return 80   // ~7h
        case .m15, .m30:    return 100  // cohérent avec la période RSI
        case .h1, .h2:      return 150  // indicateurs bien convergés
        case .h4, .h12:     return 200  // timeframes longs : full
        case .d1, .w1, .month1: return 200
        }
    }

    func fetchMTFSnapshot(
        symbol: String,
        previousGlobalRSI: Double? = nil,
        previousGlobalVMC: Double? = nil
    ) async throws -> MTFSnapshot {
        // Déterminer les timeframes selon le type d'actif
        let activeSymbol = MarketDataService.shared.activeMarketSymbol
        // Pour crypto: exclure m1 (trop bruité, peu utile pour MTF trading)
        // = 10 TF au lieu de 11 → économise ~10% des appels réseau
        let timeframes: [VMCTimeframe] = activeSymbol.isCrypto
            ? VMCTimeframe.allCases.filter { $0 != .m1 }
            : [.m5, .m15, .h1, .h4, .d1, .w1]
        
        // === UN SEUL FETCH par timeframe (mutualisé RSI + VMC) ===
        var candlesByTimeframe: [VMCTimeframe: [Candle]] = [:]
        
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
                        Logger.api.warning("MTF fetch failed for \(tf.rawValue): \(error.localizedDescription)")
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
        
        // === Calculer RSI et VMC avec les MÊMES données ===
        let rsiSnapshot = RSICalculator.createSnapshot(
            symbol: symbol,
            candlesByTimeframe: candlesByTimeframe,
            previousGlobalRSI: previousGlobalRSI
        )
        
        let vmcSnapshot = VMCCalculator.createSnapshot(
            symbol: symbol,
            candlesByTimeframe: candlesByTimeframe,
            previousGlobalScore: previousGlobalVMC
        )
        
        // Combiner en MTF Snapshot
        return combiner.createMTFSnapshot(
            symbol: symbol,
            rsiSnapshot: rsiSnapshot,
            vmcSnapshot: vmcSnapshot
        )
    }
    
    /// Récupère un snapshot MTF avec cache
    private var snapshotCache: [String: (snapshot: MTFSnapshot, timestamp: Date)] = [:]
    private let cacheValidityDuration: TimeInterval = 120 // 2 minutes (trades lents, pas besoin de refresh constant)
    
    func fetchMTFSnapshotCached(
        symbol: String,
        previousGlobalRSI: Double? = nil,
        previousGlobalVMC: Double? = nil
    ) async throws -> MTFSnapshot {
        // Vérifier le cache
        if let cached = snapshotCache[symbol],
           Date().timeIntervalSince(cached.timestamp) < cacheValidityDuration {
            return cached.snapshot
        }
        
        // Récupérer un nouveau snapshot
        let snapshot = try await fetchMTFSnapshot(
            symbol: symbol,
            previousGlobalRSI: previousGlobalRSI,
            previousGlobalVMC: previousGlobalVMC
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
