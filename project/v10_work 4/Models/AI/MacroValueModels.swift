//
//  MacroValueModels.swift
//  Journal de trading 2025
//
//  Modèles pour le parsing et l'analyse des valeurs macroéconomiques
//

import Foundation

// MARK: - Parsed Macro Value

struct ParsedMacroValue: Equatable {
    let raw: String
    let numericValue: Double?
    let unit: UnitType
    let magnitude: Magnitude
    let isValid: Bool
    
    enum UnitType: Equatable {
        case percent
        case number
    }
    
    enum Magnitude: Equatable {
        case none
        case k      // 1e3
        case m      // 1e6
        case b      // 1e9
    }
}

// MARK: - Surprise Result

struct SurpriseResult: Equatable {
    let baseline: BaselineType
    let surpriseValue: Double?
    let surprisePct: Double?
    let direction: SurpriseDirection
    let intensity: SurpriseIntensity
    let debug: String
    
    enum BaselineType: Equatable {
        case consensus
        case previous
        case none
    }
    
    enum SurpriseDirection: Equatable {
        case above
        case below
        case equal
        case unknown
    }
    
    enum SurpriseIntensity: Equatable {
        case none
        case low
        case medium
        case high
    }
}

// MARK: - Impact Assessment

enum Market: Equatable {
    case fx
    case rates
    case equities
}

enum ImpactBias: Equatable {
    case bullish
    case bearish
    case mixed
    case unknown
}

struct ImpactAssessment: Equatable {
    let market: Market
    let biasIfAbove: ImpactBias
    let biasIfBelow: ImpactBias
    let rationale: String
}

struct EventImpactProfile: Equatable {
    let higherIsBetter: Bool?
    let assessments: [ImpactAssessment]
}

// MARK: - Scenario Pair

struct ScenarioPair: Equatable {
    let above: String
    let below: String
}

// MARK: - AI Event Insight

struct AIEventInsight: Equatable {
    let title: String
    let status: InsightStatus
    let surprise: SurpriseResult?
    let scenarios: ScenarioPair?
    let summary: String
    let intensity: String
    let eventSentiment: EventSentiment
    let eventSentimentArgumentation: String
    
    enum InsightStatus: Equatable {
        case preRelease
        case postRelease
    }
    
    enum EventSentiment: String, Equatable {
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
}

// MARK: - Risk Summary

struct RiskSummary: Equatable {
    let currencyCode: String
    let dayScore: Double
    let weekScore: Double
    let topEvents: [CalendarEvent]
}
