//
//  Exchanges.swift
//  Journal de trading 2025
//

import Foundation
import CryptoKit

// MARK: - Brokers supportés

public enum Broker: String, CaseIterable, Identifiable {
    case mexc
    // ajoute d’autres brokers ici (.binance, .bybit, …)

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .mexc: return "MEXC"
        }
    }
    /// Préfixe clé trousseau (si un jour tu veux isoler par broker)
    public var keychainIdentifier: String { "com.jdt.api.\(rawValue)" }
}

// MARK: - Import infrastructure

public protocol TradeImporter {
    func fetchRecentTrades(apiKey: String, apiSecret: String) async throws -> [TradeDTO]
}

/// Registre : retourne l’importeur pour un broker
public enum ImporterRegistry {
    public static func importer(for broker: Broker) -> TradeImporter {
        switch broker {
        case .mexc:
            // On combine Spot + Futures pour toi
            return CombinedImporter(children: [
                MEXCSpotImporter(),
                MEXCFuturesImporter()
            ])
        }
    }
}

/// Combine plusieurs importeurs en un seul (concatène les résultats)
struct CombinedImporter: TradeImporter {
    let children: [TradeImporter]
    func fetchRecentTrades(apiKey: String, apiSecret: String) async throws -> [TradeDTO] {
        var all: [TradeDTO] = []
        for importer in children {
            do { all += try await importer.fetchRecentTrades(apiKey: apiKey, apiSecret: apiSecret) }
            catch { /* on ignore l’échec d’un des importeurs, mais on pourrait le remonter */ }
        }
        return all
    }
}

// MARK: - DTO générique (souple)

public struct TradeDTO: Codable, Hashable {
    public let raw: [String: String]         // toutes les paires clé/valeur sous forme de String

    public init(raw: [String: String]) { self.raw = raw }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var dict: [String: String] = [:]
        for k in c.allKeys {
            if let v = try? c.decode(String.self, forKey: k) {
                dict[k.stringValue] = v
            } else if let n = try? c.decode(Double.self, forKey: k) {
                dict[k.stringValue] = String(n)
            } else if let n = try? c.decode(Int64.self, forKey: k) {
                dict[k.stringValue] = String(n)
            } else if let n = try? c.decode(Int.self, forKey: k) {
                dict[k.stringValue] = String(n)
            } else if let b = try? c.decode(Bool.self, forKey: k) {
                dict[k.stringValue] = b ? "true" : "false"
            }
        }
        self.raw = dict
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicCodingKeys.self)
        for (k, v) in raw {
            if let key = DynamicCodingKeys(stringValue: k) {
                try c.encode(v, forKey: key)
            }
        }
    }
}

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
}

// Helpers d’accès rapides (optionnels)
public extension TradeDTO {
    var id: String { raw["id"] ?? raw["tradeId"] ?? raw["orderId"] ?? UUID().uuidString }
    var symbol: String { raw["symbol"] ?? raw["instId"] ?? raw["market"] ?? "" }
    var side: String { raw["side"] ?? raw["S"] ?? raw["type"] ?? "" }
    var price: Double { Double(raw["price"] ?? raw["px"] ?? raw["dealPrice"] ?? "") ?? 0 }
    var qty: Double { Double(raw["qty"] ?? raw["quantity"] ?? raw["vol"] ?? raw["size"] ?? "") ?? 0 }
    var fee: Double { Double(raw["fee"] ?? raw["commission"] ?? "") ?? 0 }
    var pnl: Double { Double(raw["pnl"] ?? raw["profit"] ?? raw["profitRealized"] ?? "") ?? 0 }
    var tsMs: Int64 { Int64(raw["time"] ?? raw["ts"] ?? raw["createTime"] ?? raw["timestamp"] ?? "") ?? 0 }
}

// MARK: - MEXC Spot importer

/// Doc (à titre indicatif) : GET /api/v3/myTrades
/// Base URL : https://api.mexc.com
/// Signature: HMAC SHA256(hex) du query string, header: X-MEXC-APIKEY
struct MEXCSpotImporter: TradeImporter {
    func fetchRecentTrades(apiKey: String, apiSecret: String) async throws -> [TradeDTO] {
        // Ex: on récupère les 500 dernières lignes d’un symbole. Pour du multi-symbole il faudrait boucler.
        // Tu peux aussi utiliser le paramètre startTime / endTime.
        // Pour un premier test on interroge BTCUSDT ; à adapter selon tes marchés.
        let symbol = "BTCUSDT"

        let base = "https://api.mexc.com"
        let path = "/api/v3/myTrades"
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let recvWindow = "5000"

        var query = "symbol=\(symbol)&limit=500&recvWindow=\(recvWindow)&timestamp=\(timestamp)"
        let signature = HMACSigner.sha256Hex(message: query, secret: apiSecret)
        query += "&signature=\(signature)"

        guard let url = URL(string: base + path + "?" + query) else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "X-MEXC-APIKEY")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { return [] }
        guard (200..<300).contains(http.statusCode) else {
            // Remonte l’erreur lisible pour ton UI
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImportError.http(code: http.statusCode, body: body)
        }

        // Réponse typique: tableau d’objets (on les re-stringifie via TradeDTO)
        let arr = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] ?? []
        return arr.map { dict in
            var out: [String: String] = [:]
            dict.forEach { key, value in out[key] = String(describing: value) }
            return TradeDTO(raw: out)
        }
    }
}

// MARK: - MEXC Futures importer (USDT-M) – minimal

/// Les endpoints Futures diffèrent (base URL/paramètres). Voici un squelette
/// qui interroge une liste de fills/positions selon l’API publique MEXC Futures.
/// Ajuste `base`, `path` et les paramètres selon ton compte.
/// Si l’endpoint ne correspond pas, la requête retournera 4xx et l’erreur sera affichée.
struct MEXCFuturesImporter: TradeImporter {
    func fetchRecentTrades(apiKey: String, apiSecret: String) async throws -> [TradeDTO] {
        let base = "https://contract.mexc.com"          // base futures USDT-M
        let path = "/api/v1/private/fills"              // à ajuster si besoin
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let recvWindow = "5000"

        var query = "timestamp=\(timestamp)&recvWindow=\(recvWindow)&page_size=200"
        let signature = HMACSigner.sha256Hex(message: query, secret: apiSecret)
        query += "&signature=\(signature)"

        guard let url = URL(string: base + path + "?" + query) else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(apiKey, forHTTPHeaderField: "X-MEXC-APIKEY")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { return [] }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ImportError.http(code: http.statusCode, body: body)
        }

        // Selon l’API futures, la charge utile est souvent { "data": [...] }
        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        let arr = (json?["data"] as? [[String: Any]]) ?? (json?["rows"] as? [[String: Any]]) ?? []
        return arr.map { dict in
            var out: [String: String] = [:]
            dict.forEach { key, value in out[key] = String(describing: value) }
            return TradeDTO(raw: out)
        }
    }
}

// MARK: - HMAC signer + erreurs

enum ImportError: LocalizedError {
    case http(code: Int, body: String)
    var errorDescription: String? {
        switch self {
        case .http(let c, let b): return "HTTP \(c): \(b)"
        }
    }
}

enum HMACSigner {
    static func sha256Hex(message: String, secret: String) -> String {
        let key = SymmetricKey(data: Data(secret.utf8))
        let sig = HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key)
        return sig.map { String(format: "%02x", $0) }.joined()
    }
}
