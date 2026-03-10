//
//  WTService.swift
//  Journal de trading 2025
//
//  Service pour récupérer et calculer les snapshots Wave Trend
//

import Foundation

actor WTService {
    static let shared = WTService()
    private let calculator = WTCalculator()
    
    private init() {}
    
    /// Récupère un snapshot Wave Trend complet pour un symbole
    func fetchWTSnapshot(
        symbol: String,
        interval: String = "1h", // Par défaut 1h pour l'oscillateur
        limit: Int = 200,
        config: WTConfig
    ) async throws -> WTSnapshot {
        // Récupérer les bougies
        let candles = try await MarketDataService.shared.fetchKlines(
            symbol: symbol,
            interval: interval,
            limit: limit
        )
        
        // Convertir en OHLC
        let prices = candles.map { $0.toOHLC }
        
        // Calculer le snapshot
        return calculator.createSnapshot(
            symbol: symbol,
            prices: prices
        )
    }
    
    /// Récupère un snapshot WT avec cache adaptatif par timeframe
    private struct CacheEntry {
        let snapshot: WTSnapshot
        let timestamp: Date
        let configHash: String // Hash des paramètres WT pour invalidation
    }
    
    private var snapshotCache: [String: CacheEntry] = [:]
    
    /// TTL adaptatif selon le timeframe
    private func cacheValidityDuration(for interval: String) -> TimeInterval {
        switch interval {
        case "1m", "3m", "5m":
            return 60   // 1 minute — les bougies 1m ont 60s de validité
        case "15m", "30m", "45m":
            return 120  // 2 minutes
        case "1h", "2h", "3h", "4h", "6h", "8h", "12h":
            return 600  // 10 minutes — signal H1+ peu volatil
        case "1d", "3d":
            return 3600 // 1 heure
        case "1w", "1M":
            return 7200 // 2 heures
        default:
            return 120  // 2 minutes par défaut
        }
    }
    
    /// Génère un hash des paramètres WT pour invalider le cache si les paramètres changent
    private func configHash(_ config: WTConfig) -> String {
        return "\(config.channelLength)_\(config.averageLength)_\(config.overboughtLevel2)_\(config.oversoldLevel2)_\(config.onlySmartBuyReversal)_\(config.onlySmartSellReversal)"
    }
    
    func fetchWTSnapshotCached(
        symbol: String,
        interval: String = "1h",
        limit: Int = 200,
        config: WTConfig
    ) async throws -> WTSnapshot {
        let cacheKey = "\(symbol)_\(interval)"
        let currentConfigHash = configHash(config)
        let ttl = cacheValidityDuration(for: interval)
        
        // Vérifier le cache
        if let cached = snapshotCache[cacheKey] {
            let age = Date().timeIntervalSince(cached.timestamp)
            
            // Cache valide si :
            // 1. Pas expiré (age < ttl)
            // 2. Config identique (même hash)
            if age < ttl && cached.configHash == currentConfigHash {
                return cached.snapshot
            }
        }
        
        // Récupérer un nouveau snapshot
        let snapshot = try await fetchWTSnapshot(
            symbol: symbol,
            interval: interval,
            limit: limit,
            config: config
        )
        
        // Mettre en cache
        snapshotCache[cacheKey] = CacheEntry(
            snapshot: snapshot,
            timestamp: Date(),
            configHash: currentConfigHash
        )
        
        return snapshot
    }
    
    /// Nettoie le cache expiré (appelé périodiquement)
    func cleanExpiredCache() {
        let now = Date()
        snapshotCache = snapshotCache.filter { key, entry in
            // Extraire l'interval depuis la clé
            let components = key.split(separator: "_")
            guard components.count >= 2 else { return false }
            let interval = String(components[1])
            let ttl = cacheValidityDuration(for: interval)
            return now.timeIntervalSince(entry.timestamp) < ttl
        }
    }
    
    /// Nettoie complètement le cache
    func clearCache() {
        snapshotCache.removeAll()
    }
}
