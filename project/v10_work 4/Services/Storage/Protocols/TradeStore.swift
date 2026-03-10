//
//  TradeStore.swift
//  Journal de trading 2025
//

import Foundation
import Combine

protocol TradeStore {
    var tradesPublisher: AnyPublisher<[Trade], Never> { get }
    var tradePublisher: AnyPublisher<Trade?, Never> { get }
    
    func create(_ trade: Trade) async throws -> Trade
    func fetchAll() async throws -> [Trade]
    func fetch(by id: UUID) async throws -> Trade?
    func update(_ trade: Trade) async throws -> Trade
    func delete(_ trade: Trade) async throws
    func fetchByDateRange(_ startDate: Date, _ endDate: Date) async throws -> [Trade]
    func fetchBySystem(_ systemId: UUID) async throws -> [Trade]
    func fetchByExchange(_ exchangeId: UUID) async throws -> [Trade]
    func fetchTrades(for period: DateInterval) async throws -> [Trade]
}



