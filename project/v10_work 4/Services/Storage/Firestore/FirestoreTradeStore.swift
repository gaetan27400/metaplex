//
//  FirestoreTradeStore.swift
//  Journal de trading 2025
//

import Foundation
import Combine

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
import FirebaseFirestore
import FirebaseAuth

final class FirestoreTradeStore: TradeStore {
    private let db = Firestore.firestore()
    private let tradesSubject = PassthroughSubject<[Trade], Never>()
    private let tradeSubject = PassthroughSubject<Trade?, Never>()
    
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUserId: String?
    
    var tradesPublisher: AnyPublisher<[Trade], Never> { tradesSubject.eraseToAnyPublisher() }
    var tradePublisher: AnyPublisher<Trade?, Never> { tradeSubject.eraseToAnyPublisher() }
    
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
        
        // Boot strap with current user if already logged in
        currentUserId = Auth.auth().currentUser?.uid
        restartListener()
    }
    
    private func restartListener() {
        listener?.remove()
        listener = nil
        
        guard let userId = currentUserId else {
            tradesSubject.send([])
            return
        }
        
        listener = db.collection("users")
            .document(userId)
            .collection("trades")
            .order(by: "date", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard let snapshot else {
                    print("❌ [FirestoreTradeStore] Error fetching trades: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let trades = snapshot.documents.compactMap { self.decodeTrade(from: $0.data(), id: $0.documentID) }
                self.tradesSubject.send(trades)
            }
    }
    
    // MARK: - CRUD Operations
    
    func create(_ trade: Trade) async throws -> Trade {
        let userId = try requireUserId()
        let docRef = db.collection("users").document(userId).collection("trades").document(trade.id.uuidString)
        try await docRef.setData(encodeTrade(trade))
        return trade
    }
    
    func fetchAll() async throws -> [Trade] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("trades")
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { decodeTrade(from: $0.data(), id: $0.documentID) }
    }
    
    func fetch(by id: UUID) async throws -> Trade? {
        let userId = try requireUserId()
        let doc = try await db.collection("users").document(userId).collection("trades").document(id.uuidString).getDocument()
        guard let data = doc.data() else { return nil }
        return decodeTrade(from: data, id: doc.documentID)
    }
    
    func update(_ trade: Trade) async throws -> Trade {
        let userId = try requireUserId()
        let docRef = db.collection("users").document(userId).collection("trades").document(trade.id.uuidString)
        try await docRef.setData(encodeTrade(trade), merge: true)
        return trade
    }
    
    func delete(_ trade: Trade) async throws {
        let userId = try requireUserId()
        try await db.collection("users").document(userId).collection("trades").document(trade.id.uuidString).delete()
    }
    
    // MARK: - Query Methods
    
    func fetchByDateRange(_ startDate: Date, _ endDate: Date) async throws -> [Trade] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("trades")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endDate))
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { decodeTrade(from: $0.data(), id: $0.documentID) }
    }
    
    func fetchBySystem(_ systemId: UUID) async throws -> [Trade] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("trades")
            .whereField("systemId", isEqualTo: systemId.uuidString)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { decodeTrade(from: $0.data(), id: $0.documentID) }
    }
    
    func fetchByExchange(_ exchangeId: UUID) async throws -> [Trade] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("trades")
            .whereField("exchangeId", isEqualTo: exchangeId.uuidString)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { decodeTrade(from: $0.data(), id: $0.documentID) }
    }
    
    func fetchTrades(for period: DateInterval) async throws -> [Trade] {
        try await fetchByDateRange(period.start, period.end)
    }
    
    // MARK: - Helpers
    
    private func requireUserId() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw FirestoreTradeStoreError.notAuthenticated
        }
        return uid
    }
    
    private func encodeTrade(_ trade: Trade) -> [String: Any] {
        var data: [String: Any] = [
            "id": trade.id.uuidString,
            "date": Timestamp(date: trade.date),
            "symbol": trade.symbol,
            "type": trade.type.rawValue,
            "leverage": trade.leverage,
            "exchangeId": trade.exchangeId.uuidString,
            "orderRole": trade.orderRole.rawValue,
            "systemId": trade.systemId.uuidString,
            "session": trade.session.rawValue,
            "status": trade.status.rawValue,
            "tags": trade.tags
        ]
        
        if let entryPrice = trade.entryPrice { data["entryPrice"] = entryPrice }
        if let exitPrice = trade.exitPrice { data["exitPrice"] = exitPrice }
        if let quantity = trade.quantity { data["quantity"] = quantity }
        if let flashPnLNet = trade.flashPnLNet { data["flashPnLNet"] = flashPnLNet }
        if let notes = trade.notes { data["notes"] = notes }
        if let currentPrice = trade.currentPrice { data["currentPrice"] = currentPrice }
        if let lastPriceUpdate = trade.lastPriceUpdate { data["lastPriceUpdate"] = Timestamp(date: lastPriceUpdate) }
        if let closedAt = trade.closedAt { data["closedAt"] = Timestamp(date: closedAt) }
        
        return data
    }
    
    private func decodeTrade(from data: [String: Any], id: String) -> Trade? {
        guard
            let uuid = UUID(uuidString: id),
            let dateTs = data["date"] as? Timestamp,
            let symbol = data["symbol"] as? String,
            let typeString = data["type"] as? String,
            let type = TradeType(rawValue: typeString),
            let leverage = data["leverage"] as? Double,
            let exchangeIdString = data["exchangeId"] as? String,
            let exchangeId = UUID(uuidString: exchangeIdString),
            let orderRoleString = data["orderRole"] as? String,
            let orderRole = OrderRole(rawValue: orderRoleString),
            let systemIdString = data["systemId"] as? String,
            let systemId = UUID(uuidString: systemIdString),
            let sessionString = data["session"] as? String,
            let session = Session(rawValue: sessionString)
        else {
            print("❌ [FirestoreTradeStore] Failed to decode trade \(id)")
            return nil
        }
        
        let entryPrice = data["entryPrice"] as? Double
        let exitPrice = data["exitPrice"] as? Double
        let quantity = data["quantity"] as? Double
        let flashPnLNet = data["flashPnLNet"] as? Double
        let notes = data["notes"] as? String
        let tags = data["tags"] as? [String] ?? []
        
        let statusRaw = data["status"] as? String
        let status = TradeStatus(rawValue: statusRaw ?? TradeStatus.closed.rawValue) ?? .closed
        let currentPrice = data["currentPrice"] as? Double
        let lastPriceUpdate = (data["lastPriceUpdate"] as? Timestamp)?.dateValue()
        let closedAt = (data["closedAt"] as? Timestamp)?.dateValue()
        
        return Trade(
            id: uuid,
            date: dateTs.dateValue(),
            symbol: symbol,
            type: type,
            entryPrice: entryPrice,
            exitPrice: exitPrice,
            quantity: quantity,
            leverage: leverage,
            exchangeId: exchangeId,
            orderRole: orderRole,
            systemId: systemId,
            session: session,
            flashPnLNet: flashPnLNet,
            notes: notes,
            tags: tags,
            status: status,
            currentPrice: currentPrice,
            lastPriceUpdate: lastPriceUpdate,
            closedAt: closedAt
        )
    }
}

enum FirestoreTradeStoreError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Utilisateur non authentifié"
        }
    }
}
#endif



