import Foundation
import SQLite3

class LocalPrestigeStore: PrestigeStore {
    private let db: LocalDatabase
    
    init(database: LocalDatabase) {
        self.db = database
    }
    
    // MARK: - Progression
    
    func getProgression() async throws -> Progression {
        let query = """
            SELECT level, xpInLevel, prestige, dailyXP, totalXP, xpRequiredForNextLevel, 
                   lastXPReset, lastPrestigeDate, created_at, updated_at
            FROM progressions 
            WHERE id = 1
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query) { result in
                switch result {
                case .success(let statement):
                    if sqlite3_step(statement) == SQLITE_ROW {
                        let progression = self.progressionFromRow(statement: statement)
                        continuation.resume(returning: progression)
                    } else {
                        // Créer une progression par défaut si elle n'existe pas
                        let defaultProgression = Progression(
                            id: 1,
                            level: 1,
                            xpInLevel: 0,
                            prestige: 0,
                            dailyXP: 0,
                            totalXP: 0,
                            xpRequiredForNextLevel: 100,
                            lastXPReset: Date(),
                            lastPrestigeDate: nil,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                        
                        Task {
                            do {
                                _ = try await self.createProgression(defaultProgression)
                                continuation.resume(returning: defaultProgression)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func createProgression(_ progression: Progression) async throws -> Progression {
        let query = """
            INSERT INTO progressions (
                id, level, xpInLevel, prestige, dailyXP, totalXP, xpRequiredForNextLevel,
                lastXPReset, lastPrestigeDate, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let parameters: [Any] = [
            progression.id,
            progression.level,
            progression.xpInLevel,
            progression.prestige,
            progression.dailyXP,
            progression.totalXP,
            progression.xpRequiredForNextLevel,
            progression.lastXPReset.timeIntervalSince1970,
            progression.lastPrestigeDate?.timeIntervalSince1970 as Any,
            progression.createdAt.timeIntervalSince1970,
            progression.updatedAt.timeIntervalSince1970
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume(returning: progression)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateProgression(_ progression: Progression) async throws -> Progression {
        let query = """
            UPDATE progressions SET
                level = ?, xpInLevel = ?, prestige = ?, dailyXP = ?, totalXP = ?,
                xpRequiredForNextLevel = ?, lastXPReset = ?, lastPrestigeDate = ?,
                updated_at = ?
            WHERE id = ?
        """
        
        let parameters: [Any] = [
            progression.level,
            progression.xpInLevel,
            progression.prestige,
            progression.dailyXP,
            progression.totalXP,
            progression.xpRequiredForNextLevel,
            progression.lastXPReset.timeIntervalSince1970,
            progression.lastPrestigeDate?.timeIntervalSince1970 as Any,
            progression.updatedAt.timeIntervalSince1970,
            progression.id
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume(returning: progression)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Badges
    
    func getBadges() async throws -> [Badge] {
        let query = """
            SELECT id, name, description, icon, rarity, unlockedAt, created_at, updated_at
            FROM badges
            ORDER BY unlockedAt DESC, created_at ASC
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            var badges: [Badge] = []
            
            db.executeQuery(query: query) { result in
                switch result {
                case .success(let statement):
                    while sqlite3_step(statement) == SQLITE_ROW {
                        badges.append(self.badgeFromRow(statement: statement))
                    }
                    continuation.resume(returning: badges)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getRecentBadges(limit: Int = 10) async throws -> [Badge] {
        let query = """
            SELECT id, name, description, icon, rarity, unlockedAt, created_at, updated_at
            FROM badges
            WHERE unlockedAt IS NOT NULL
            ORDER BY unlockedAt DESC
            LIMIT ?
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            var badges: [Badge] = []
            
            db.executeQuery(query: query, parameters: [limit]) { result in
                switch result {
                case .success(let statement):
                    while sqlite3_step(statement) == SQLITE_ROW {
                        badges.append(self.badgeFromRow(statement: statement))
                    }
                    continuation.resume(returning: badges)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func createBadge(_ badge: Badge) async throws -> Badge {
        let query = """
            INSERT INTO badges (
                id, name, description, icon, rarity, unlockedAt, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let parameters: [Any] = [
            badge.id,
            badge.name,
            badge.description,
            badge.icon,
            badge.rarity.rawValue,
            badge.unlockedAt?.timeIntervalSince1970 as Any,
            badge.createdAt.timeIntervalSince1970,
            badge.updatedAt.timeIntervalSince1970
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume(returning: badge)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateBadge(_ badge: Badge) async throws -> Badge {
        let query = """
            UPDATE badges SET
                name = ?, description = ?, icon = ?, rarity = ?, unlockedAt = ?,
                updated_at = ?
            WHERE id = ?
        """
        
        let parameters: [Any] = [
            badge.name,
            badge.description,
            badge.icon,
            badge.rarity.rawValue,
            badge.unlockedAt?.timeIntervalSince1970 as Any,
            badge.updatedAt.timeIntervalSince1970,
            badge.id
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume(returning: badge)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - XPEvents
    
    func getXPEvents(limit: Int = 50) async throws -> [XPEvent] {
        let query = """
            SELECT id, type, amount, description, metadata, createdAt
            FROM xp_events
            ORDER BY createdAt DESC
            LIMIT ?
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            var events: [XPEvent] = []
            
            db.executeQuery(query: query, parameters: [limit]) { result in
                switch result {
                case .success(let statement):
                    while sqlite3_step(statement) == SQLITE_ROW {
                        events.append(self.xpEventFromRow(statement: statement))
                    }
                    continuation.resume(returning: events)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func createXPEvent(_ event: XPEvent) async throws -> XPEvent {
        let query = """
            INSERT INTO xp_events (
                id, type, amount, description, metadata, createdAt
            ) VALUES (?, ?, ?, ?, ?, ?)
        """
        
        let metadataJSON = try? JSONEncoder().encode(event.metadata)
        let metadataString = metadataJSON.flatMap { String(data: $0, encoding: .utf8) }
        
        let parameters: [Any] = [
            event.id,
            event.type.rawValue,
            event.amount,
            event.description,
            metadataString ?? "",
            event.createdAt.timeIntervalSince1970
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume(returning: event)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func progressionFromRow(statement: OpaquePointer) -> Progression {
        let id = Int(sqlite3_column_int64(statement, 0))
        let level = Int(sqlite3_column_int(statement, 1))
        let xpInLevel = Int(sqlite3_column_int(statement, 2))
        let prestige = Int(sqlite3_column_int(statement, 3))
        let dailyXP = Int(sqlite3_column_int(statement, 4))
        let totalXP = Int(sqlite3_column_int(statement, 5))
        let xpRequiredForNextLevel = Int(sqlite3_column_int(statement, 6))
        
        let lastXPResetTimestamp = sqlite3_column_double(statement, 7)
        let lastXPReset = Date(timeIntervalSince1970: lastXPResetTimestamp)
        
        let lastPrestigeTimestamp = sqlite3_column_double(statement, 8)
        let lastPrestigeDate = lastPrestigeTimestamp > 0 ? Date(timeIntervalSince1970: lastPrestigeTimestamp) : nil
        
        let createdAtTimestamp = sqlite3_column_double(statement, 9)
        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        
        let updatedAtTimestamp = sqlite3_column_double(statement, 10)
        let updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
        
        return Progression(
            id: id,
            level: level,
            xpInLevel: xpInLevel,
            prestige: prestige,
            dailyXP: dailyXP,
            totalXP: totalXP,
            xpRequiredForNextLevel: xpRequiredForNextLevel,
            lastXPReset: lastXPReset,
            lastPrestigeDate: lastPrestigeDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func badgeFromRow(statement: OpaquePointer) -> Badge {
        let id = sqlite3_column_text(statement, 0).flatMap { String(cString: $0) } ?? ""
        let name = sqlite3_column_text(statement, 1).flatMap { String(cString: $0) } ?? ""
        let description = sqlite3_column_text(statement, 2).flatMap { String(cString: $0) } ?? ""
        let icon = sqlite3_column_text(statement, 3).flatMap { String(cString: $0) } ?? ""
        let rarityString = sqlite3_column_text(statement, 4).flatMap { String(cString: $0) } ?? ""
        let rarity = BadgeRarity(rawValue: rarityString) ?? .common
        
        let unlockedAtTimestamp = sqlite3_column_double(statement, 5)
        let unlockedAt = unlockedAtTimestamp > 0 ? Date(timeIntervalSince1970: unlockedAtTimestamp) : nil
        
        let createdAtTimestamp = sqlite3_column_double(statement, 6)
        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        
        let updatedAtTimestamp = sqlite3_column_double(statement, 7)
        let updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
        
        return Badge(
            id: id,
            name: name,
            description: description,
            icon: icon,
            rarity: rarity,
            unlockedAt: unlockedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    private func xpEventFromRow(statement: OpaquePointer) -> XPEvent {
        let id = sqlite3_column_text(statement, 0).flatMap { String(cString: $0) } ?? ""
        let typeString = sqlite3_column_text(statement, 1).flatMap { String(cString: $0) } ?? ""
        let type = XPEventType(rawValue: typeString) ?? .checklist
        let amount = Int(sqlite3_column_int(statement, 2))
        let description = sqlite3_column_text(statement, 3).flatMap { String(cString: $0) } ?? ""
        
        let metadataString = sqlite3_column_text(statement, 4).flatMap { String(cString: $0) } ?? ""
        let metadata: [String: String] = (try? JSONDecoder().decode([String: String].self, from: metadataString.data(using: .utf8) ?? Data())) ?? [:]
        
        let createdAtTimestamp = sqlite3_column_double(statement, 5)
        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        
        return XPEvent(
            id: id,
            type: type,
            amount: amount,
            description: description,
            metadata: metadata,
            createdAt: createdAt
        )
    }
}

// MARK: - Error Types

enum PrestigeStoreError: Error {
    case notFound
    case databaseError(String)
    case invalidData
}
