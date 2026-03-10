//
//  MockStores.swift
//  Journal de trading 2025
//

import Foundation
import Combine

// MARK: - Mock Trade Store

class MockTradeStore: TradeStore {
    private var trades: [Trade] = []
    private let tradesSubject = CurrentValueSubject<[Trade], Never>([])
    private let tradeSubject = CurrentValueSubject<Trade?, Never>(nil)
    
    /// Initialise le store avec option de seed automatique
    /// - Parameter autoSeed: Si true, génère automatiquement 150 trades de démo (par défaut: false pour éviter les race conditions)
    init(autoSeed: Bool = false) {
        if autoSeed {
            // Seed 150 demo trades on first use (déprécié - peut causer des race conditions)
            // Utiliser seedDemoTrades() explicitement après l'initialisation si nécessaire
            Task { await seedDemoTrades(count: 150) }
        }
    }
    
    var tradesPublisher: AnyPublisher<[Trade], Never> {
        tradesSubject.eraseToAnyPublisher()
    }
    
    var tradePublisher: AnyPublisher<Trade?, Never> {
        tradeSubject.eraseToAnyPublisher()
    }
    
    func create(_ trade: Trade) async throws -> Trade {
        print("💾 [MockTradeStore] Création d'un trade: \(trade.symbol) avec status: \(trade.status.rawValue)")
        trades.append(trade)
        tradesSubject.send(trades)
        return trade
    }
    
    func fetchAll() async throws -> [Trade] {
        return trades
    }
    
    func fetch(by id: UUID) async throws -> Trade? {
        return trades.first { $0.id == id }
    }
    
    func update(_ trade: Trade) async throws -> Trade {
        if let index = trades.firstIndex(where: { $0.id == trade.id }) {
            let oldStatus = trades[index].status
            trades[index] = trade
            print("💾 [MockTradeStore] Mise à jour d'un trade: \(trade.symbol) - status: \(oldStatus.rawValue) → \(trade.status.rawValue)")
            tradesSubject.send(trades)
        }
        return trade
    }
    
    func delete(_ trade: Trade) async throws {
        trades.removeAll { $0.id == trade.id }
        tradesSubject.send(trades)
    }
    
    func fetchByDateRange(_ startDate: Date, _ endDate: Date) async throws -> [Trade] {
        return trades.filter { trade in
            trade.date >= startDate && trade.date <= endDate
        }
    }
    
    func fetchBySystem(_ systemId: UUID) async throws -> [Trade] {
        return trades.filter { $0.systemId == systemId }
    }
    
    func fetchByExchange(_ exchangeId: UUID) async throws -> [Trade] {
        return trades.filter { $0.exchangeId == exchangeId }
    }
    
    func fetchTrades(for period: DateInterval) async throws -> [Trade] {
        return trades.filter { trade in
            trade.date >= period.start && trade.date <= period.end
        }
    }
    
    // Helper to generate demo trades
    @discardableResult
    func seedDemoTrades(count: Int) async -> Int {
        guard trades.isEmpty else { return trades.count }
        let symbols = ["BTC","ETH","SOL","AVAX","MATIC","LINK","UNI","AAVE"]
        let calendar = Calendar.current
        let today = Date()
        let defaultExchange = Exchange(name: "DemoEx", makerFeeRate: 0.001, takerFeeRate: 0.0015)
        let systems = [TradingSystem(name: "Breakout"), TradingSystem(name: "MeanRevert"), TradingSystem(name: "Momentum")]
        for _ in 0..<count {
            let daysAgo = Int.random(in: 0...120)
            guard let tradeDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            let symbol = symbols.randomElement()!
            let type: TradeType = Bool.random() ? .long : .short
            let session = Session.allCases.randomElement()!
            let orderRole: OrderRole = Bool.random() ? .maker : .taker
            if Bool.random() {
                // detailed
                let entry = Double.random(in: 100...60000)
                let change = Double.random(in: -0.05...0.06)
                let exit = max(1.0, entry * (1.0 + change))
                let qty = Double.random(in: 0.01...2.5)
                let trade = Trade(
                    date: tradeDate,
                    symbol: symbol,
                    type: type,
                    entryPrice: entry,
                    exitPrice: exit,
                    quantity: qty,
                    leverage: 1.0,
                    exchangeId: defaultExchange.id,
                    orderRole: orderRole,
                    systemId: systems.randomElement()!.id,
                    session: session,
                    flashPnLNet: nil
                )
                trades.append(trade)
            } else {
                // flash
                let pnl = Bool.random() ? Double.random(in: 20...500) : -Double.random(in: 10...400)
                let trade = Trade(
                    date: tradeDate,
                    symbol: symbol,
                    type: type,
                    leverage: 1.0,
                    exchangeId: defaultExchange.id,
                    orderRole: orderRole,
                    systemId: systems.randomElement()!.id,
                    session: session,
                    flashPnLNet: pnl
                )
                trades.append(trade)
            }
        }
        tradesSubject.send(trades)
        return trades.count
    }
}

// MARK: - Mock Exchange Store

class MockExchangeStore: ExchangeStore {
    private var exchanges: [Exchange] = []
    private let exchangesSubject = CurrentValueSubject<[Exchange], Never>([])
    
    var exchangesPublisher: AnyPublisher<[Exchange], Never> {
        exchangesSubject.eraseToAnyPublisher()
    }
    
    func create(_ exchange: Exchange) async throws -> Exchange {
        exchanges.append(exchange)
        exchangesSubject.send(exchanges)
        return exchange
    }
    
    func fetchAll() async throws -> [Exchange] {
        return exchanges
    }
    
    func fetch(by id: UUID) async throws -> Exchange? {
        return exchanges.first { $0.id == id }
    }
    
    func update(_ exchange: Exchange) async throws -> Exchange {
        if let index = exchanges.firstIndex(where: { $0.id == exchange.id }) {
            exchanges[index] = exchange
            exchangesSubject.send(exchanges)
        }
        return exchange
    }
    
    func delete(_ exchange: Exchange) async throws {
        exchanges.removeAll { $0.id == exchange.id }
        exchangesSubject.send(exchanges)
    }
}

// MARK: - Mock System Store

class MockSystemStore: SystemStore {
    private var systems: [TradingSystem] = []
    private let systemsSubject = CurrentValueSubject<[TradingSystem], Never>([])
    
    var systemsPublisher: AnyPublisher<[TradingSystem], Never> {
        systemsSubject.eraseToAnyPublisher()
    }
    
    func create(_ system: TradingSystem) async throws -> TradingSystem {
        systems.append(system)
        systemsSubject.send(systems)
        return system
    }
    
    func fetchAll() async throws -> [TradingSystem] {
        return systems
    }
    
    func fetch(by id: UUID) async throws -> TradingSystem? {
        return systems.first { $0.id == id }
    }
    
    func update(_ system: TradingSystem) async throws -> TradingSystem {
        if let index = systems.firstIndex(where: { $0.id == system.id }) {
            systems[index] = system
            systemsSubject.send(systems)
        }
        return system
    }
    
    func delete(_ system: TradingSystem) async throws {
        systems.removeAll { $0.id == system.id }
        systemsSubject.send(systems)
    }
    
    func fetchSystems() async throws -> [TradingSystem] {
        return systems
    }
}

// MARK: - Mock API Store

class MockAPIStore: APIStore {
    private var credentials: [APICredentials] = []
    
    func saveAPICredentials(_ credentials: APICredentials) async throws {
        if let index = self.credentials.firstIndex(where: { $0.exchange == credentials.exchange }) {
            self.credentials[index] = credentials
        } else {
            self.credentials.append(credentials)
        }
    }
    
    func fetchAPICredentials(for exchange: String) async throws -> APICredentials? {
        return credentials.first { $0.exchange == exchange }
    }
    
    func deleteAPICredentials(for exchange: String) async throws {
        credentials.removeAll { $0.exchange == exchange }
    }
    
    func fetchAllAPICredentials() async throws -> [APICredentials] {
        return credentials
    }
}





