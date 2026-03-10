//
//  MarketSymbol.swift
//  Journal de trading 2025
//
//  Modèle d'actif unifié (crypto, actions, forex, ETF, commodities)
//

import Foundation

// MARK: - InstrumentType extensions pour multi-assets

extension InstrumentType {
    var marketIcon: String {
        switch self {
        case .crypto: return "bitcoinsign.circle.fill"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .forex: return "dollarsign.arrow.circlepath"
        case .futures: return "leaf.fill"
        case .options: return "building.columns.fill"
        }
    }
    
    var marketDisplayName: String {
        switch self {
        case .crypto: return "Crypto"
        case .stocks: return "Action"
        case .forex: return "Forex"
        case .futures: return "Futures"
        case .options: return "Options"
        }
    }
}

// MARK: - Market Symbol

struct MarketSymbol: Identifiable, Equatable {
    let id: String
    let symbol: String
    let displayName: String
    let exchange: String?
    let instrumentType: InstrumentType
    let currency: String?
    
    init(
        symbol: String,
        displayName: String,
        exchange: String? = nil,
        instrumentType: InstrumentType,
        currency: String? = "USD"
    ) {
        self.id = "\(symbol)_\(exchange ?? "unknown")"
        self.symbol = symbol
        self.displayName = displayName
        self.exchange = exchange
        self.instrumentType = instrumentType
        self.currency = currency
    }
    
    var isCrypto: Bool { instrumentType == .crypto }
    var binanceSymbol: String? { isCrypto ? symbol : nil }
    var twelveDataSymbol: String { symbol }
    
    // MARK: - Default
    static let btcDefault = MarketSymbol(
        symbol: "BTCUSDT",
        displayName: "Bitcoin",
        exchange: "Binance",
        instrumentType: .crypto
    )
    
    // MARK: - Interval Mapping Binance → TwelveData
    static func twelveDataInterval(from binanceInterval: String) -> String {
        switch binanceInterval {
        case "1m": return "1min"
        case "3m": return "3min"
        case "5m": return "5min"
        case "15m": return "15min"
        case "30m": return "30min"
        case "45m": return "45min"
        case "1h": return "1h"
        case "2h": return "2h"
        case "4h": return "4h"
        case "12h": return "4h" // TwelveData ne supporte pas 12h, fallback sur 4h
        case "1d": return "1day"
        case "1w": return "1week"
        case "1M": return "1month"
        default: return binanceInterval
        }
    }
}
