//
//  LocalTradeStore.swift
//  Journal de trading 2025
//
//  Store local pour persister les trades dans SQLite

import Foundation
import Combine

class LocalTradeStore: TradeStore {
    private let database = LocalDatabase.shared
    private let tradesSubject = CurrentValueSubject<[Trade], Never>([])
    private let tradeSubject = CurrentValueSubject<Trade?, Never>(nil)
    private let backupFileURL: URL
    
    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        backupFileURL = documentsPath.appendingPathComponent("trades_backup.json")
        print("✅ [LocalTradeStore] Initialisé (chargement différé)")
        print("📂 [LocalTradeStore] Fichier de sauvegarde: \(backupFileURL.path)")
    }
    
    var tradesPublisher: AnyPublisher<[Trade], Never> {
        tradesSubject.eraseToAnyPublisher()
    }
    
    var tradePublisher: AnyPublisher<Trade?, Never> {
        tradeSubject.eraseToAnyPublisher()
    }
    
    // Sauvegarde de secours avec FileManager
    private func saveToFileManagerBackup(_ trade: Trade) {
        do {
            // Charger les trades existants depuis le fichier de secours
            var existingTrades: [Trade] = []
            if FileManager.default.fileExists(atPath: backupFileURL.path) {
                let data = try Data(contentsOf: backupFileURL)
                existingTrades = try JSONDecoder().decode([Trade].self, from: data)
            }
            
            // Ajouter le nouveau trade (éviter les doublons)
            if !existingTrades.contains(where: { $0.id == trade.id }) {
                existingTrades.append(trade)
                
                // Sauvegarder
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(existingTrades)
                try data.write(to: backupFileURL, options: .atomic)
                print("✅ [LocalTradeStore] Sauvegarde de secours effectuée: \(existingTrades.count) trades dans le fichier")
            }
        } catch {
            print("⚠️ [LocalTradeStore] Erreur lors de la sauvegarde de secours: \(error)")
        }
    }
    
    private func loadFromFileManagerBackup() -> [Trade] {
        guard FileManager.default.fileExists(atPath: backupFileURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: backupFileURL)
            let trades = try JSONDecoder().decode([Trade].self, from: data)
            print("✅ [LocalTradeStore] \(trades.count) trades chargés depuis la sauvegarde de secours")
            return trades
        } catch {
            print("❌ [LocalTradeStore] Erreur lors du chargement de la sauvegarde de secours: \(error)")
            return []
        }
    }
    
    private func loadTrades() {
        Task {
            do {
                let trades = try await fetchAll()
                await MainActor.run {
                    tradesSubject.send(trades)
                }
                print("✅ [LocalTradeStore] Chargé \(trades.count) trades depuis SQLite")
            } catch {
                print("❌ [LocalTradeStore] Erreur lors du chargement des trades: \(error)")
            }
        }
    }
    
    private func updatePublishers() {
        // Recharger les trades depuis la base de données
        Task {
            do {
                let allTrades = try await fetchAll()
                await MainActor.run {
                    tradesSubject.send(allTrades)
                    print("🔄 [LocalTradeStore] Publishers mis à jour avec \(allTrades.count) trades")
                }
            } catch {
                print("❌ [LocalTradeStore] Erreur lors de la mise à jour des publishers: \(error)")
            }
        }
    }
    
    // MARK: - CRUD Operations
    
    func create(_ trade: Trade) async throws -> Trade {
        let sql = """
        INSERT INTO trades (id, date, symbol, type, entryPrice, exitPrice, quantity, leverage, exchangeId, orderRole, systemId, session, flashPnLNet, status, currentPrice, lastPriceUpdate, closedAt, notes, tags)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let tagsJSON = try JSONSerialization.data(withJSONObject: trade.tags)
        let tagsString = String(data: tagsJSON, encoding: .utf8) ?? "[]"
        
        // Construire les paramètres avec gestion des valeurs optionnelles
        let parameters: [Any] = [
            trade.id.uuidString,
            trade.date.timeIntervalSince1970,
            trade.symbol,
            trade.type.rawValue,
            trade.entryPrice ?? NSNull(),
            trade.exitPrice ?? NSNull(),
            trade.quantity ?? NSNull(),
            trade.leverage,
            trade.exchangeId.uuidString,
            trade.orderRole.rawValue,
            trade.systemId.uuidString,
            trade.session.rawValue,
            trade.flashPnLNet ?? NSNull(),
            trade.status.rawValue,
            trade.currentPrice ?? NSNull(),
            trade.lastPriceUpdate?.timeIntervalSince1970 ?? NSNull(),
            trade.closedAt?.timeIntervalSince1970 ?? NSNull(),
            trade.notes ?? NSNull(),
            tagsString
        ]
        
        print("💾 [LocalTradeStore] Tentative de sauvegarde du trade: \(trade.symbol) (id: \(trade.id.uuidString))")
        print("💾 [LocalTradeStore] Détails du trade: entryPrice=\(trade.entryPrice?.description ?? "nil"), exitPrice=\(trade.exitPrice?.description ?? "nil"), quantity=\(trade.quantity?.description ?? "nil")")
        
        // Sauvegarde de secours avec FileManager en parallèle (TOUJOURS effectuée)
        saveToFileManagerBackup(trade)
        
        print("🔍 [LocalTradeStore] Exécution de la requête SQL avec \(parameters.count) paramètres")
        let success = database.executeUpdate(sql, parameters: parameters)
        
        if success {
            print("✅ [LocalTradeStore] Trade sauvegardé avec succès dans SQLite: \(trade.symbol)")
            
            // Vérification immédiate : récupérer le trade depuis la base pour confirmer
            let verification = database.executeQuery("SELECT id FROM trades WHERE id = ?", parameters: [trade.id.uuidString])
            if verification.isEmpty {
                print("⚠️ [LocalTradeStore] ATTENTION: Trade sauvegardé mais non trouvé lors de la vérification!")
            } else {
                print("✅ [LocalTradeStore] Vérification OK: Trade trouvé dans la base après sauvegarde")
            }
            
            // Mettre à jour les publishers immédiatement
            await MainActor.run {
                updatePublishers()
            }
            print("💾 [LocalTradeStore] Trade sauvegardé: \(trade.symbol) (status: \(trade.status.rawValue))")
            return trade
        } else {
            print("❌ [LocalTradeStore] Échec de la sauvegarde du trade: \(trade.symbol)")
            print("❌ [LocalTradeStore] Vérification de la base de données...")
            // Vérifier si la base de données est accessible
            let testQuery = database.executeQuery("SELECT COUNT(*) as count FROM trades", parameters: [])
            print("🔍 [LocalTradeStore] Test query: \(testQuery.count) résultats")
            
            // Vérifier si la table existe
            let tableCheck = database.executeQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='trades'", parameters: [])
            print("🔍 [LocalTradeStore] Table 'trades' existe: \(!tableCheck.isEmpty)")
            
            throw TradeStoreError.saveFailed
        }
    }
    
    func fetchAll() async throws -> [Trade] {
        print("🔍 [LocalTradeStore] fetchAll() - Début de la récupération des trades")
        let sql = "SELECT * FROM trades ORDER BY date DESC"
        let rows = database.executeQuery(sql)
        
        print("🔍 [LocalTradeStore] fetchAll() - \(rows.count) lignes récupérées de SQLite")
        
        var trades = rows.compactMap { row in
            self.tradeFromRow(row)
        }
        
        print("✅ [LocalTradeStore] fetchAll() - \(trades.count) trades parsés depuis SQLite")
        
        // Si SQLite ne retourne aucun trade, essayer la sauvegarde de secours
        if trades.isEmpty {
            print("⚠️ [LocalTradeStore] Aucun trade dans SQLite, tentative de chargement depuis la sauvegarde de secours...")
            let backupTrades = loadFromFileManagerBackup()
            if !backupTrades.isEmpty {
                print("✅ [LocalTradeStore] \(backupTrades.count) trades récupérés depuis la sauvegarde de secours")
                // Essayer de les sauvegarder dans SQLite
                for trade in backupTrades {
                    do {
                        _ = try await create(trade)
                    } catch {
                        print("⚠️ [LocalTradeStore] Impossible de restaurer le trade \(trade.symbol) dans SQLite: \(error)")
                    }
                }
                trades = backupTrades
            }
        }
        
        return trades
    }
    
    func fetch(by id: UUID) async throws -> Trade? {
        let sql = "SELECT * FROM trades WHERE id = ?"
        let rows = database.executeQuery(sql, parameters: [id.uuidString])
        
        return rows.first.flatMap { self.tradeFromRow($0) }
    }
    
    func update(_ trade: Trade) async throws -> Trade {
        let sql = """
        UPDATE trades SET
            date = ?, symbol = ?, type = ?, entryPrice = ?, exitPrice = ?, quantity = ?,
            leverage = ?, exchangeId = ?, orderRole = ?, systemId = ?, session = ?,
            flashPnLNet = ?, status = ?, currentPrice = ?, lastPriceUpdate = ?,
            closedAt = ?, notes = ?, tags = ?
        WHERE id = ?
        """
        
        let tagsJSON = try JSONSerialization.data(withJSONObject: trade.tags)
        let tagsString = String(data: tagsJSON, encoding: .utf8) ?? "[]"
        
        // Construire les paramètres avec gestion des valeurs optionnelles
        let parameters: [Any] = [
            trade.date.timeIntervalSince1970,
            trade.symbol,
            trade.type.rawValue,
            trade.entryPrice ?? NSNull(),
            trade.exitPrice ?? NSNull(),
            trade.quantity ?? NSNull(),
            trade.leverage,
            trade.exchangeId.uuidString,
            trade.orderRole.rawValue,
            trade.systemId.uuidString,
            trade.session.rawValue,
            trade.flashPnLNet ?? NSNull(),
            trade.status.rawValue,
            trade.currentPrice ?? NSNull(),
            trade.lastPriceUpdate?.timeIntervalSince1970 ?? NSNull(),
            trade.closedAt?.timeIntervalSince1970 ?? NSNull(),
            trade.notes ?? NSNull(),
            tagsString,
            trade.id.uuidString
        ]
        
        if database.executeUpdate(sql, parameters: parameters) {
            await MainActor.run {
                updatePublishers()
            }
            print("💾 [LocalTradeStore] Trade mis à jour: \(trade.symbol) (status: \(trade.status.rawValue))")
            return trade
        } else {
            throw TradeStoreError.saveFailed
        }
    }
    
    func delete(_ trade: Trade) async throws {
        let sql = "DELETE FROM trades WHERE id = ?"
        
        if database.executeUpdate(sql, parameters: [trade.id.uuidString]) {
            await MainActor.run {
                updatePublishers()
            }
            print("🗑️ [LocalTradeStore] Trade supprimé: \(trade.symbol)")
        } else {
            throw TradeStoreError.deleteFailed
        }
    }
    
    func fetchByDateRange(_ startDate: Date, _ endDate: Date) async throws -> [Trade] {
        let sql = "SELECT * FROM trades WHERE date >= ? AND date <= ? ORDER BY date DESC"
        let parameters = [startDate.timeIntervalSince1970, endDate.timeIntervalSince1970]
        let rows = database.executeQuery(sql, parameters: parameters)
        
        return rows.compactMap { row in
            self.tradeFromRow(row)
        }
    }
    
    func fetchBySystem(_ systemId: UUID) async throws -> [Trade] {
        let sql = "SELECT * FROM trades WHERE systemId = ? ORDER BY date DESC"
        let rows = database.executeQuery(sql, parameters: [systemId.uuidString])
        
        return rows.compactMap { row in
            self.tradeFromRow(row)
        }
    }
    
    func fetchByExchange(_ exchangeId: UUID) async throws -> [Trade] {
        let sql = "SELECT * FROM trades WHERE exchangeId = ? ORDER BY date DESC"
        let rows = database.executeQuery(sql, parameters: [exchangeId.uuidString])
        
        return rows.compactMap { row in
            self.tradeFromRow(row)
        }
    }
    
    func fetchTrades(for period: DateInterval) async throws -> [Trade] {
        return try await fetchByDateRange(period.start, period.end)
    }
    
    // MARK: - Helper Methods
    
    private func tradeFromRow(_ row: [String: Any]) -> Trade? {
        guard let idString = row["id"] as? String,
              let id = UUID(uuidString: idString),
              let dateTimestamp = row["date"] as? Double,
              let symbol = row["symbol"] as? String,
              let typeString = row["type"] as? String,
              let type = TradeType(rawValue: typeString),
              let leverageValue = row["leverage"] as? Double,
              let exchangeIdString = row["exchangeId"] as? String,
              let exchangeId = UUID(uuidString: exchangeIdString),
              let orderRoleString = row["orderRole"] as? String,
              let orderRole = OrderRole(rawValue: orderRoleString),
              let systemIdString = row["systemId"] as? String,
              let systemId = UUID(uuidString: systemIdString),
              let sessionString = row["session"] as? String,
              let session = Session(rawValue: sessionString) else {
            print("❌ [LocalTradeStore] Erreur de parsing d'un trade depuis la base de données")
            print("❌ [LocalTradeStore] Row: \(row)")
            print("❌ [LocalTradeStore] Colonnes disponibles: \(row.keys.sorted().joined(separator: ", "))")
            return nil
        }
        
        let date = Date(timeIntervalSince1970: dateTimestamp)
        let entryPrice = row["entryPrice"] as? Double
        let exitPrice = row["exitPrice"] as? Double
        let quantity = row["quantity"] as? Double
        let leverage = leverageValue
        let flashPnLNet = row["flashPnLNet"] as? Double
        
        // Nouveaux champs (avec valeurs par défaut pour compatibilité)
        let statusString = row["status"] as? String ?? "closed"
        let status = TradeStatus(rawValue: statusString) ?? .closed
        let currentPrice = row["currentPrice"] as? Double
        let lastPriceUpdateTimestamp = row["lastPriceUpdate"] as? Double
        let lastPriceUpdate = lastPriceUpdateTimestamp.map { Date(timeIntervalSince1970: $0) }
        let closedAtTimestamp = row["closedAt"] as? Double
        let closedAt = closedAtTimestamp.map { Date(timeIntervalSince1970: $0) }
        let notes = row["notes"] as? String
        
        // Tags (JSON array)
        let tagsString = row["tags"] as? String ?? "[]"
        let tags: [String]
        if let tagsData = tagsString.data(using: .utf8),
           let tagsArray = try? JSONSerialization.jsonObject(with: tagsData) as? [String] {
            tags = tagsArray
        } else {
            tags = []
        }
        
        return Trade(
            id: id,
            date: date,
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

// MARK: - Trade Store Error

enum TradeStoreError: LocalizedError {
    case saveFailed
    case deleteFailed
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Erreur lors de la sauvegarde du trade"
        case .deleteFailed:
            return "Erreur lors de la suppression du trade"
        case .fetchFailed:
            return "Erreur lors de la récupération des trades"
        }
    }
}

