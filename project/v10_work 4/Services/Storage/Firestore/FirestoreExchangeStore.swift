//
//  FirestoreExchangeStore.swift
//  Journal de trading 2025
//

import Foundation
import Combine

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
import FirebaseFirestore
import FirebaseAuth

final class FirestoreExchangeStore: ExchangeStore {
    private let db = Firestore.firestore()
    private let exchangesSubject = PassthroughSubject<[Exchange], Never>()
    
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUserId: String?
    
    var exchangesPublisher: AnyPublisher<[Exchange], Never> { exchangesSubject.eraseToAnyPublisher() }
    
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
            exchangesSubject.send([])
            return
        }
        
        listener = db.collection("users")
            .document(userId)
            .collection("exchanges")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard let snapshot else {
                    print("❌ [FirestoreExchangeStore] Error fetching exchanges: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let exchanges = snapshot.documents.compactMap { self.decodeExchange(from: $0.data(), id: $0.documentID) }
                self.exchangesSubject.send(exchanges)
            }
    }
    
    func create(_ exchange: Exchange) async throws -> Exchange {
        let userId = try requireUserId()
        let docRef = db.collection("users").document(userId).collection("exchanges").document(exchange.id.uuidString)
        try await docRef.setData(encodeExchange(exchange))
        return exchange
    }
    
    func fetchAll() async throws -> [Exchange] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users").document(userId).collection("exchanges").getDocuments()
        return snapshot.documents.compactMap { decodeExchange(from: $0.data(), id: $0.documentID) }
    }
    
    func fetch(by id: UUID) async throws -> Exchange? {
        let userId = try requireUserId()
        let doc = try await db.collection("users").document(userId).collection("exchanges").document(id.uuidString).getDocument()
        guard let data = doc.data() else { return nil }
        return decodeExchange(from: data, id: doc.documentID)
    }
    
    func update(_ exchange: Exchange) async throws -> Exchange {
        let userId = try requireUserId()
        let docRef = db.collection("users").document(userId).collection("exchanges").document(exchange.id.uuidString)
        try await docRef.setData(encodeExchange(exchange), merge: true)
        return exchange
    }
    
    func delete(_ exchange: Exchange) async throws {
        let userId = try requireUserId()
        try await db.collection("users").document(userId).collection("exchanges").document(exchange.id.uuidString).delete()
    }
    
    private func requireUserId() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw FirestoreExchangeStoreError.notAuthenticated }
        return uid
    }
    
    private func encodeExchange(_ exchange: Exchange) -> [String: Any] {
        [
            "id": exchange.id.uuidString,
            "name": exchange.name,
            "makerFeeRate": exchange.makerFeeRate,
            "takerFeeRate": exchange.takerFeeRate,
            "isDefault": exchange.isDefault
        ]
    }
    
    private func decodeExchange(from data: [String: Any], id: String) -> Exchange? {
        guard
            let uuid = UUID(uuidString: id),
            let name = data["name"] as? String,
            let makerFeeRate = data["makerFeeRate"] as? Double,
            let takerFeeRate = data["takerFeeRate"] as? Double,
            let isDefault = data["isDefault"] as? Bool
        else {
            print("❌ [FirestoreExchangeStore] Failed to decode exchange \(id)")
            return nil
        }
        
        return Exchange(id: uuid, name: name, makerFeeRate: makerFeeRate, takerFeeRate: takerFeeRate, isDefault: isDefault)
    }
}

enum FirestoreExchangeStoreError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Utilisateur non authentifié"
        }
    }
}
#endif



