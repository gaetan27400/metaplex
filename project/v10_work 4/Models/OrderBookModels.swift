//
//  OrderBookModels.swift
//  Journal de trading 2025
//
//  Modèles pour la heatmap de liquidation BTC style Coinglass
//

import Foundation

// MARK: - Binance Futures Kline

struct BinanceFuturesKline: Identifiable {
    let id = UUID()
    let openTime: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
}

// MARK: - Binance Depth Response (Futures)

struct BinanceDepthResponse: Codable {
    let lastUpdateId: Int
    let bids: [[String]]
    let asks: [[String]]
}

// MARK: - Liquidation Level

struct LiquidationLevel {
    let price: Double
    let estimatedVolume: Double  // volume USD estimé de liquidations
    let leverage: Int            // levier estimé (5x, 10x, 25x, 50x, 100x)
    let side: LiquidationSide
    
    enum LiquidationSide {
        case long   // liquidation de longs (en dessous du prix)
        case short  // liquidation de shorts (au dessus du prix)
    }
}

// MARK: - Heatmap Cell

struct LiqHeatmapCell {
    let timeIndex: Int
    let priceIndex: Int
    let intensity: Double   // 0...1
    let volume: Double      // volume estimé en USD
}

// MARK: - Heatmap Snapshot (une colonne temporelle)

struct HeatmapSnapshot: Identifiable {
    let id = UUID()
    let timestamp: Date
    let candle: BinanceFuturesKline?
    let liquidationLevels: [Double]  // intensité par bucket de prix (0...1)
}

// MARK: - Heatmap Time Period

enum LiqHeatmapPeriod: String, CaseIterable, Identifiable {
    case m15 = "M15"
    case h1 = "H1"
    case h4 = "H4"
    case h12 = "12h"
    case h24 = "24h"
    case d3 = "3j"
    case w1 = "1sem"
    case w2 = "2sem"
    case m1 = "1mois"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    /// Intervalle des bougies Binance
    var klineInterval: String {
        switch self {
        case .m15:  return "1m"
        case .h1:   return "1m"
        case .h4:   return "3m"
        case .h12:  return "5m"
        case .h24:  return "15m"
        case .d3:   return "30m"
        case .w1:   return "1h"
        case .w2:   return "2h"
        case .m1:   return "4h"
        }
    }
    
    /// Nombre de bougies à fetcher
    var klineLimit: Int {
        switch self {
        case .m15:  return 15    // 15m / 1m
        case .h1:   return 60    // 1h / 1m
        case .h4:   return 80    // 4h / 3m
        case .h12:  return 144   // 12h / 5m
        case .h24:  return 96    // 24h / 15m
        case .d3:   return 144   // 3j / 30m
        case .w1:   return 168   // 7j / 1h
        case .w2:   return 168   // 14j / 2h
        case .m1:   return 180   // 30j / 4h
        }
    }
    
    /// Nombre de colonnes max dans la heatmap
    var maxColumns: Int { klineLimit }
}

// MARK: - Heatmap Data (complet)

struct LiquidityHeatmapData {
    let period: LiqHeatmapPeriod
    let priceMin: Double
    let priceMax: Double
    let priceBucketCount: Int
    let snapshots: [HeatmapSnapshot]
    let candles: [BinanceFuturesKline]
    
    var priceStep: Double {
        guard priceBucketCount > 0 else { return 1 }
        return (priceMax - priceMin) / Double(priceBucketCount)
    }
    
    func priceForBucket(_ index: Int) -> Double {
        priceMin + Double(index) * priceStep + priceStep / 2
    }
    
    static let empty = LiquidityHeatmapData(
        period: .h24, priceMin: 0, priceMax: 0,
        priceBucketCount: 0, snapshots: [], candles: []
    )
}
