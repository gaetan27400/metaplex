import Foundation

protocol ChallengeStore {
    func getDailyChallenges() async throws -> [Challenge]
    func getWeeklyChallenges() async throws -> [Challenge]
    func getAllChallenges() async throws -> [Challenge]
    func createChallenge(_ challenge: Challenge) async throws -> Challenge
    func updateChallenge(_ challenge: Challenge) async throws -> Challenge
    func deleteChallenge(_ challengeId: String) async throws
    func getChallengeProgress(_ challengeId: String) async throws -> Int
    func updateChallengeProgress(_ challengeId: String, progress: Int) async throws
    func completeChallenge(_ challengeId: String) async throws
    func getRerollCount(for date: Date) async throws -> Int
    func recordReroll(for challengeId: String) async throws
}











