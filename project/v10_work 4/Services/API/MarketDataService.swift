//
//  MarketDataService.swift
//  Journal de trading 2025
//
//  Routage multi-assets : Crypto → Binance, Actions → Finnhub → fallback TwelveData
//  Plus aucune vérification de clé API locale.
//

import Foundation

struct Candle: Codable {
    let openTime: TimeInterval
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let closeTime: TimeInterval
}

final class MarketDataService {
    static let shared = MarketDataService()

    /// Session optimisée via NetworkSession.market
    private static var session: URLSession { NetworkSession.market }

    private init() {}

    /// Symbole actif sélectionné (partagé depuis AIAssistantView)
    var activeMarketSymbol: MarketSymbol = .btcDefault

    // MARK: - Fetch Klines (par symbole string)

    func fetchKlines(symbol: String, interval: String, limit: Int = 200) async throws -> [Candle] {
        // Si le symbole actif correspond ET n'est pas crypto → Finnhub ou TwelveData
        if activeMarketSymbol.symbol == symbol && !activeMarketSymbol.isCrypto {
            // Priorité 1 : Finnhub via Cloud Function
            do {
                let resolution = FinnhubService.finnhubResolution(from: interval)
                return try await FinnhubService.shared.fetchStockCandles(
                    symbol: symbol,
                    resolution: resolution,
                    limit: limit
                )
            } catch {
                Logger.api.warning("Finnhub failed for \(symbol), falling back to TwelveData: \(error.localizedDescription)")
            }

            // Priorité 2 : TwelveData via Cloud Function
            let tdInterval = MarketSymbol.twelveDataInterval(from: interval)
            return try await TwelveDataService.shared.fetchTimeSeries(
                symbol: activeMarketSymbol.twelveDataSymbol,
                interval: tdInterval,
                outputSize: limit
            )
        }

        // Sinon Binance (crypto par défaut — appel direct, pas de clé nécessaire)
        let urlString = "https://api.binance.com/api/v3/klines?symbol=\(symbol)&interval=\(interval)&limit=\(limit)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        let (data, response) = try await MarketDataService.session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.invalidResponse }
        let raw = try JSONSerialization.jsonObject(with: data) as? [[Any]] ?? []
        let candles: [Candle] = raw.compactMap { arr in
            guard arr.count >= 7,
                  let openTime = arr[0] as? Double,
                  let openStr = arr[1] as? String,
                  let highStr = arr[2] as? String,
                  let lowStr = arr[3] as? String,
                  let closeStr = arr[4] as? String,
                  let volumeStr = arr[5] as? String,
                  let closeTime = arr[6] as? Double,
                  let open = Double(openStr),
                  let high = Double(highStr),
                  let low = Double(lowStr),
                  let close = Double(closeStr),
                  let volume = Double(volumeStr) else { return nil }
            return Candle(openTime: openTime / 1000.0, open: open, high: high, low: low, close: close, volume: volume, closeTime: closeTime / 1000.0)
        }
        return candles
    }

    // MARK: - Fetch Klines (par MarketSymbol)

    func fetchKlines(marketSymbol: MarketSymbol, interval: String, limit: Int = 200) async throws -> [Candle] {
        if marketSymbol.isCrypto, let binanceSymbol = marketSymbol.binanceSymbol {
            return try await fetchKlines(symbol: binanceSymbol, interval: interval, limit: limit)
        } else {
            // Actions : Finnhub en priorité via Cloud Function
            do {
                let resolution = FinnhubService.finnhubResolution(from: interval)
                return try await FinnhubService.shared.fetchStockCandles(
                    symbol: marketSymbol.symbol,
                    resolution: resolution,
                    limit: limit
                )
            } catch {
                Logger.api.warning("Finnhub failed, falling back to TwelveData: \(error.localizedDescription)")
            }
            // Fallback TwelveData via Cloud Function
            let tdInterval = MarketSymbol.twelveDataInterval(from: interval)
            return try await TwelveDataService.shared.fetchTimeSeries(
                symbol: marketSymbol.twelveDataSymbol,
                interval: tdInterval,
                outputSize: limit
            )
        }
    }
}
