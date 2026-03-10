//
//  SystemStore.swift
//  Journal de trading 2025
//

import Foundation
import Combine

protocol SystemStore {
    var systemsPublisher: AnyPublisher<[TradingSystem], Never> { get }
    
    func create(_ system: TradingSystem) async throws -> TradingSystem
    func fetchAll() async throws -> [TradingSystem]
    func fetch(by id: UUID) async throws -> TradingSystem?
    func update(_ system: TradingSystem) async throws -> TradingSystem
    func delete(_ system: TradingSystem) async throws
    func fetchSystems() async throws -> [TradingSystem]
}



