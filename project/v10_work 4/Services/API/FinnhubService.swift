//
//  FinnhubService.swift
//  Journal de trading 2025
//
//  Service Finnhub — passe désormais par Firebase Cloud Functions.
//  Plus aucune clé API côté iOS.
//

import Foundation

final class FinnhubService {
    static let shared = FinnhubService()
    private init() {}

    // Plus besoin de clé locale
    var hasAPIKey: Bool { true }

    // MARK: - Résolution mapping (conservé tel quel)

    static func finnhubResolution(from binanceInterval: String) -> String {
        switch binanceInterval {
        case "1m":  return "1"
        case "5m":  return "5"
        case "15m": return "15"
        case "30m": return "30"
        case "1h":  return "60"
        case "2h":  return "60"
        case "4h":  return "60"
        case "12h": return "D"
        case "1d":  return "D"
        case "1w":  return "W"
        case "1M":  return "M"
        default:    return "D"
        }
    }

    /// Calcule le range de dates
    private func dateRange(for resolution: String, limit: Int) -> (from: Int, to: Int) {
        let now = Int(Date().timeIntervalSince1970)
        let secondsPerCandle: Int
        switch resolution {
        case "1":  secondsPerCandle = 60
        case "5":  secondsPerCandle = 300
        case "15": secondsPerCandle = 900
        case "30": secondsPerCandle = 1800
        case "60": secondsPerCandle = 3600
        case "D":  secondsPerCandle = 86400
        case "W":  secondsPerCandle = 604800
        case "M":  secondsPerCandle = 2_592_000
        default:   secondsPerCandle = 86400
        }
        let from = now - (secondsPerCandle * limit)
        return (from, now)
    }

    // MARK: - Stock Candles → [Candle]

    func fetchStockCandles(
        symbol: String,
        resolution: String,
        limit: Int = 200
    ) async throws -> [Candle] {
        let range = dateRange(for: resolution, limit: limit)
        return try await CloudFunctionService.shared.fetchStockCandles(
            symbol: symbol,
            resolution: resolution,
            from: range.from,
            to: range.to
        )
    }

    // MARK: - Symbol Search

    func searchSymbols(query: String) async throws -> [MarketSymbol] {
        return try await CloudFunctionService.shared.searchFinnhubSymbols(query: query)
    }
}

// MARK: - Errors (conservés pour compatibilité)

enum FinnhubError: LocalizedError {
    case noAPIKey
    case rateLimited
    case noData
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "Service Finnhub non disponible."
        case .rateLimited: return "Limite d'appels Finnhub atteinte. Réessayez."
        case .noData: return "Aucune donnée disponible pour ce symbole."
        case .apiError(let msg): return "Erreur Finnhub: \(msg)"
        }
    }
}

// MARK: - Response Models (conservés pour compatibilité)

struct FinnhubCandleResponse: Decodable {
    let c: [Double]?
    let h: [Double]?
    let l: [Double]?
    let o: [Double]?
    let t: [Int]?
    let v: [Double]?
    let s: String
}

struct FinnhubSearchResponse: Decodable {
    let count: Int?
    let result: [FinnhubSearchItem]
}

struct FinnhubSearchItem: Decodable {
    let description: String?
    let displaySymbol: String?
    let symbol: String
    let type: String?
}
