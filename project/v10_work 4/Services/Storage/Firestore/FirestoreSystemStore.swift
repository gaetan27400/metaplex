//
//  FirestoreSystemStore.swift
//  Journal de trading 2025
//

import Foundation
import Combine

#if canImport(FirebaseFirestore) && canImport(FirebaseAuth)
import FirebaseFirestore
import FirebaseAuth

final class FirestoreSystemStore: SystemStore {
    private let db = Firestore.firestore()
    private let systemsSubject = PassthroughSubject<[TradingSystem], Never>()
    
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentUserId: String?
    
    var systemsPublisher: AnyPublisher<[TradingSystem], Never> { systemsSubject.eraseToAnyPublisher() }
    
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
            systemsSubject.send([])
            return
        }
        
        listener = db.collection("users")
            .document(userId)
            .collection("systems")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }
                guard let snapshot else {
                    print("❌ [FirestoreSystemStore] Error fetching systems: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                let systems = snapshot.documents.compactMap { self.decodeSystem(from: $0.data(), id: $0.documentID) }
                self.systemsSubject.send(systems)
            }
    }
    
    func create(_ system: TradingSystem) async throws -> TradingSystem {
        let userId = try requireUserId()
        let docRef = db.collection("users").document(userId).collection("systems").document(system.id.uuidString)
        try await docRef.setData(encodeSystem(system))
        return system
    }
    
    func fetchAll() async throws -> [TradingSystem] {
        let userId = try requireUserId()
        let snapshot = try await db.collection("users").document(userId).collection("systems").getDocuments()
        return snapshot.documents.compactMap { decodeSystem(from: $0.data(), id: $0.documentID) }
    }
    
    func fetch(by id: UUID) async throws -> TradingSystem? {
        let userId = try requireUserId()
        let doc = try await db.collection("users").document(userId).collection("systems").document(id.uuidString).getDocument()
        guard let data = doc.data() else { return nil }
        return decodeSystem(from: data, id: doc.documentID)
    }
    
    func update(_ system: TradingSystem) async throws -> TradingSystem {
        let userId = try requireUserId()
        let docRef = db.collection("users").document(userId).collection("systems").document(system.id.uuidString)
        try await docRef.setData(encodeSystem(system), merge: true)
        return system
    }
    
    func delete(_ system: TradingSystem) async throws {
        let userId = try requireUserId()
        try await db.collection("users").document(userId).collection("systems").document(system.id.uuidString).delete()
    }
    
    func fetchSystems() async throws -> [TradingSystem] {
        try await fetchAll()
    }
    
    private func requireUserId() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw FirestoreSystemStoreError.notAuthenticated }
        return uid
    }
    
    private func encodeSystem(_ system: TradingSystem) -> [String: Any] {
        [
            "id": system.id.uuidString,
            "name": system.name,
            "color": system.color
        ]
    }
    
    private func decodeSystem(from data: [String: Any], id: String) -> TradingSystem? {
        guard
            let uuid = UUID(uuidString: id),
            let name = data["name"] as? String,
            let color = data["color"] as? String
        else {
            print("❌ [FirestoreSystemStore] Failed to decode system \(id)")
            return nil
        }
        
        return TradingSystem(id: uuid, name: name, color: color)
    }
}

enum FirestoreSystemStoreError: LocalizedError {
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Utilisateur non authentifié"
        }
    }
}
#endif



