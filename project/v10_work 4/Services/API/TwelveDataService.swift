//
//  TwelveDataService.swift
//  Journal de trading 2025
//
//  Service TwelveData — passe désormais par Firebase Cloud Functions.
//  Plus aucune clé API côté iOS.
//

import Foundation

final class TwelveDataService {
    static let shared = TwelveDataService()
    private init() {}

    // Plus besoin de clé locale — la Cloud Function gère tout
    var hasAPIKey: Bool { true }

    // MARK: - Symbol Search

    func searchSymbols(query: String) async throws -> [MarketSymbol] {
        return try await CloudFunctionService.shared.searchSymbols(query: query)
    }

    // MARK: - Time Series → [Candle]

    func fetchTimeSeries(
        symbol: String,
        interval: String,
        outputSize: Int = 200
    ) async throws -> [Candle] {
        return try await CloudFunctionService.shared.fetchTimeSeries(
            symbol: symbol,
            interval: interval,
            outputSize: outputSize
        )
    }

    // MARK: - Binance Crypto Search (no key needed — appel direct conservé)

    func searchBinanceCrypto(query: String) async throws -> [MarketSymbol] {
        let urlString = "https://api.binance.com/api/v3/exchangeInfo"
        guard let url = URL(string: urlString) else { return [] }

        let (data, _) = try await NetworkSession.market.data(from: url)

        struct BinanceExchangeInfo: Decodable {
            let symbols: [BinanceSymbol]
        }
        struct BinanceSymbol: Decodable {
            let symbol: String
            let baseAsset: String
            let quoteAsset: String
            let status: String
        }

        let info = try JSONDecoder().decode(BinanceExchangeInfo.self, from: data)
        let q = query.uppercased()

        return info.symbols
            .filter { $0.status == "TRADING" && $0.quoteAsset == "USDT" }
            .filter { $0.symbol.contains(q) || $0.baseAsset.contains(q) }
            .prefix(10)
            .map { sym in
                MarketSymbol(
                    symbol: sym.symbol,
                    displayName: sym.baseAsset,
                    exchange: "Binance",
                    instrumentType: .crypto,
                    currency: "USDT"
                )
            }
    }
}

// MARK: - Errors (conservés pour compatibilité)

enum TwelveDataError: LocalizedError {
    case noAPIKey
    case apiError(String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Service TwelveData non disponible."
        case .apiError(let msg): return "Erreur TwelveData: \(msg)"
        case .rateLimited: return "Limite d'appels atteinte. Réessayez."
        }
    }
}

// MARK: - Response Models (conservés pour compatibilité)

struct TDSearchResponse: Decodable {
    let data: [TDSearchItem]
}

struct TDSearchItem: Decodable {
    let symbol: String
    let instrument_name: String?
    let exchange: String?
    let instrument_type: String?
    let currency: String?
}

struct TDTimeSeriesResponse: Decodable {
    let status: String?
    let message: String?
    let values: [TDOHLC]?
}

struct TDOHLC: Decodable {
    let datetime: String
    let open: String
    let high: String
    let low: String
    let close: String
    let volume: String?
}
