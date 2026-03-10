//
//  Alert.swift
//  Journal de trading 2025
//

import Foundation

// MARK: - Alert Domain Model

struct Alert: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    let symbol: String
    let exchange: String?
    let price: Double?
    let message: String
    let severity: AlertSeverity
    let tags: [String]
    let payloadJSON: String
    var isRead: Bool
    let source: AlertSource
    let linkedTradeId: UUID?
    
    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         symbol: String,
         exchange: String? = nil,
         price: Double? = nil,
         message: String,
         severity: AlertSeverity = .normal,
         tags: [String] = [],
         payloadJSON: String = "{}",
         isRead: Bool = false,
         source: AlertSource = .tradingView,
         linkedTradeId: UUID? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.symbol = symbol
        self.exchange = exchange
        self.price = price
        self.message = message
        self.severity = severity
        self.tags = tags
        self.payloadJSON = payloadJSON
        self.isRead = isRead
        self.source = source
        self.linkedTradeId = linkedTradeId
    }
}

// MARK: - Alert Severity

enum AlertSeverity: String, CaseIterable, Codable {
    case info = "info"
    case normal = "normal"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .info: return "Info"
        case .normal: return "Normal"
        case .high: return "Élevé"
        }
    }
    
    var color: String {
        switch self {
        case .info: return "#4ECDC4"
        case .normal: return "#FFE66D"
        case .high: return "#FF6B6B"
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .normal: return "exclamationmark.circle.fill"
        case .high: return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Alert Source

enum AlertSource: String, CaseIterable, Codable {
    case tradingView = "tradingView"
    case custom = "custom"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .tradingView: return "TradingView"
        case .custom: return "Personnalisé"
        case .other: return "Autre"
        }
    }
    
    var icon: String {
        switch self {
        case .tradingView: return "chart.line.uptrend.xyaxis"
        case .custom: return "person.circle.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Alert Filters

struct AlertFilters {
    var symbol: String?
    var severity: AlertSeverity?
    var tags: [String]?
    var dateRange: DateInterval?
    var isRead: Bool?
    var source: AlertSource?
    
    static let `default` = AlertFilters()
}

// MARK: - Alert Statistics

struct AlertStatistics {
    let totalCount: Int
    let unreadCount: Int
    let bySeverity: [AlertSeverity: Int]
    let bySource: [AlertSource: Int]
    let recentCount: Int // Last 24 hours
}


