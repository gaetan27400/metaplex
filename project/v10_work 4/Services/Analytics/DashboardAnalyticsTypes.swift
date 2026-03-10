import Foundation

// ❌ PAS de @MainActor
// ❌ PAS de SwiftUI
// ❌ PAS de type englobant UI

enum DashboardHeatmapPeriod: Int, CaseIterable, Hashable, Identifiable {
    case week
    case month
    case threeMonths
    case sixMonths
    case year

    nonisolated var id: Self { self }

    nonisolated var displayName: String {
        switch self {
        case .week: return "7j"
        case .month: return "1M"
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .year: return "1A"
        }
    }

    nonisolated var weeksCount: Int {
        switch self {
        case .week: return 1
        case .month: return 5
        case .threeMonths: return 13
        case .sixMonths: return 26
        case .year: return 52
        }
    }
}

enum CurveTimeRange: Int, CaseIterable, Hashable, Identifiable {
    case daily
    case week
    case twoWeeks
    case month
    case threeMonths
    case sixMonths
    case year
    case all

    nonisolated var id: Self { self }

    nonisolated var displayName: String {
        switch self {
        case .daily: return "1J"
        case .week: return "7J"
        case .twoWeeks: return "14J"
        case .month: return "1M"
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .year: return "1A"
        case .all: return "Tout"
        }
    }

    nonisolated var title: String { displayName }
}

enum CurveXAxisUnit: Int, Hashable {
    case day
    case month
}

struct CurveDateRange: Hashable {
    let start: Date
    let end: Date
}

struct DashboardHeatmapCell: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let value: Double

    let fillHex: String
    let fillOpacity: Double
    let strokeOpacity: Double
    let accessibilityLabel: String
    let title: String
    let primaryText: String
    let secondaryText: String
    let count: Int
    let isBest: Bool
    let isWorst: Bool
    let isCurrentWeek: Bool

    nonisolated init(
        date: Date,
        value: Double,
        fillHex: String,
        fillOpacity: Double,
        strokeOpacity: Double,
        accessibilityLabel: String,
        title: String = "",
        primaryText: String = "",
        secondaryText: String = "",
        count: Int = 0,
        isBest: Bool = false,
        isWorst: Bool = false,
        isCurrentWeek: Bool = false,
        id: UUID = UUID()
    ) {
        self.id = id
        self.date = date
        self.value = value
        self.fillHex = fillHex
        self.fillOpacity = fillOpacity
        self.strokeOpacity = strokeOpacity
        self.accessibilityLabel = accessibilityLabel
        self.title = title
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.count = count
        self.isBest = isBest
        self.isWorst = isWorst
        self.isCurrentWeek = isCurrentWeek
    }
}

struct DashboardCurvePoint: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let value: Double

    nonisolated init(date: Date, value: Double, id: UUID = UUID()) {
        self.id = id
        self.date = date
        self.value = value
    }
}

struct DashboardBarPoint: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let value: Double

    nonisolated init(date: Date, value: Double, id: UUID = UUID()) {
        self.id = id
        self.date = date
        self.value = value
    }
}

struct CurveInsight: Identifiable, Hashable {
    let id: String
    let text: String
}

// MARK: - Explicit nonisolated Hashable conformances (required for Swift 6)

extension DashboardHeatmapPeriod {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
    
    nonisolated static func == (lhs: DashboardHeatmapPeriod, rhs: DashboardHeatmapPeriod) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

extension CurveTimeRange {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
    
    nonisolated static func == (lhs: CurveTimeRange, rhs: CurveTimeRange) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

extension CurveXAxisUnit {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
    
    nonisolated static func == (lhs: CurveXAxisUnit, rhs: CurveXAxisUnit) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

extension DashboardHeatmapCell {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: DashboardHeatmapCell, rhs: DashboardHeatmapCell) -> Bool {
        lhs.id == rhs.id
    }
}

extension DashboardCurvePoint {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: DashboardCurvePoint, rhs: DashboardCurvePoint) -> Bool {
        lhs.id == rhs.id
    }
}

extension DashboardBarPoint {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: DashboardBarPoint, rhs: DashboardBarPoint) -> Bool {
        lhs.id == rhs.id
    }
}

extension CurveInsight {
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: CurveInsight, rhs: CurveInsight) -> Bool {
        lhs.id == rhs.id
    }
}
