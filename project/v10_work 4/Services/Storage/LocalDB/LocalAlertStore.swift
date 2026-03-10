//
//  LocalAlertStore.swift
//  Journal de trading 2025
//

import Foundation
import Combine

// MARK: - Alert Store Error

enum AlertStoreError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Utilisateur non authentifié"
        case .invalidData:
            return "Données invalides"
        case .networkError(let message):
            return "Erreur réseau: \(message)"
        }
    }
}

class LocalAlertStore: AlertStore {
    private let database = LocalDatabase.shared
    private let alertsSubject = CurrentValueSubject<[Alert], Never>([])
    private let unreadCountSubject = CurrentValueSubject<Int, Never>(0)
    
    var alertsPublisher: AnyPublisher<[Alert], Never> {
        alertsSubject.eraseToAnyPublisher()
    }
    
    var unreadCountPublisher: AnyPublisher<Int, Never> {
        unreadCountSubject.eraseToAnyPublisher()
    }
    
    init() {
        loadAlerts()
    }
    
    private func loadAlerts() {
        Task {
            do {
                let alerts = try await fetchAll()
                alertsSubject.send(alerts)
                unreadCountSubject.send(alerts.filter { !$0.isRead }.count)
            } catch {
                print("❌ [LocalAlertStore] Error loading alerts: \(error)")
            }
        }
    }
    
    private func updatePublishers() {
        loadAlerts()
    }
    
    // MARK: - CRUD Operations
    
    func create(_ alert: Alert) async throws -> Alert {
        let sql = """
        INSERT INTO alerts (id, createdAt, symbol, exchange, price, message, severity, tags, payloadJSON, isRead, source, linkedTradeId)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let tagsJSON = try JSONSerialization.data(withJSONObject: alert.tags)
        let tagsString = String(data: tagsJSON, encoding: .utf8) ?? "[]"
        let priceString = alert.price?.description ?? ""
        let linkedTradeIdString = alert.linkedTradeId?.uuidString ?? ""
        
        let parameters: [Any] = [
            alert.id.uuidString,
            alert.createdAt.timeIntervalSince1970,
            alert.symbol,
            alert.exchange ?? "",
            priceString,
            alert.message,
            alert.severity.rawValue,
            tagsString,
            alert.payloadJSON,
            alert.isRead ? 1 : 0,
            alert.source.rawValue,
            linkedTradeIdString
        ]
        
        if database.executeUpdate(sql, parameters: parameters) {
            await MainActor.run {
                updatePublishers()
            }
            return alert
        } else {
            throw AlertStoreError.invalidData
        }
    }
    
    func fetchAll() async throws -> [Alert] {
        let sql = "SELECT * FROM alerts ORDER BY createdAt DESC"
        let rows = database.executeQuery(sql)
        
        return rows.compactMap { row in
            self.alertFromRow(row)
        }
    }
    
    func fetch(by id: UUID) async throws -> Alert? {
        let sql = "SELECT * FROM alerts WHERE id = ?"
        let rows = database.executeQuery(sql, parameters: [id.uuidString])
        
        return rows.first.flatMap { self.alertFromRow($0) }
    }
    
    func update(_ alert: Alert) async throws -> Alert {
        let sql = """
        UPDATE alerts SET
            createdAt = ?, symbol = ?, exchange = ?, price = ?, message = ?, severity = ?,
            tags = ?, payloadJSON = ?, isRead = ?, source = ?, linkedTradeId = ?
        WHERE id = ?
        """
        
        let tagsJSON = try JSONSerialization.data(withJSONObject: alert.tags)
        let tagsString = String(data: tagsJSON, encoding: .utf8) ?? "[]"
        let priceString = alert.price?.description ?? ""
        let linkedTradeIdString = alert.linkedTradeId?.uuidString ?? ""
        
        let parameters: [Any] = [
            alert.createdAt.timeIntervalSince1970,
            alert.symbol,
            alert.exchange ?? "",
            priceString,
            alert.message,
            alert.severity.rawValue,
            tagsString,
            alert.payloadJSON,
            alert.isRead ? 1 : 0,
            alert.source.rawValue,
            linkedTradeIdString,
            alert.id.uuidString
        ]
        
        if database.executeUpdate(sql, parameters: parameters) {
            await MainActor.run {
                updatePublishers()
            }
            return alert
        } else {
            throw AlertStoreError.invalidData
        }
    }
    
    func delete(_ alert: Alert) async throws {
        let sql = "DELETE FROM alerts WHERE id = ?"
        
        if database.executeUpdate(sql, parameters: [alert.id.uuidString]) {
            await MainActor.run {
                updatePublishers()
            }
        } else {
            throw AlertStoreError.invalidData
        }
    }
    
    func markAsRead(_ alert: Alert) async throws {
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
        let sql = "SELECT * FROM alerts WHERE isRead = 0 ORDER BY createdAt DESC"
        let rows = database.executeQuery(sql)
        
        return rows.compactMap { row in
            self.alertFromRow(row)
        }
    }
    
    func fetchBySymbol(_ symbol: String) async throws -> [Alert] {
        let sql = "SELECT * FROM alerts WHERE symbol = ? ORDER BY createdAt DESC"
        let rows = database.executeQuery(sql, parameters: [symbol])
        
        return rows.compactMap { row in
            self.alertFromRow(row)
        }
    }
    
    func fetchBySeverity(_ severity: AlertSeverity) async throws -> [Alert] {
        let sql = "SELECT * FROM alerts WHERE severity = ? ORDER BY createdAt DESC"
        let rows = database.executeQuery(sql, parameters: [severity.rawValue])
        
        return rows.compactMap { row in
            self.alertFromRow(row)
        }
    }
    
    func fetchByDateRange(_ startDate: Date, _ endDate: Date) async throws -> [Alert] {
        let sql = "SELECT * FROM alerts WHERE createdAt >= ? AND createdAt <= ? ORDER BY createdAt DESC"
        let parameters = [startDate.timeIntervalSince1970, endDate.timeIntervalSince1970]
        let rows = database.executeQuery(sql, parameters: parameters)
        
        return rows.compactMap { row in
            self.alertFromRow(row)
        }
    }
    
    // MARK: - Helper Methods
    
    private func alertFromRow(_ row: [String: Any]) -> Alert? {
        guard let idString = row["id"] as? String,
              let id = UUID(uuidString: idString),
              let createdAtTimestamp = row["createdAt"] as? Double,
              let symbol = row["symbol"] as? String,
              let message = row["message"] as? String,
              let severityString = row["severity"] as? String,
              let severity = AlertSeverity(rawValue: severityString),
              let tagsString = row["tags"] as? String,
              let payloadJSON = row["payloadJSON"] as? String,
              let isReadInt = row["isRead"] as? Int,
              let sourceString = row["source"] as? String,
              let source = AlertSource(rawValue: sourceString) else {
            return nil
        }
        
        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        let exchange = row["exchange"] as? String
        let priceString = row["price"] as? String ?? ""
        let price = priceString.isEmpty ? nil : Double(priceString)
        let isRead = isReadInt == 1
        let linkedTradeIdString = row["linkedTradeId"] as? String ?? ""
        let linkedTradeId = linkedTradeIdString.isEmpty ? nil : UUID(uuidString: linkedTradeIdString)
        
        let tags: [String]
        if let tagsData = tagsString.data(using: .utf8),
           let tagsArray = try? JSONSerialization.jsonObject(with: tagsData) as? [String] {
            tags = tagsArray
        } else {
            tags = []
        }
        
        return Alert(
            id: id,
            createdAt: createdAt,
            symbol: symbol,
            exchange: exchange?.isEmpty == false ? exchange : nil,
            price: price,
            message: message,
            severity: severity,
            tags: tags,
            payloadJSON: payloadJSON,
            isRead: isRead,
            source: source,
            linkedTradeId: linkedTradeId
        )
    }
}
