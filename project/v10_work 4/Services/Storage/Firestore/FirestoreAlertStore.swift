//
//  FirestoreAlertStore.swift
//  Journal de trading 2025
//

import Foundation
import Combine

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
import FirebaseFirestore
import FirebaseAuth

final class FirestoreAlertStore: AlertStore {
    private let db = Firestore.firestore()
    private let alertsSubject = PassthroughSubject<[Alert], Never>()
    private let unreadCountSubject = PassthroughSubject<Int, Never>()
    
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUserId: String?
    
    var alertsPublisher: AnyPublisher<[Alert], Never> { alertsSubject.eraseToAnyPublisher() }
    var unreadCountPublisher: AnyPublisher<Int, Never> { unreadCountSubject.eraseToAnyPublisher() }
    
    init() {
        startAuthListener()
    }
    
    deinit {
        listener?.remove()
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }
    
    private func startAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            let newUid = user?.uid
            if newUid != self.currentUserId {
                self.currentUserId = newUid
                self.restartListener()
            }
        }
        
        currentUserId = Auth.auth().currentUser?.uid
        restartListener()
    }
    
    private func restartListener() {
        listener?.remove()
        listener = nil
        
        guard let userId = currentUserId else {
            alertsSubject.send([])
            unreadCountSubject.send(0)
            return
        }
        
        listener = db.collection("users")
            .document(userId)
            .collection("alerts")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard let snapshot else {
                    print("❌ [FirestoreAlertStore] Error fetching alerts: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let alerts = snapshot.documents.compactMap { self.decodeAlert(from: $0.data(), id: $0.documentID) }
                self.alertsSubject.send(alerts)
                self.unreadCountSubject.send(alerts.filter { !$0.isRead }.count)
            }
    }
    
    func create(_ alert: Alert) async throws -> Alert {
        let userId = try requireUserId()
        let docRef = db.collection("users").document(userId).collection("alerts").document(alert.id.uuidString)
        try await docRef.setData(encodeAlert(alert))
        return alert
    }
    
    func fetchAll() async throws -> [Alert] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users").document(userId).collection("alerts").order(by: "createdAt", descending: true).getDocuments()
        return snapshot.documents.compactMap { decodeAlert(from: $0.data(), id: $0.documentID) }
    }
    
    func fetch(by id: UUID) async throws -> Alert? {
        let userId = try requireUserId()
        let doc = try await db.collection("users").document(userId).collection("alerts").document(id.uuidString).getDocument()
        guard let data = doc.data() else { return nil }
        return decodeAlert(from: data, id: doc.documentID)
    }
    
    func update(_ alert: Alert) async throws -> Alert {
        let userId = try requireUserId()
        let docRef = db.collection("users").document(userId).collection("alerts").document(alert.id.uuidString)
        try await docRef.setData(encodeAlert(alert), merge: true)
        return alert
    }
    
    func delete(_ alert: Alert) async throws {
        let userId = try requireUserId()
        try await db.collection("users").document(userId).collection("alerts").document(alert.id.uuidString).delete()
    }
    
    func markAsRead(_ alert: Alert) async throws {
        var updated = alert
        updated.isRead = true
        _ = try await update(updated)
    }
    
    func fetchUnread() async throws -> [Alert] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("alerts")
            .whereField("isRead", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { decodeAlert(from: $0.data(), id: $0.documentID) }
    }
    
    func fetchBySymbol(_ symbol: String) async throws -> [Alert] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("alerts")
            .whereField("symbol", isEqualTo: symbol)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { decodeAlert(from: $0.data(), id: $0.documentID) }
    }
    
    func fetchBySeverity(_ severity: AlertSeverity) async throws -> [Alert] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("alerts")
            .whereField("severity", isEqualTo: severity.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { decodeAlert(from: $0.data(), id: $0.documentID) }
    }
    
    func fetchByDateRange(_ startDate: Date, _ endDate: Date) async throws -> [Alert] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("alerts")
            .whereField("createdAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("createdAt", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { decodeAlert(from: $0.data(), id: $0.documentID) }
    }
    
    private func requireUserId() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw FirestoreAlertStoreError.notAuthenticated }
        return uid
    }
    
    private func encodeAlert(_ alert: Alert) -> [String: Any] {
        var data: [String: Any] = [
            "id": alert.id.uuidString,
            "createdAt": Timestamp(date: alert.createdAt),
            "symbol": alert.symbol,
            "message": alert.message,
            "severity": alert.severity.rawValue,
            "tags": alert.tags,
            "payloadJSON": alert.payloadJSON,
            "isRead": alert.isRead,
            "source": alert.source.rawValue
        ]
        if let exchange = alert.exchange { data["exchange"] = exchange }
        if let price = alert.price { data["price"] = price }
        if let linked = alert.linkedTradeId { data["linkedTradeId"] = linked.uuidString }
        return data
    }
    
    private func decodeAlert(from data: [String: Any], id: String) -> Alert? {
        guard
            let uuid = UUID(uuidString: id),
            let createdAtTs = data["createdAt"] as? Timestamp,
            let symbol = data["symbol"] as? String,
            let message = data["message"] as? String,
            let severityRaw = data["severity"] as? String,
            let severity = AlertSeverity(rawValue: severityRaw),
            let payloadJSON = data["payloadJSON"] as? String,
            let isRead = data["isRead"] as? Bool,
            let sourceRaw = data["source"] as? String,
            let source = AlertSource(rawValue: sourceRaw)
        else {
            print("❌ [FirestoreAlertStore] Failed to decode alert \(id)")
            return nil
        }
        
        let tags = data["tags"] as? [String] ?? []
        let exchange = data["exchange"] as? String
        let price = data["price"] as? Double
        let linkedTradeId = (data["linkedTradeId"] as? String).flatMap(UUID.init(uuidString:))
        
        return Alert(
            id: uuid,
            createdAt: createdAtTs.dateValue(),
            symbol: symbol,
            exchange: exchange,
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

enum FirestoreAlertStoreError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Utilisateur non authentifié"
        }
    }
}
#endif

