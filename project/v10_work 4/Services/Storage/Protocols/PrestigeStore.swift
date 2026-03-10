import Foundation

protocol PrestigeStore {
    func getProgression() async throws -> Progression
    func createProgression(_ progression: Progression) async throws -> Progression
    func updateProgression(_ progression: Progression) async throws -> Progression
    func getBadges() async throws -> [Badge]
    func getRecentBadges(limit: Int) async throws -> [Badge]
    func createBadge(_ badge: Badge) async throws -> Badge
    func updateBadge(_ badge: Badge) async throws -> Badge
    func getXPEvents(limit: Int) async throws -> [XPEvent]
    func createXPEvent(_ event: XPEvent) async throws -> XPEvent
}











