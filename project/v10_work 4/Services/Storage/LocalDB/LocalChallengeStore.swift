import Foundation
import SQLite3

class LocalChallengeStore: ChallengeStore {
    private let db: LocalDatabase
    
    init(database: LocalDatabase) {
        self.db = database
    }
    
    // MARK: - Challenges
    
    func getDailyChallenges() async throws -> [Challenge] {
        let query = """
            SELECT id, title, description, type, targetValue, currentValue, rewardXP, 
                   isCompleted, completedAt, expiresAt, mutators, created_at, updated_at
            FROM challenges
            WHERE type = 'daily' AND expiresAt > ?
            ORDER BY created_at ASC
        """
        
        let now = Date().timeIntervalSince1970
        
        return try await withCheckedThrowingContinuation { continuation in
            var challenges: [Challenge] = []
            
            db.executeQuery(query: query, parameters: [now]) { result in
                switch result {
                case .success(let statement):
                    while sqlite3_step(statement) == SQLITE_ROW {
                        challenges.append(self.challengeFromRow(statement: statement))
                    }
                    continuation.resume(returning: challenges)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getWeeklyChallenges() async throws -> [Challenge] {
        let query = """
            SELECT id, title, description, type, targetValue, currentValue, rewardXP, 
                   isCompleted, completedAt, expiresAt, mutators, created_at, updated_at
            FROM challenges
            WHERE type = 'weekly' AND expiresAt > ?
            ORDER BY created_at ASC
        """
        
        let now = Date().timeIntervalSince1970
        
        return try await withCheckedThrowingContinuation { continuation in
            var challenges: [Challenge] = []
            
            db.executeQuery(query: query, parameters: [now]) { result in
                switch result {
                case .success(let statement):
                    while sqlite3_step(statement) == SQLITE_ROW {
                        challenges.append(self.challengeFromRow(statement: statement))
                    }
                    continuation.resume(returning: challenges)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getAllChallenges() async throws -> [Challenge] {
        let query = """
            SELECT id, title, description, type, targetValue, currentValue, rewardXP, 
                   isCompleted, completedAt, expiresAt, mutators, created_at, updated_at
            FROM challenges
            ORDER BY type, created_at ASC
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            var challenges: [Challenge] = []
            
            db.executeQuery(query: query) { result in
                switch result {
                case .success(let statement):
                    while sqlite3_step(statement) == SQLITE_ROW {
                        challenges.append(self.challengeFromRow(statement: statement))
                    }
                    continuation.resume(returning: challenges)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func createChallenge(_ challenge: Challenge) async throws -> Challenge {
        let query = """
            INSERT INTO challenges (
                id, title, description, type, targetValue, currentValue, rewardXP,
                isCompleted, completedAt, expiresAt, mutators, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        
        let mutatorsJSON = try? JSONEncoder().encode(challenge.mutators)
        let mutatorsString = mutatorsJSON.flatMap { String(data: $0, encoding: .utf8) }
        
        let parameters: [Any] = [
            challenge.id,
            challenge.title,
            challenge.description,
            challenge.type.rawValue,
            challenge.targetValue,
            challenge.currentValue,
            challenge.rewardXP,
            challenge.isCompleted,
            challenge.completedAt?.timeIntervalSince1970 as Any,
            challenge.expiresAt.timeIntervalSince1970,
            mutatorsString ?? "",
            challenge.createdAt.timeIntervalSince1970,
            challenge.updatedAt.timeIntervalSince1970
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume(returning: challenge)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateChallenge(_ challenge: Challenge) async throws -> Challenge {
        let query = """
            UPDATE challenges SET
                title = ?, description = ?, type = ?, targetValue = ?, currentValue = ?,
                rewardXP = ?, isCompleted = ?, completedAt = ?, expiresAt = ?,
                mutators = ?, updated_at = ?
            WHERE id = ?
        """
        
        let mutatorsJSON = try? JSONEncoder().encode(challenge.mutators)
        let mutatorsString = mutatorsJSON.flatMap { String(data: $0, encoding: .utf8) }
        
        let parameters: [Any] = [
            challenge.title,
            challenge.description,
            challenge.type.rawValue,
            challenge.targetValue,
            challenge.currentValue,
            challenge.rewardXP,
            challenge.isCompleted,
            challenge.completedAt?.timeIntervalSince1970 as Any,
            challenge.expiresAt.timeIntervalSince1970,
            mutatorsString ?? "",
            challenge.updatedAt.timeIntervalSince1970,
            challenge.id
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume(returning: challenge)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteChallenge(_ challengeId: String) async throws {
        let query = "DELETE FROM challenges WHERE id = ?"
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: [challengeId]) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Challenge Progress
    
    func getChallengeProgress(_ challengeId: String) async throws -> Int {
        let query = """
            SELECT currentValue FROM challenges WHERE id = ?
        """
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: [challengeId]) { result in
                switch result {
                case .success(let statement):
                    if sqlite3_step(statement) == SQLITE_ROW {
                        let progress = Int(sqlite3_column_int(statement, 0))
                        continuation.resume(returning: progress)
                    } else {
                        continuation.resume(returning: 0)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateChallengeProgress(_ challengeId: String, progress: Int) async throws {
        let query = """
            UPDATE challenges SET currentValue = ?, updated_at = ?
            WHERE id = ?
        """
        
        let parameters: [Any] = [
            progress,
            Date().timeIntervalSince1970,
            challengeId
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func completeChallenge(_ challengeId: String) async throws {
        let query = """
            UPDATE challenges SET 
                isCompleted = true, 
                completedAt = ?, 
                updated_at = ?
            WHERE id = ?
        """
        
        let parameters: [Any] = [
            Date().timeIntervalSince1970,
            Date().timeIntervalSince1970,
            challengeId
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Challenge Rerolls
    
    func getRerollCount(for date: Date) async throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let query = """
            SELECT COUNT(*) FROM challenge_rerolls 
            WHERE rerollDate >= ? AND rerollDate < ?
        """
        
        let parameters: [Any] = [
            startOfDay.timeIntervalSince1970,
            endOfDay.timeIntervalSince1970
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success(let statement):
                    if sqlite3_step(statement) == SQLITE_ROW {
                        let count = Int(sqlite3_column_int(statement, 0))
                        continuation.resume(returning: count)
                    } else {
                        continuation.resume(returning: 0)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func recordReroll(for challengeId: String) async throws {
        let query = """
            INSERT INTO challenge_rerolls (challengeId, rerollDate)
            VALUES (?, ?)
        """
        
        let parameters: [Any] = [
            challengeId,
            Date().timeIntervalSince1970
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            db.executeQuery(query: query, parameters: parameters) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func challengeFromRow(statement: OpaquePointer) -> Challenge {
        let id = sqlite3_column_text(statement, 0).flatMap { String(cString: $0) } ?? ""
        let title = sqlite3_column_text(statement, 1).flatMap { String(cString: $0) } ?? ""
        let description = sqlite3_column_text(statement, 2).flatMap { String(cString: $0) } ?? ""
        let typeString = sqlite3_column_text(statement, 3).flatMap { String(cString: $0) } ?? ""
        let type = Challenge.ChallengeType(rawValue: typeString) ?? .daily
        
        let targetValue = Int(sqlite3_column_int(statement, 4))
        let currentValue = Int(sqlite3_column_int(statement, 5))
        let rewardXP = Int(sqlite3_column_int(statement, 6))
        let isCompleted = sqlite3_column_int(statement, 7) != 0
        
        let completedAtTimestamp = sqlite3_column_double(statement, 8)
        let completedAt = completedAtTimestamp > 0 ? Date(timeIntervalSince1970: completedAtTimestamp) : nil
        
        let expiresAtTimestamp = sqlite3_column_double(statement, 9)
        let expiresAt = Date(timeIntervalSince1970: expiresAtTimestamp)
        
        let mutatorsString = sqlite3_column_text(statement, 10).flatMap { String(cString: $0) } ?? ""
        let mutators: [ChallengeMutator] = (try? JSONDecoder().decode([ChallengeMutator].self, from: mutatorsString.data(using: .utf8) ?? Data())) ?? []
        
        let createdAtTimestamp = sqlite3_column_double(statement, 11)
        let createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        
        let updatedAtTimestamp = sqlite3_column_double(statement, 12)
        let updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
        
        return Challenge(
            id: id,
            title: title,
            description: description,
            type: type,
            targetValue: targetValue,
            currentValue: currentValue,
            rewardXP: rewardXP,
            isCompleted: isCompleted,
            completedAt: completedAt,
            expiresAt: expiresAt,
            mutators: mutators,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Error Types

enum ChallengeStoreError: Error {
    case notFound
    case databaseError(String)
    case invalidData
    case rerollLimitExceeded
}
