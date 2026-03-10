//
//  ChartAnalysis.swift
//  Journal de trading 2025
//
//  Modèles pour l'analyse de graphiques via OpenAI Vision
//

import Foundation
import UIKit

struct ChartAnalysis: Decodable {
    let resume: String
    let structure: String
    let zones: String
    let momentum: String
    let patterns: String
    let indicateurs: String
    let mtf: String
    let plan: TradePlan
    let psychologie: String
    // Champs enrichis optionnels (remplis quand multi-UT)
    let confluences: String?
    let risques: String?
    let scenarioAlternatif: String?
    // Symbole détecté par l'IA (ex: "BTCUSDT", "ETHUSDT", nil si non-crypto)
    let symbol: String?

    enum CodingKeys: String, CodingKey {
        case resume, structure, zones, momentum, patterns, indicateurs, mtf, plan, psychologie
        case confluences, risques
        case scenarioAlternatif = "scenario_alternatif"
        case symbol
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        resume       = (try? c.decodeIfPresent(String.self, forKey: .resume))       ?? ""
        structure    = (try? c.decodeIfPresent(String.self, forKey: .structure))    ?? ""
        zones        = (try? c.decodeIfPresent(String.self, forKey: .zones))        ?? ""
        momentum     = (try? c.decodeIfPresent(String.self, forKey: .momentum))     ?? ""
        patterns     = (try? c.decodeIfPresent(String.self, forKey: .patterns))     ?? ""
        indicateurs  = (try? c.decodeIfPresent(String.self, forKey: .indicateurs))  ?? ""
        mtf          = (try? c.decodeIfPresent(String.self, forKey: .mtf))          ?? ""
        psychologie  = (try? c.decodeIfPresent(String.self, forKey: .psychologie))  ?? ""
        confluences  = try? c.decodeIfPresent(String.self, forKey: .confluences)
        risques      = try? c.decodeIfPresent(String.self, forKey: .risques)
        scenarioAlternatif = try? c.decodeIfPresent(String.self, forKey: .scenarioAlternatif)
        symbol       = try? c.decodeIfPresent(String.self, forKey: .symbol)
        // plan : tolérant — TradePlan vide par défaut si absent
        plan = (try? c.decode(TradePlan.self, forKey: .plan)) ?? TradePlan.empty
    }
}

struct TradePlan: Decodable {
    let biais: String
    let entree: String
    let stop: String
    let objectifs: String
    let confirmation: String
    let invalidation: String
    // Champs enrichis optionnels (remplis quand multi-UT)
    let rr: String?
    let zonesRetournement: String?

    enum CodingKeys: String, CodingKey {
        case biais, entree, stop, objectifs, confirmation, invalidation
        case rr
        case zonesRetournement = "zones_retournement"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        biais        = (try? c.decodeIfPresent(String.self, forKey: .biais))        ?? ""
        entree       = (try? c.decodeIfPresent(String.self, forKey: .entree))       ?? ""
        stop         = (try? c.decodeIfPresent(String.self, forKey: .stop))         ?? ""
        objectifs    = (try? c.decodeIfPresent(String.self, forKey: .objectifs))    ?? ""
        confirmation = (try? c.decodeIfPresent(String.self, forKey: .confirmation)) ?? ""
        invalidation = (try? c.decodeIfPresent(String.self, forKey: .invalidation)) ?? ""
        rr               = try? c.decodeIfPresent(String.self, forKey: .rr)
        zonesRetournement = try? c.decodeIfPresent(String.self, forKey: .zonesRetournement)
    }

    static let empty = TradePlan(
        biais: "", entree: "", stop: "", objectifs: "",
        confirmation: "", invalidation: "", rr: nil, zonesRetournement: nil
    )

    init(biais: String, entree: String, stop: String, objectifs: String,
         confirmation: String, invalidation: String, rr: String?, zonesRetournement: String?) {
        self.biais = biais; self.entree = entree; self.stop = stop
        self.objectifs = objectifs; self.confirmation = confirmation
        self.invalidation = invalidation; self.rr = rr; self.zonesRetournement = zonesRetournement
    }
}

// MARK: - Timeframe pour l'analyse multi-UT

enum AnalysisTimeframe: String, CaseIterable, Identifiable {
    case m1 = "M1"
    case m5 = "M5"
    case m15 = "M15"
    case m30 = "M30"
    case h1 = "H1"
    case h4 = "H4"
    case daily = "Daily"
    case threeDay = "3D"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var icon: String {
        switch self {
        case .m1, .m5: return "clock"
        case .m15, .m30: return "clock.badge"
        case .h1, .h4: return "clock.arrow.circlepath"
        case .daily: return "calendar.day.timeline.left"
        case .threeDay, .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .m1: return 0
        case .m5: return 1
        case .m15: return 2
        case .m30: return 3
        case .h1: return 4
        case .h4: return 5
        case .daily: return 6
        case .threeDay: return 7
        case .weekly: return 8
        case .monthly: return 9
        }
    }
}

/// Image associée à une unité de temps
struct TimeframeImage: Identifiable {
    let id = UUID()
    let timeframe: AnalysisTimeframe
    let image: UIImage
}
