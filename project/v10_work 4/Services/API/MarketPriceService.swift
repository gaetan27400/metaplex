//
//  MarketPriceService.swift
//  Journal de trading 2025
//
//  Service pour récupérer les prix de marché en temps réel
//

import Foundation

final class MarketPriceService {
    static let shared = MarketPriceService()
    
    private let baseURL = "https://api.binance.com/api/v3"
    private var priceCache: [String: (price: Double, timestamp: Date)] = [:]
    private let cacheValidity: TimeInterval = 5 // 5 secondes
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Récupère le prix actuel d'un symbole
    func getCurrentPrice(for symbol: String) async throws -> Double {
        let normalizedSymbol = normalizeSymbol(symbol)
        
        // Vérifier le cache
        if let cached = priceCache[normalizedSymbol],
           Date().timeIntervalSince(cached.timestamp) < cacheValidity {
            return cached.price
        }
        
        // Récupérer depuis l'API
        let urlString = "\(baseURL)/ticker/price?symbol=\(normalizedSymbol)"
        guard let url = URL(string: urlString) else {
            throw MarketPriceError.invalidSymbol
        }
        
        do {
            let (data, _) = try await NetworkSession.market.data(from: url)
            let response = try JSONDecoder().decode(BinancePriceResponse.self, from: data)
            
            let price = Double(response.price) ?? 0.0
            
            // Mettre en cache
            priceCache[normalizedSymbol] = (price: price, timestamp: Date())
            
            return price
        } catch {
            print("❌ [MarketPriceService] Erreur lors de la récupération du prix pour \(symbol): \(error)")
            throw MarketPriceError.networkError(error.localizedDescription)
        }
    }
    
    /// Récupère les prix pour plusieurs symboles en une seule requête
    func getCurrentPrices(for symbols: [String]) async throws -> [String: Double] {
        var prices: [String: Double] = [:]
        
        // Récupérer tous les prix depuis l'API Binance
        let urlString = "\(baseURL)/ticker/price"
        guard let url = URL(string: urlString) else {
            throw MarketPriceError.invalidURL
        }
        
        do {
            let (data, _) = try await NetworkSession.market.data(from: url)
            let allPrices = try JSONDecoder().decode([BinancePriceResponse].self, from: data)
            
            // Créer un dictionnaire pour recherche rapide
            let priceDict = Dictionary(uniqueKeysWithValues: allPrices.compactMap { response -> (String, Double)? in
                guard let price = Double(response.price) else { return nil }
                return (response.symbol, price)
            })
            
            // Extraire les prix demandés
            for symbol in symbols {
                let normalized = normalizeSymbol(symbol)
                if let price = priceDict[normalized] {
                    prices[symbol] = price
                    priceCache[normalized] = (price: price, timestamp: Date())
                }
            }
            
            return prices
        } catch {
            print("❌ [MarketPriceService] Erreur lors de la récupération des prix: \(error)")
            throw MarketPriceError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Helper Methods
    
    private func normalizeSymbol(_ symbol: String) -> String {
        // Convertir BTCUSDT, BTC/USDT, BTC-USDT en BTCUSDT
        return symbol.uppercased()
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}

// MARK: - Models

struct BinancePriceResponse: Codable {
    let symbol: String
    let price: String
}

enum MarketPriceError: LocalizedError {
    case invalidSymbol
    case invalidURL
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidSymbol:
            return "Symbole invalide"
        case .invalidURL:
            return "URL invalide"
        case .networkError(let message):
            return "Erreur réseau: \(message)"
        }
    }
}


