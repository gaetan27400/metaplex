//
//  TradingJournalComplete.swift
//  Journal de trading 2025
//
//  Application complète avec toutes les fonctionnalités
//
import Foundation
import Combine
import SwiftUI
import Charts
import CryptoKit
import Security

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
import FirebaseFirestore
import FirebaseAuth
#endif

// MARK: - Core Data Models

enum TradeStatus: String, Codable, Equatable {
    case open = "open"
    case closed = "closed"
}

struct Trade: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let symbol: String
    let type: TradeType
    let entryPrice: Double?
    let exitPrice: Double?
    let quantity: Double?
    let leverage: Double
    var exchangeId: UUID
    let orderRole: OrderRole
    var systemId: UUID
    let session: Session
    let flashPnLNet: Double?
    var notes: String?
    var tags: [String]
    
    // Nouvelles propriétés pour les trades ouverts
    var status: TradeStatus
    var currentPrice: Double?
    var lastPriceUpdate: Date?
    var closedAt: Date?
    
    // Propriétés mutables pour permettre la mise à jour
    mutating func updateCurrentPrice(_ price: Double) {
        self = Trade(
            id: self.id,
            date: self.date,
            symbol: self.symbol,
            type: self.type,
            entryPrice: self.entryPrice,
            exitPrice: self.exitPrice,
            quantity: self.quantity,
            leverage: self.leverage,
            exchangeId: self.exchangeId,
            orderRole: self.orderRole,
            systemId: self.systemId,
            session: self.session,
            flashPnLNet: self.flashPnLNet,
            notes: self.notes,
            tags: self.tags,
            status: self.status,
            currentPrice: price,
            lastPriceUpdate: Date(),
            closedAt: self.closedAt
        )
    }

    /// Retourne une copie du trade avec `currentPrice`/`lastPriceUpdate` mis à jour (sans changer le statut).
    /// (Utilisé par certains appels legacy; ne dépend pas de la feature "Trades en cours".)
    func withUpdatedPrice(_ price: Double) -> Trade {
        var copy = self
        copy.updateCurrentPrice(price)
        return copy
    }
    
    // Computed properties for compatibility
    var entryDate: Date { date }
    var isOpen: Bool { status == .open }
    var isClosed: Bool { status == .closed }
    
    // MARK: - PnL Computed Properties (BRUT - SANS FRAIS)
    // ⚠️ ATTENTION: Ces propriétés calculent le PnL BRUT sans tenir compte des frais (maker/taker fees).
    // Pour les calculs de statistiques et métriques, utilisez TOUJOURS `appState.netPnL(for: trade)`
    // qui prend en compte les frais via PnLCalculator.netPnL.
    
    /// P&L réalisé (pour trades fermés) - BRUT SANS FRAIS
    /// ⚠️ Ne pas utiliser pour les statistiques. Utiliser `appState.netPnL(for: trade)` à la place.
    nonisolated var realizedPnL: Double? {
        guard status == .closed else { return nil }
        if let flashPnL = flashPnLNet {
            return flashPnL
        } else if let entry = entryPrice, let exit = exitPrice, let qty = quantity {
            if type == .long {
                return (exit - entry) * qty * leverage
            } else {
                return (entry - exit) * qty * leverage
            }
        }
        return nil
    }
    
    /// P&L non réalisé (pour trades ouverts) - BRUT SANS FRAIS
    /// ⚠️ Ne pas utiliser pour les statistiques. Utiliser `appState.netPnL(for: trade)` à la place.
    nonisolated var unrealizedPnL: Double? {
        guard status == .open,
              let entry = entryPrice,
              let current = currentPrice,
              let qty = quantity else { return nil }
        
        if type == .long {
            return (current - entry) * qty * leverage
        } else {
            return (entry - current) * qty * leverage
        }
    }
    
    /// P&L total (réalisé ou non réalisé selon le statut) - BRUT SANS FRAIS
    /// ⚠️ ATTENTION: Cette propriété ne prend PAS en compte les frais (maker/taker fees).
    /// Pour les calculs de statistiques, utilisez TOUJOURS `appState.netPnL(for: trade)`.
    /// Cette propriété est conservée pour compatibilité mais ne doit pas être utilisée pour les métriques.
    nonisolated var pnl: Double { 
        if let realized = realizedPnL {
            return realized
        } else if let unrealized = unrealizedPnL {
            return unrealized
        } else if let flashPnL = flashPnLNet {
            return flashPnL
        }
        return 0.0
    }
    
    init(id: UUID = UUID(),
         date: Date,
         symbol: String,
         type: TradeType,
         entryPrice: Double? = nil,
         exitPrice: Double? = nil,
         quantity: Double? = nil,
         leverage: Double = 1.0,
         exchangeId: UUID,
         orderRole: OrderRole,
         systemId: UUID,
         session: Session,
         flashPnLNet: Double? = nil,
         notes: String? = nil,
         tags: [String] = [],
         status: TradeStatus = .closed,
         currentPrice: Double? = nil,
         lastPriceUpdate: Date? = nil,
         closedAt: Date? = nil) {
        self.id = id
        self.date = date
        self.symbol = symbol
        self.type = type
        self.entryPrice = entryPrice
        self.exitPrice = exitPrice
        self.quantity = quantity
        self.leverage = leverage
        self.exchangeId = exchangeId
        self.orderRole = orderRole
        self.systemId = systemId
        self.session = session
        self.flashPnLNet = flashPnLNet
        self.notes = notes
        self.tags = tags
        self.status = status
        self.currentPrice = currentPrice
        self.lastPriceUpdate = lastPriceUpdate
        self.closedAt = closedAt
    }
}

struct Exchange: Identifiable, Codable {
    let id: UUID
    var name: String
    var makerFeeRate: Double
    var takerFeeRate: Double
    var isDefault: Bool
    
    init(id: UUID = UUID(),
         name: String,
         makerFeeRate: Double,
         takerFeeRate: Double,
         isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.makerFeeRate = makerFeeRate
        self.takerFeeRate = takerFeeRate
        self.isDefault = isDefault
    }
}

struct TradingSystem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var color: String
    
    init(id: UUID = UUID(), name: String, color: String = "#00D9FF") {
        self.id = id
        self.name = name
        self.color = color
    }
}

enum TradeType: String, CaseIterable, Identifiable, Codable {
    case long = "Long"
    case short = "Short"
    var id: String { rawValue }
}

enum OrderRole: String, CaseIterable, Identifiable, Codable {
    case maker = "Maker"
    case taker = "Taker"
    var id: String { rawValue }
}

enum Session: String, CaseIterable, Identifiable, Codable {
    case us = "US"
    case asia = "Asia"
    case europe = "Europe"
    var id: String { rawValue }
}
// MARK: - API Models & Integration

struct ExchangeAPI: Identifiable, Codable {
    let id: UUID
    var name: String
    var exchangeType: ExchangeType
    var apiKey: String
    var isActive: Bool
    var lastSyncDate: Date?
    
    enum ExchangeType: String, Codable, CaseIterable {
        case binance = "Binance"
        case bybit = "Bybit"
        case okx = "OKX"
        case kraken = "Kraken"
        case bitget = "Bitget"
        case gateio = "Gate.io"
        case mexc = "MEXC"
        
        var baseURL: String {
            switch self {
            case .binance: return "https://api.binance.com"
            case .bybit: return "https://api.bybit.com"
            case .okx: return "https://www.okx.com"
            case .kraken: return "https://api.kraken.com"
            case .bitget: return "https://api.bitget.com"
            case .gateio: return "https://api.gateio.ws"
            case .mexc: return "https://api.mexc.com"
            }
        }
    }
}

struct ExchangeTrade: Codable {
    let symbol: String
    let side: String
    let price: String
    let quantity: String
    let commission: String
    let commissionAsset: String
    let time: Int64
    let orderId: Int64
}

struct BinanceTradeResponse: Codable {
    let symbol: String
    let orderId: Int64
    let price: String
    let qty: String
    let commission: String
    let commissionAsset: String
    let time: Int64
    let isBuyer: Bool
}

class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    func save(apiKey: String, secret: String, for identifier: String) -> Bool {
        let data = "\(apiKey)|\(secret)".data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
    
    func retrieve(for identifier: String) -> (apiKey: String, secret: String)? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let credentials = String(data: data, encoding: .utf8) else { return nil }
        let components = credentials.split(separator: "|", omittingEmptySubsequences: false)
        guard components.count == 2 else { return nil }
        return (String(components[0]), String(components[1]))
    }
    
    func delete(for identifier: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

protocol ExchangeAPIClient {
    func testConnection() async throws -> Bool
    func fetchTrades(symbol: String?, startTime: Date?, endTime: Date?) async throws -> [ExchangeTrade]
}

class BinanceAPIClient: ExchangeAPIClient {
    private let apiKey: String
    private let secretKey: String
    private let baseURL = "https://api.binance.com"
    
    init(apiKey: String, secretKey: String) {
        self.apiKey = apiKey
        self.secretKey = secretKey
    }
    
    private func createSignature(queryString: String) -> String {
        let key = SymmetricKey(data: Data(secretKey.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(queryString.utf8), using: key)
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }
    
    func testConnection() async throws -> Bool {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let queryString = "timestamp=\(timestamp)"
        let signature = createSignature(queryString: queryString)
        let urlString = "\(baseURL)/api/v3/account?\(queryString)&signature=\(signature)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }
    
    func fetchTrades(symbol: String?, startTime: Date?, endTime: Date?) async throws -> [ExchangeTrade] {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        var queryString = "timestamp=\(timestamp)"
        if let symbol = symbol { queryString += "&symbol=\(symbol)" }
        if let startTime = startTime {
            queryString += "&startTime=\(Int64(startTime.timeIntervalSince1970 * 1000))"
        }
        if let endTime = endTime {
            queryString += "&endTime=\(Int64(endTime.timeIntervalSince1970 * 1000))"
        }
        queryString += "&limit=1000"
        let signature = createSignature(queryString: queryString)
        let urlString = "\(baseURL)/api/v3/myTrades?\(queryString)&signature=\(signature)"
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-MBX-APIKEY")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.apiError(code: 400) }
        let binanceTrades = try JSONDecoder().decode([BinanceTradeResponse].self, from: data)
        return binanceTrades.map { trade in
            ExchangeTrade(symbol: trade.symbol, side: trade.isBuyer ? "BUY" : "SELL",
                         price: trade.price, quantity: trade.qty, commission: trade.commission,
                         commissionAsset: trade.commissionAsset, time: trade.time, orderId: trade.orderId)
        }
    }
}

enum APIError: LocalizedError {
    case invalidURL, invalidResponse, apiError(code: Int), noCredentials, custom(String)
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL invalide"
        case .invalidResponse: return "Réponse invalide"
        case .apiError(let code): return "Erreur API: \(code)"
        case .noCredentials: return "Aucune credential trouvée"
        case .custom(let message): return message
        }
    }
}

class APIManager: ObservableObject {
    @Published var connectedAPIs: [ExchangeAPI] = []
    @Published var isSyncing = false
    @Published var lastError: String?
    @Published var syncProgress: Double = 0
    @Published var importedTrades: [Trade] = []
    private let keychain = KeychainManager.shared
    
    // AppStorage pour les clés API MEXC (compatible avec APIConfigurationView)
    @AppStorage("apiKey") private var mexcApiKey: String = ""
    @AppStorage("apiSecret") private var mexcApiSecret: String = ""
    
    func addAPI(exchangeName: String, exchangeType: ExchangeAPI.ExchangeType, apiKey: String, secret: String) async throws {
        // Cas particulier: MEXC est géré via nos importeurs (Spot/Futures) déjà en place
        if exchangeType == .mexc {
            let api = ExchangeAPI(id: UUID(), name: exchangeName, exchangeType: exchangeType,
                                  apiKey: apiKey, isActive: false, lastSyncDate: nil)
            // Persister les credentials
            guard keychain.save(apiKey: apiKey, secret: secret, for: api.id.uuidString) else {
                throw APIError.noCredentials
            }
            // Alimente aussi l'AppStorage utilisé par l'importeur MEXC
            await MainActor.run {
                self.mexcApiKey = apiKey
                self.mexcApiSecret = secret
            }
            // Test de connectivité: on tente un fetch très léger via l'importeur MEXC
            do {
                let importer = ImporterRegistry.importer(for: .mexc)
                // Un appel suffit; s'il retourne 200 (même 0 trade), on considère la clé valide
                _ = try await importer.fetchRecentTrades(apiKey: apiKey, apiSecret: secret)
                var activatedAPI = api
                activatedAPI.isActive = true
                await MainActor.run { connectedAPIs.append(activatedAPI) }
            } catch {
                _ = keychain.delete(for: api.id.uuidString)
                throw APIError.apiError(code: 401)
            }
            return
        }

        // Par défaut: validation via client dédié (actuellement Binance)
        let api = ExchangeAPI(id: UUID(), name: exchangeName, exchangeType: exchangeType,
                             apiKey: apiKey, isActive: false, lastSyncDate: nil)
        guard keychain.save(apiKey: apiKey, secret: secret, for: api.id.uuidString) else {
            throw APIError.noCredentials
        }
        let client = try createClient(for: api)
        let isValid = try await client.testConnection()
        if isValid {
            var activatedAPI = api
            activatedAPI.isActive = true
            await MainActor.run { connectedAPIs.append(activatedAPI) }
        } else {
            _ = keychain.delete(for: api.id.uuidString)
            throw APIError.apiError(code: 401)
        }
    }
    
    func removeAPI(_ api: ExchangeAPI) {
        _ = keychain.delete(for: api.id.uuidString)
        connectedAPIs.removeAll { $0.id == api.id }
    }
    
    func testAPI(_ api: ExchangeAPI) async throws -> Bool {
        let client = try createClient(for: api)
        return try await client.testConnection()
    }
    
    // MARK: - MEXC Integration
    
    /// Importe les trades depuis MEXC en utilisant les clés API configurées
    func importMEXCTrades() async {
        print("🔍 [DEBUG] Début de l'import MEXC")
        
        guard !mexcApiKey.isEmpty && !mexcApiSecret.isEmpty else {
            print("❌ [DEBUG] Clés API manquantes")
            await MainActor.run { lastError = "Clés API MEXC non configurées" }
            return
        }
        
        print("✅ [DEBUG] Clés API présentes - Key: \(mexcApiKey.prefix(8))..., Secret: \(mexcApiSecret.prefix(8))...")
        
        await MainActor.run { 
            isSyncing = true
            syncProgress = 0
            lastError = nil
        }
        
        do {
            // Utilise l'importeur MEXC existant
            let importer = ImporterRegistry.importer(for: .mexc)
            print("🔧 [DEBUG] Importeur MEXC créé")
            await MainActor.run { syncProgress = 0.3 }
            
            print("🌐 [DEBUG] Appel API MEXC en cours...")
            let tradeDTOs = try await importer.fetchRecentTrades(apiKey: mexcApiKey, apiSecret: mexcApiSecret)
            print("📥 [DEBUG] \(tradeDTOs.count) trades reçus de l'API")
            await MainActor.run { syncProgress = 0.7 }
            
            // Convertit les DTOs en Trades internes
            let convertedTrades = tradeDTOs.compactMap { dto -> Trade? in
                return convertTradeDTOToTrade(dto)
            }
            print("🔄 [DEBUG] \(convertedTrades.count) trades convertis avec succès")
            
            await MainActor.run {
                importedTrades.append(contentsOf: convertedTrades)
                syncProgress = 1.0
                isSyncing = false
            }
            
            print("✅ [DEBUG] Import terminé avec succès - \(convertedTrades.count) trades ajoutés")
            
        } catch {
            print("❌ [DEBUG] Erreur lors de l'import: \(error)")
            await MainActor.run {
                lastError = error.localizedDescription
                isSyncing = false
                syncProgress = 0
            }
        }
    }
    
    /// Convertit un TradeDTO MEXC en Trade interne
    private func convertTradeDTOToTrade(_ dto: TradeDTO) -> Trade? {
        print("🔄 [DEBUG] Conversion DTO: symbol=\(dto.symbol), price=\(dto.price), qty=\(dto.qty), side=\(dto.side)")
        
        guard let symbol = dto.symbol.isEmpty ? nil : dto.symbol,
              let price = dto.price > 0 ? dto.price : nil,
              let quantity = dto.qty > 0 ? dto.qty : nil else {
            print("❌ [DEBUG] Trade ignoré - données manquantes")
            return nil
        }
        
        // Détermine le type de trade basé sur le side
        let tradeType: TradeType = (dto.side.lowercased() == "buy") ? .long : .short
        
        // Crée une date à partir du timestamp
        let date = Date(timeIntervalSince1970: Double(dto.tsMs) / 1000.0)
        
        // Utilise un Exchange par défaut ou crée MEXC s'il n'existe pas
        let exchange = getOrCreateMEXCExchange()
        
        // Utilise un système par défaut
        let system = getDefaultTradingSystem()
        
        return Trade(
            date: date,
            symbol: symbol,
            type: tradeType,
            entryPrice: price,
            quantity: quantity,
            leverage: 1.0, // Spot trading
            exchangeId: exchange.id,
            orderRole: .taker, // Par défaut
            systemId: system.id,
            session: Session.us,
            flashPnLNet: dto.pnl
        )
    }
    
    /// Récupère ou crée l'exchange MEXC
    private func getOrCreateMEXCExchange() -> Exchange {
        // Pour l'instant, on retourne un exchange par défaut
        // Dans une vraie implémentation, on vérifierait en base de données
        return Exchange(
            name: "MEXC",
            makerFeeRate: 0.002,
            takerFeeRate: 0.002,
            isDefault: true
        )
    }
    
    /// Récupère le système de trading par défaut
    private func getDefaultTradingSystem() -> TradingSystem {
        return TradingSystem(name: "MEXC Import", color: "#00D9FF")
    }
    
    // MARK: - Synchronisation périodique
    
    /// Active la synchronisation automatique toutes les X minutes
    func startPeriodicSync(intervalMinutes: Int = 30) {
        Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMinutes * 60), repeats: true) { _ in
            Task {
                await self.importMEXCTrades()
            }
        }
    }
    
    /// Teste la connexion API MEXC avec les clés configurées
    func testMEXCConnection() async -> Bool {
        print("🧪 [DEBUG] Test de connexion MEXC")
        
        guard !mexcApiKey.isEmpty && !mexcApiSecret.isEmpty else {
            print("❌ [DEBUG] Clés API manquantes pour le test")
            return false
        }
        
        do {
            let importer = ImporterRegistry.importer(for: .mexc)
            print("🔧 [DEBUG] Test: Importeur créé")
            
            // Test avec une limite très petite pour éviter de surcharger
            let tradeDTOs = try await importer.fetchRecentTrades(apiKey: mexcApiKey, apiSecret: mexcApiSecret)
            print("✅ [DEBUG] Test: Connexion réussie - \(tradeDTOs.count) trades reçus")
            
            return true
        } catch {
            print("❌ [DEBUG] Test: Échec de connexion - \(error)")
            await MainActor.run {
                lastError = "Test API échoué: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    /// Synchronise les trades récents (dernières 24h)
    func syncRecentTrades() async {
        guard !mexcApiKey.isEmpty && !mexcApiSecret.isEmpty else { return }
        
        do {
            let importer = ImporterRegistry.importer(for: .mexc)
            let tradeDTOs = try await importer.fetchRecentTrades(apiKey: mexcApiKey, apiSecret: mexcApiSecret)
            
            // Filtrer les trades des dernières 24h
            let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
            let recentTrades = tradeDTOs.compactMap { dto -> Trade? in
                let tradeDate = Date(timeIntervalSince1970: Double(dto.tsMs) / 1000.0)
                guard tradeDate > oneDayAgo else { return nil }
                return convertTradeDTOToTrade(dto)
            }
            
            await MainActor.run {
                // Éviter les doublons en vérifiant les IDs
                let existingIds = Set(importedTrades.map { $0.id.uuidString })
                let newTrades = recentTrades.filter { !existingIds.contains($0.id.uuidString) }
                importedTrades.append(contentsOf: newTrades)
            }
            
        } catch {
            await MainActor.run {
                lastError = "Erreur de synchronisation: \(error.localizedDescription)"
            }
        }
    }
    
    func syncTrades(for api: ExchangeAPI, symbol: String? = nil, days: Int = 30) async -> [ExchangeTrade] {
        await MainActor.run { isSyncing = true; syncProgress = 0 }
        defer { Task { await MainActor.run { isSyncing = false; syncProgress = 0 } } }
        do {
            let client = try createClient(for: api)
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
            await MainActor.run { syncProgress = 0.3 }
            let trades = try await client.fetchTrades(symbol: symbol, startTime: startDate, endTime: endDate)
            await MainActor.run { syncProgress = 0.7 }
            if let index = connectedAPIs.firstIndex(where: { $0.id == api.id }) {
                await MainActor.run {
                    connectedAPIs[index].lastSyncDate = Date()
                    syncProgress = 1.0
                }
            }
            return trades
        } catch {
            await MainActor.run { lastError = error.localizedDescription }
            return []
        }
    }
    
    private func createClient(for api: ExchangeAPI) throws -> ExchangeAPIClient {
        guard let credentials = keychain.retrieve(for: api.id.uuidString) else {
            throw APIError.noCredentials
        }
        switch api.exchangeType {
        case .binance: return BinanceAPIClient(apiKey: credentials.apiKey, secretKey: credentials.secret)
        case .bybit: throw APIError.apiError(code: 501)
        case .okx: throw APIError.apiError(code: 501)
        case .kraken: throw APIError.apiError(code: 501)
        case .bitget: throw APIError.apiError(code: 501)
        case .gateio: throw APIError.apiError(code: 501)
        case .mexc: throw APIError.apiError(code: 501)
        }
    }
}

