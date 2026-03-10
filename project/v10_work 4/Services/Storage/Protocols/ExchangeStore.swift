//
//  ExchangeStore.swift
//  Journal de trading 2025
//

import Foundation
import Combine

protocol ExchangeStore {
    var exchangesPublisher: AnyPublisher<[Exchange], Never> { get }
    
    func create(_ exchange: Exchange) async throws -> Exchange
    func fetchAll() async throws -> [Exchange]
    func fetch(by id: UUID) async throws -> Exchange?
    func update(_ exchange: Exchange) async throws -> Exchange
    func delete(_ exchange: Exchange) async throws
}









