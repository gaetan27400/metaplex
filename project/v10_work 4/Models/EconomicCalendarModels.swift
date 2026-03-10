//
//  EconomicCalendarModels.swift
//  Journal de trading 2025
//
//  Modèles pour le calendrier économique
//

import Foundation

// MARK: - Calendar Response

struct CalendarResponse: Codable {
    let success: Bool?
    let message: String?
    let data: [CalendarEvent]? // Optionnel car absent en cas d'erreur API
    let lastUpdated: String?
    let totalEvents: Int?
    let timezone: String?
    let volatilityBreakdown: VolatilityBreakdown?
    let dateRange: DateRange?
    let maxLimit: Int?
}

// MARK: - Calendar Event

struct CalendarEvent: Codable, Identifiable, Equatable {
    let id: String
    let eventId: String?
    let name: String
    let countryCode: String
    let currencyCode: String?
    let dateUtc: String
    let periodDateUtc: String?
    let periodType: String?
    let volatility: String
    let actual: String?
    let revised: String?
    let consensus: String?
    let previous: String?
    let unit: String?
    let categoryId: String?
    let ratioDeviation: Double?
    let isBetterThanExpected: Bool?
    let isScoreTrackable: Bool?
    let isAllDay: Bool?
    let isTentative: Bool?
    let isPreliminary: Bool?
    let isReport: Bool?
    let isSpeech: Bool?
    let hasHistorical: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId
        case name
        case countryCode
        case currencyCode
        case dateUtc
        case periodDateUtc
        case periodType
        case volatility
        case actual
        case revised
        case consensus
        case previous
        case unit
        case categoryId
        case ratioDeviation
        case isBetterThanExpected
        case isScoreTrackable
        case isAllDay
        case isTentative
        case isPreliminary
        case isReport
        case isSpeech
        case hasHistorical
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // id peut être String OU Int
        if let s = try? container.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? container.decode(Int.self, forKey: .id) {
            id = String(i)
        } else {
            id = UUID().uuidString
        }
        
        // Champs critiques avec fallback
        name = (try? container.decode(String.self, forKey: .name)) ?? "Unknown"
        countryCode = (try? container.decode(String.self, forKey: .countryCode)) ?? "--"
        dateUtc = (try? container.decode(String.self, forKey: .dateUtc)) ?? ""
        volatility = (try? container.decode(String.self, forKey: .volatility)) ?? "NONE"
        
        // Champs optionnels
        eventId = try? container.decode(String.self, forKey: .eventId)
        currencyCode = try? container.decode(String.self, forKey: .currencyCode)
        periodDateUtc = try? container.decode(String.self, forKey: .periodDateUtc)
        periodType = try? container.decode(String.self, forKey: .periodType)
        actual = try? container.decode(String.self, forKey: .actual)
        revised = try? container.decode(String.self, forKey: .revised)
        consensus = try? container.decode(String.self, forKey: .consensus)
        previous = try? container.decode(String.self, forKey: .previous)
        unit = try? container.decode(String.self, forKey: .unit)
        categoryId = try? container.decode(String.self, forKey: .categoryId)
        ratioDeviation = try? container.decode(Double.self, forKey: .ratioDeviation)
        isBetterThanExpected = try? container.decode(Bool.self, forKey: .isBetterThanExpected)
        isScoreTrackable = try? container.decode(Bool.self, forKey: .isScoreTrackable)
        isAllDay = try? container.decode(Bool.self, forKey: .isAllDay)
        isTentative = try? container.decode(Bool.self, forKey: .isTentative)
        isPreliminary = try? container.decode(Bool.self, forKey: .isPreliminary)
        isReport = try? container.decode(Bool.self, forKey: .isReport)
        isSpeech = try? container.decode(Bool.self, forKey: .isSpeech)
        hasHistorical = try? container.decode(Bool.self, forKey: .hasHistorical)
    }
    
    // Initializer public pour les tests
    init(
        id: String,
        eventId: String? = nil,
        name: String,
        countryCode: String,
        currencyCode: String? = nil,
        dateUtc: String,
        periodDateUtc: String? = nil,
        periodType: String? = nil,
        volatility: String,
        actual: String? = nil,
        revised: String? = nil,
        consensus: String? = nil,
        previous: String? = nil,
        unit: String? = nil,
        categoryId: String? = nil,
        ratioDeviation: Double? = nil,
        isBetterThanExpected: Bool? = nil,
        isScoreTrackable: Bool? = nil,
        isAllDay: Bool? = nil,
        isTentative: Bool? = nil,
        isPreliminary: Bool? = nil,
        isReport: Bool? = nil,
        isSpeech: Bool? = nil,
        hasHistorical: Bool? = nil
    ) {
        self.id = id
        self.eventId = eventId
        self.name = name
        self.countryCode = countryCode
        self.currencyCode = currencyCode
        self.dateUtc = dateUtc
        self.periodDateUtc = periodDateUtc
        self.periodType = periodType
        self.volatility = volatility
        self.actual = actual
        self.revised = revised
        self.consensus = consensus
        self.previous = previous
        self.unit = unit
        self.categoryId = categoryId
        self.ratioDeviation = ratioDeviation
        self.isBetterThanExpected = isBetterThanExpected
        self.isScoreTrackable = isScoreTrackable
        self.isAllDay = isAllDay
        self.isTentative = isTentative
        self.isPreliminary = isPreliminary
        self.isReport = isReport
        self.isSpeech = isSpeech
        self.hasHistorical = hasHistorical
    }
    
    // Propriété calculée pour convertir dateUtc en Date (optionnel pour éviter de faux événements)
    var dateValue: Date? {
        guard !dateUtc.isEmpty else { return nil }
        
        let formatter1 = ISO8601DateFormatter()
        formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter1.date(from: dateUtc) {
            return date
        }
        
        let formatter2 = ISO8601DateFormatter()
        formatter2.formatOptions = [.withInternetDateTime]
        if let date = formatter2.date(from: dateUtc) {
            return date
        }
        
        let formatter3 = DateFormatter()
        formatter3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter3.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = formatter3.date(from: dateUtc) {
            return date
        }
        
        return nil // Ne pas retourner Date() pour éviter de faux événements
    }
    
    // Propriété calculée pour convertir periodDateUtc en Date
    var periodDateValue: Date? {
        guard let periodDateUtc = periodDateUtc else { return nil }
        
        let formatter1 = ISO8601DateFormatter()
        formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter1.date(from: periodDateUtc) {
            return date
        }
        
        let formatter2 = ISO8601DateFormatter()
        formatter2.formatOptions = [.withInternetDateTime]
        if let date = formatter2.date(from: periodDateUtc) {
            return date
        }
        
        return nil
    }
    
    // Propriété calculée pour convertir volatility en EventImpact
    var impactValue: EventImpact {
        switch volatility.uppercased() {
        case "HIGH": return .high
        case "MEDIUM": return .medium
        case "LOW": return .low
        case "NONE": return .low
        default: return .low
        }
    }
    
    // Propriété calculée pour convertir categoryId en EventCategory
    var category: EventCategory? {
        guard let categoryId = categoryId else { return nil }
        return EventCategory.from(categoryId: categoryId)
    }
    
    // Propriétés de compatibilité avec l'ancien code
    var title: String { name }
    var country: String { countryCode }
    var date: String { dateUtc }
    var impact: String { volatility }
    var forecast: String? { consensus }
    
    /// Description textuelle pour l'UI (compat avec l'ancien modèle)
    /// Construite intelligemment à partir des champs API disponibles
    var description: String? {
        var parts: [String] = []
        
        if let unit = unit {
            parts.append("Unité: \(unit)")
        }
        
        if let periodType = periodType, !periodType.isEmpty {
            parts.append("Période: \(periodType.capitalized)")
        }
        
        if let categoryId = categoryId {
            parts.append("Catégorie: \(categoryId.capitalized)")
        }
        
        if isPreliminary == true {
            parts.append("Preliminaire")
        }
        
        if isTentative == true {
            parts.append("Tentative")
        }
        
        if isReport == true {
            parts.append("Rapport")
        }
        
        if isSpeech == true {
            parts.append("Discours")
        }
        
        if let ratioDeviation = ratioDeviation {
            let deviationPercent = String(format: "%.1f%%", ratioDeviation * 100)
            if isBetterThanExpected == true {
                parts.append("Mieux que prévu (+\(deviationPercent))")
            } else if isBetterThanExpected == false {
                parts.append("Moins bien que prévu (-\(deviationPercent))")
            }
        }
        
        if parts.isEmpty {
            return nil
        }
        
        return parts.joined(separator: " • ")
    }
}

// MARK: - Volatility Breakdown

struct VolatilityBreakdown: Codable {
    let NONE: Int
    let LOW: Int
    let MEDIUM: Int
    let HIGH: Int
}

// MARK: - Date Range

struct DateRange: Codable {
    let start: String
    let end: String
}

// MARK: - Event Impact

enum EventImpact: String, Codable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .high: return "Élevé"
        case .medium: return "Moyen"
        case .low: return "Faible"
        }
    }
    
    var color: String {
        switch self {
        case .high: return "#FF3B30"
        case .medium: return "#FF9500"
        case .low: return "#34C759"
        }
    }
}

// MARK: - Event Category

enum EventCategory: String, Codable {
    case employment = "employment"
    case inflation = "inflation"
    case gdp = "gdp"
    case interestRate = "interest rate"
    case centralBank = "central bank"
    case trade = "trade"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .employment: return "Emploi"
        case .inflation: return "Inflation"
        case .gdp: return "PIB"
        case .interestRate: return "Taux d'intérêt"
        case .centralBank: return "Banque centrale"
        case .trade: return "Commerce"
        case .other: return "Autre"
        }
    }
    
    var icon: String {
        switch self {
        case .employment: return "person.2.fill"
        case .inflation: return "chart.line.uptrend.xyaxis"
        case .gdp: return "chart.bar.fill"
        case .interestRate: return "percent"
        case .centralBank: return "building.columns.fill"
        case .trade: return "arrow.left.arrow.right"
        case .other: return "circle.fill"
        }
    }
    
    // Méthode pour convertir categoryId de l'API en EventCategory
    static func from(categoryId: String) -> EventCategory {
        switch categoryId.lowercased() {
        case "employment", "jobs": return .employment
        case "inflation", "cpi", "ppi": return .inflation
        case "gdp", "gross domestic product": return .gdp
        case "interest rate", "rates", "fed": return .interestRate
        case "central bank", "centralbank", "cb": return .centralBank
        case "trade", "trade balance": return .trade
        default: return .other
        }
    }
}

// MARK: - Market Risk Analysis

struct MarketRiskAnalysis: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let riskLevel: RiskLevel
    let summary: String
    let events: [CalendarEvent]
    let recommendations: [String]
    let marketRecommendations: [MarketRecommendation]
    let affectedMarkets: [String]
    let marketSentiment: MarketSentiment
    let sentimentArgumentation: String
    
    enum MarketSentiment: String, Codable, Equatable {
        case bullish = "POSITIF"
        case bearish = "NÉGATIF"
        case neutral = "NEUTRE"
        
        var displayName: String {
            switch self {
            case .bullish: return "Positif"
            case .bearish: return "Négatif"
            case .neutral: return "Neutre"
            }
        }
        
        var color: String {
            switch self {
            case .bullish: return "#10B981" // Green
            case .bearish: return "#EF4444" // Red
            case .neutral: return "#6B7280" // Gray
            }
        }
        
        var icon: String {
            switch self {
            case .bullish: return "arrow.up.circle.fill"
            case .bearish: return "arrow.down.circle.fill"
            case .neutral: return "minus.circle.fill"
            }
        }
    }
    
    enum RiskLevel: String, Codable {
        case critical = "CRITICAL"
        case veryHigh = "VERY_HIGH"
        case high = "HIGH"
        case medium = "MEDIUM"
        case low = "LOW"
        
        var displayName: String {
            switch self {
            case .critical: return "Critique"
            case .veryHigh: return "Très élevé"
            case .high: return "Élevé"
            case .medium: return "Moyen"
            case .low: return "Faible"
            }
        }
        
        var color: String {
            switch self {
            case .critical: return "#FF3B30"
            case .veryHigh: return "#FF6B35"
            case .high: return "#FF9500"
            case .medium: return "#FFCC00"
            case .low: return "#34C759"
            }
        }
    }
    
    struct MarketRecommendation: Equatable {
        let market: String
        let recommendations: [String]
        let rationale: String
        
        // Nouveaux champs pour analyse précise et directive
        let title: String // Ex: "Crypto — CPI en hausse"
        let sentiment: MarketSentiment // Sentiment spécifique pour ce marché
        let intensity: String // "Élevée", "Modérée", "Faible"
        let explanation: String // Explication détaillée du contexte
        let actionableRecommendations: [String] // Recommandations avec flèches
        
        // Initializer avec valeurs par défaut pour compatibilité
        init(
            market: String,
            recommendations: [String],
            rationale: String,
            title: String? = nil,
            sentiment: MarketSentiment? = nil,
            intensity: String? = nil,
            explanation: String? = nil,
            actionableRecommendations: [String]? = nil
        ) {
            self.market = market
            self.recommendations = recommendations
            self.rationale = rationale
            self.title = title ?? market
            self.sentiment = sentiment ?? .neutral
            self.intensity = intensity ?? "Faible"
            self.explanation = explanation ?? rationale
            self.actionableRecommendations = actionableRecommendations ?? recommendations
        }
    }
}

// MARK: - Timezone Info

struct TimezoneInfo: Identifiable, Codable, Equatable {
    let id: String
    let timezone: String
    let zone: String
    let offset: String
    let name: String
    
    // Init public pour créer manuellement des TimezoneInfo
    init(timezone: String, zone: String, offset: String, name: String) {
        self.timezone = timezone
        self.zone = zone
        self.offset = offset
        self.name = name
        self.id = timezone // Utiliser timezone comme ID unique
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timezone = try container.decode(String.self, forKey: .timezone)
        zone = try container.decode(String.self, forKey: .zone)
        offset = try container.decode(String.self, forKey: .offset)
        name = try container.decode(String.self, forKey: .name)
        id = timezone // Utiliser timezone comme ID unique
    }
    
    enum CodingKeys: String, CodingKey {
        case timezone
        case zone
        case offset
        case name
    }
}

// MARK: - Timezones Response

struct TimezonesResponse: Codable {
    let success: Bool
    let message: String
    let timezones: [TimezoneInfo]
    let total: Int
    let `default`: String
}

// MARK: - Typealias pour compatibilité

typealias EconomicEvent = CalendarEvent
typealias EconomicCalendarResponse = CalendarResponse
