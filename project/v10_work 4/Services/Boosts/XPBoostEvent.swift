import Foundation

struct XPBoostEvent: Codable, Hashable {
    let id: String
    let title: String
    let multiplier: Double // e.g., 1.3 for +30%
    let startsAt: Date
    let endsAt: Date
}

final class XPBoostProvider {
    private var cache: [XPBoostEvent] = []
    private var cacheDate: Date?
    private let cacheTTL: TimeInterval = 3600
    
    func fetchActiveBoosts(now: Date = Date()) async -> [XPBoostEvent] {
        if let ts = cacheDate, now.timeIntervalSince(ts) < cacheTTL { return cache.filter { $0.startsAt <= now && now <= $0.endsAt } }
        // Stub: aucun boost par défaut
        cache = []
        cacheDate = now
        return []
    }
}












