//
//  AlertStore.swift
//  Journal de trading 2025
//

import Foundation
import Combine

protocol AlertStore {
    var alertsPublisher: AnyPublisher<[Alert], Never> { get }
    var unreadCountPublisher: AnyPublisher<Int, Never> { get }
    
    func create(_ alert: Alert) async throws -> Alert
    func fetchAll() async throws -> [Alert]
    func fetch(by id: UUID) async throws -> Alert?
    func update(_ alert: Alert) async throws -> Alert
    func delete(_ alert: Alert) async throws
    func markAsRead(_ alert: Alert) async throws
    func fetchUnread() async throws -> [Alert]
    func fetchBySymbol(_ symbol: String) async throws -> [Alert]
    func fetchBySeverity(_ severity: AlertSeverity) async throws -> [Alert]
    func fetchByDateRange(_ startDate: Date, _ endDate: Date) async throws -> [Alert]
}
