//
//  FirestoreAlertStore_Stub.swift
//  Journal de trading 2025
//
//  Version stub de FirestoreAlertStore utilisée quand Firebase n'est pas installé
//

import Foundation
import Combine

/// Stub implementation of FirestoreAlertStore for when Firebase is not available
/// This class will be replaced by the real FirestoreAlertStore once Firebase is configured
class FirestoreAlertStoreStub: AlertStore {
    private let alertsSubject = PassthroughSubject<[Alert], Never>()
    private let unreadCountSubject = PassthroughSubject<Int, Never>()
    private var alerts: [Alert] = []
    
    var alertsPublisher: AnyPublisher<[Alert], Never> {
        alertsSubject.eraseToAnyPublisher()
    }
    
    var unreadCountPublisher: AnyPublisher<Int, Never> {
        unreadCountSubject.eraseToAnyPublisher()
    }
    
    // MARK: - CRUD Operations
    
    func create(_ alert: Alert) async throws -> Alert {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        alerts.append(alert)
        alertsSubject.send(alerts)
        return alert
    }
    
    func fetchAll() async throws -> [Alert] {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        return alerts
    }
    
    func fetch(by id: UUID) async throws -> Alert? {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        return alerts.first { $0.id == id }
    }
    
    func update(_ alert: Alert) async throws -> Alert {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index] = alert
            alertsSubject.send(alerts)
        }
        return alert
    }
    
    func delete(_ alert: Alert) async throws {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        alerts.removeAll { $0.id == alert.id }
        alertsSubject.send(alerts)
    }
    
    func markAsRead(_ alert: Alert) async throws {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        var updatedAlert = alert
        updatedAlert = Alert(
            id: alert.id,
            createdAt: alert.createdAt,
            symbol: alert.symbol,
            exchange: alert.exchange,
            price: alert.price,
            message: alert.message,
            severity: alert.severity,
            tags: alert.tags,
            payloadJSON: alert.payloadJSON,
            isRead: true,
            source: alert.source,
            linkedTradeId: alert.linkedTradeId
        )
        _ = try await update(updatedAlert)
    }
    
    // MARK: - Query Methods
    
    func fetchUnread() async throws -> [Alert] {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        return alerts.filter { !$0.isRead }
    }
    
    func fetchBySymbol(_ symbol: String) async throws -> [Alert] {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        return alerts.filter { $0.symbol == symbol }
    }
    
    func fetchBySeverity(_ severity: AlertSeverity) async throws -> [Alert] {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        return alerts.filter { $0.severity == severity }
    }
    
    func fetchByDateRange(_ startDate: Date, _ endDate: Date) async throws -> [Alert] {
        print("⚠️ [FirestoreAlertStoreStub] Firebase not configured. Using stub implementation.")
        return alerts.filter { alert in
            alert.createdAt >= startDate && alert.createdAt <= endDate
        }
    }
}
