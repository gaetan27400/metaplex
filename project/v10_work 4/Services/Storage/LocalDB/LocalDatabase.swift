//
//  LocalDatabase.swift
//  Journal de trading 2025
//

import Foundation
import SQLite3
import Combine

class LocalDatabase {
    static let shared = LocalDatabase()
    
    private var db: OpaquePointer?
    private let dbPath: String
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        dbPath = documentsPath.appendingPathComponent("trading_journal.db").path
        
        openDatabase()
        createTables()
    }
    
    deinit {
        closeDatabase()
    }
    
    private func openDatabase() {
        print("🔍 [LocalDatabase] Tentative d'ouverture de la base de données...")
        print("🔍 [LocalDatabase] Chemin: \(dbPath)")
        let result = sqlite3_open(dbPath, &db)
        if result != SQLITE_OK {
            let errorMessage = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
            print("❌ [LocalDatabase] Unable to open database: \(errorMessage) (code: \(result))")
            print("❌ [LocalDatabase] Database path: \(dbPath)")
            // Fermer la connexion si elle a été partiellement ouverte
            if db != nil {
                sqlite3_close(db)
                db = nil
            }
        } else {
            print("✅ [LocalDatabase] Database opened successfully at: \(dbPath)")
            print("✅ [LocalDatabase] Database pointer: \(db != nil ? "non-nil" : "nil")")
        }
    }
    
    private func closeDatabase() {
        if sqlite3_close(db) != SQLITE_OK {
            print("❌ [LocalDatabase] Error closing database")
        }
    }
    
    private func createTables() {
        print("🔍 [LocalDatabase] Création des tables...")
        guard db != nil else {
            print("❌ [LocalDatabase] Database is nil, cannot create tables")
            return
        }
        createAlertsTable()
        createTradesTable()
        createExchangesTable()
        createSystemsTable()
        createAPICredentialsTable()
        createPrestigeTables()
        print("✅ [LocalDatabase] Toutes les tables créées/vérifiées")
    }
    
    private func createAlertsTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS alerts (
            id TEXT PRIMARY KEY,
            createdAt REAL NOT NULL,
            symbol TEXT NOT NULL,
            exchange TEXT,
            price TEXT,
            message TEXT NOT NULL,
            severity TEXT NOT NULL,
            tags TEXT NOT NULL,
            payloadJSON TEXT NOT NULL,
            isRead INTEGER NOT NULL,
            source TEXT NOT NULL,
            linkedTradeId TEXT
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ [LocalDatabase] Error creating alerts table")
        }
    }
    
    private func createTradesTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS trades (
            id TEXT PRIMARY KEY,
            date REAL NOT NULL,
            symbol TEXT NOT NULL,
            type TEXT NOT NULL,
            entryPrice REAL,
            exitPrice REAL,
            quantity REAL,
            leverage REAL NOT NULL,
            exchangeId TEXT NOT NULL,
            orderRole TEXT NOT NULL,
            systemId TEXT NOT NULL,
            session TEXT NOT NULL,
            flashPnLNet REAL,
            status TEXT NOT NULL DEFAULT 'closed',
            currentPrice REAL,
            lastPriceUpdate REAL,
            closedAt REAL,
            notes TEXT,
            tags TEXT NOT NULL DEFAULT '[]'
        );
        """
        
        guard db != nil else {
            print("❌ [LocalDatabase] Database is nil, cannot create trades table")
            return
        }
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ [LocalDatabase] Error creating trades table: \(errorMessage)")
        } else {
            // Migration: ajouter les nouvelles colonnes si elles n'existent pas déjà
            migrateTradesTable()
        }
    }
    
    private func migrateTradesTable() {
        guard db != nil else {
            print("❌ [LocalDatabase] Database is nil, cannot migrate trades table")
            return
        }
        
        // Vérifier si les colonnes existent déjà
        let checkColumnsSQL = "PRAGMA table_info(trades)"
        let columns = executeQuery(checkColumnsSQL)
        let columnNames = Set(columns.compactMap { $0["name"] as? String })
        
        var migrations: [String] = []
        
        if !columnNames.contains("status") {
            migrations.append("ALTER TABLE trades ADD COLUMN status TEXT NOT NULL DEFAULT 'closed'")
        }
        if !columnNames.contains("currentPrice") {
            migrations.append("ALTER TABLE trades ADD COLUMN currentPrice REAL")
        }
        if !columnNames.contains("lastPriceUpdate") {
            migrations.append("ALTER TABLE trades ADD COLUMN lastPriceUpdate REAL")
        }
        if !columnNames.contains("closedAt") {
            migrations.append("ALTER TABLE trades ADD COLUMN closedAt REAL")
        }
        if !columnNames.contains("notes") {
            migrations.append("ALTER TABLE trades ADD COLUMN notes TEXT")
        }
        if !columnNames.contains("tags") {
            migrations.append("ALTER TABLE trades ADD COLUMN tags TEXT NOT NULL DEFAULT '[]'")
        }
        
        for migrationSQL in migrations {
            if sqlite3_exec(db, migrationSQL, nil, nil, nil) != SQLITE_OK {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                print("⚠️ [LocalDatabase] Migration warning: \(migrationSQL) - \(errorMessage)")
            } else {
                print("✅ [LocalDatabase] Migration applied: \(migrationSQL)")
            }
        }
    }
    
    private func createExchangesTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS exchanges (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            makerFeeRate REAL NOT NULL,
            takerFeeRate REAL NOT NULL,
            isDefault INTEGER NOT NULL
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ [LocalDatabase] Error creating exchanges table")
        }
    }
    
    private func createSystemsTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS systems (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color TEXT NOT NULL
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ [LocalDatabase] Error creating systems table")
        }
    }
    
    private func createAPICredentialsTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS api_credentials (
            id TEXT PRIMARY KEY,
            exchange TEXT NOT NULL,
            apiKey TEXT NOT NULL,
            apiSecret TEXT NOT NULL,
            isActive INTEGER NOT NULL,
            createdAt REAL NOT NULL,
            lastUsed REAL
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ [LocalDatabase] Error creating api_credentials table")
        }
    }
    
    private func createPrestigeTables() {
        createProgressionsTable()
        createBadgesTable()
        createXPEventsTable()
        createChallengesTable()
        createChallengeRerollsTable()
    }
    
    private func createProgressionsTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS progressions (
            id INTEGER PRIMARY KEY,
            level INTEGER NOT NULL DEFAULT 1,
            xpInLevel INTEGER NOT NULL DEFAULT 0,
            prestige INTEGER NOT NULL DEFAULT 0,
            dailyXP INTEGER NOT NULL DEFAULT 0,
            totalXP INTEGER NOT NULL DEFAULT 0,
            xpRequiredForNextLevel INTEGER NOT NULL DEFAULT 100,
            lastXPReset REAL NOT NULL,
            lastPrestigeDate REAL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ [LocalDatabase] Error creating progressions table")
        }
    }
    
    private func createBadgesTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS badges (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            icon TEXT NOT NULL,
            rarity TEXT NOT NULL,
            unlockedAt REAL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ [LocalDatabase] Error creating badges table")
        }
    }
    
    private func createXPEventsTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS xp_events (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            amount INTEGER NOT NULL,
            description TEXT NOT NULL,
            metadata TEXT NOT NULL,
            createdAt REAL NOT NULL
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ [LocalDatabase] Error creating xp_events table")
        }
    }
    
    private func createChallengesTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS challenges (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            type TEXT NOT NULL,
            targetValue INTEGER NOT NULL,
            currentValue INTEGER NOT NULL DEFAULT 0,
            rewardXP INTEGER NOT NULL,
            isCompleted INTEGER NOT NULL DEFAULT 0,
            completedAt REAL,
            expiresAt REAL NOT NULL,
            mutators TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ [LocalDatabase] Error creating challenges table")
        }
    }
    
    private func createChallengeRerollsTable() {
        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS challenge_rerolls (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            challengeId TEXT NOT NULL,
            rerollDate REAL NOT NULL,
            FOREIGN KEY (challengeId) REFERENCES challenges (id)
        );
        """
        
        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            print("❌ [LocalDatabase] Error creating challenge_rerolls table")
        }
    }
    
    // MARK: - Generic Database Operations
    
    func executeQuery(_ sql: String, parameters: [Any] = []) -> [[String: Any]] {
        guard db != nil else {
            print("❌ [LocalDatabase] Database is nil, cannot execute query")
            return []
        }
        
        var statement: OpaquePointer?
        var results: [[String: Any]] = []
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ [LocalDatabase] Erreur de préparation SQL (query): \(errorMessage)")
            print("❌ [LocalDatabase] SQL: \(sql)")
            sqlite3_finalize(statement)
            return results
        }
        
        // Bind parameters
        for (index, parameter) in parameters.enumerated() {
            let paramIndex = Int32(index + 1)
            if let stringParam = parameter as? String {
                sqlite3_bind_text(statement, paramIndex, stringParam, -1, nil)
            } else if let intParam = parameter as? Int {
                sqlite3_bind_int(statement, paramIndex, Int32(intParam))
            } else if let doubleParam = parameter as? Double {
                sqlite3_bind_double(statement, paramIndex, doubleParam)
            } else if parameter is NSNull {
                sqlite3_bind_null(statement, paramIndex)
            }
        }
        
        // Execute query and collect results
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: Any] = [:]
            let columnCount = sqlite3_column_count(statement)
            
            for i in 0..<columnCount {
                let columnName = String(cString: sqlite3_column_name(statement, i))
                let columnType = sqlite3_column_type(statement, i)
                
                switch columnType {
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(statement, i) {
                        row[columnName] = String(cString: text)
                    } else {
                        row[columnName] = NSNull()
                    }
                case SQLITE_INTEGER:
                    row[columnName] = sqlite3_column_int(statement, i)
                case SQLITE_FLOAT:
                    row[columnName] = sqlite3_column_double(statement, i)
                case SQLITE_NULL:
                    row[columnName] = NSNull()
                default:
                    row[columnName] = NSNull()
                }
            }
            results.append(row)
        }
        
        sqlite3_finalize(statement)
        return results
    }
    
    func executeUpdate(_ sql: String, parameters: [Any] = []) -> Bool {
        if db == nil {
            print("❌ [LocalDatabase] Database is nil, cannot execute update")
            print("❌ [LocalDatabase] Tentative de réouverture de la base de données...")
            openDatabase()
            if db == nil {
                print("❌ [LocalDatabase] Impossible de rouvrir la base de données")
                return false
            }
        }
        
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ [LocalDatabase] Erreur de préparation SQL (update): \(errorMessage)")
            print("❌ [LocalDatabase] SQL: \(sql)")
            print("❌ [LocalDatabase] Paramètres: \(parameters.count) paramètres")
            for (index, param) in parameters.enumerated() {
                if param is NSNull {
                    print("  [\(index + 1)] = NULL")
                } else if let str = param as? String {
                    print("  [\(index + 1)] = String(\(str.prefix(50)))")
                } else if let dbl = param as? Double {
                    print("  [\(index + 1)] = Double(\(dbl))")
                } else {
                    print("  [\(index + 1)] = \(type(of: param))")
                }
            }
            sqlite3_finalize(statement)
            return false
        }
        
        // Bind parameters
        for (index, parameter) in parameters.enumerated() {
            let paramIndex = Int32(index + 1)
            
            // Utiliser un type spécial pour représenter NULL
            if parameter is NSNull {
                sqlite3_bind_null(statement, paramIndex)
            } else if let stringParam = parameter as? String {
                sqlite3_bind_text(statement, paramIndex, stringParam, -1, nil)
            } else if let intParam = parameter as? Int {
                sqlite3_bind_int(statement, paramIndex, Int32(intParam))
            } else if let doubleParam = parameter as? Double {
                sqlite3_bind_double(statement, paramIndex, doubleParam)
            } else {
                // Pour les valeurs optionnelles nil, utiliser NSNull
                sqlite3_bind_null(statement, paramIndex)
            }
        }
        
        let result = sqlite3_step(statement)
        
        if result != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ [LocalDatabase] Erreur d'exécution SQL: \(errorMessage) (code: \(result))")
            print("❌ [LocalDatabase] SQL: \(sql)")
            print("❌ [LocalDatabase] Codes SQLite: SQLITE_DONE=\(SQLITE_DONE), result=\(result)")
            sqlite3_finalize(statement)
            return false
        }
        
        let finalizeResult = sqlite3_finalize(statement)
        if finalizeResult != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("⚠️ [LocalDatabase] Avertissement lors de la finalisation: \(errorMessage) (code: \(finalizeResult))")
        } else {
            print("✅ [LocalDatabase] Requête SQL exécutée avec succès")
        }
        
        return true
    }
    
    // MARK: - Async Database Operations
    
    func executeQuery(query: String, parameters: [Any] = [], completion: @escaping (Result<OpaquePointer, Error>) -> Void) {
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            completion(.failure(DatabaseError.prepareFailed))
            return
        }
        
        // Bind parameters
        for (index, parameter) in parameters.enumerated() {
            let paramIndex = Int32(index + 1)
            if let stringParam = parameter as? String {
                sqlite3_bind_text(statement, paramIndex, stringParam, -1, nil)
            } else if let intParam = parameter as? Int {
                sqlite3_bind_int(statement, paramIndex, Int32(intParam))
            } else if let doubleParam = parameter as? Double {
                sqlite3_bind_double(statement, paramIndex, doubleParam)
            }
        }
        
        completion(.success(statement!))
    }
}

enum DatabaseError: Error {
    case prepareFailed
    case executionFailed
    case invalidData
}
