import Foundation

enum AssistantAISectionType: String, Codable, CaseIterable {
    case summary
    case market
    case discipline
    case emotion
    case performance
    case photo
}

enum AssistantTrendBias: String, Codable, Equatable {
    case bullish
    case bearish
    case neutral
}

struct AssistantAIIndicatorSnapshot: Identifiable, Codable, Equatable {
    let id = UUID()
    let timeframe: String
    let rsi: Int
    let macd: Double
    let trix: Double
    let vmc: Double
    let odp: Double
    let bias: AssistantTrendBias
    
    // Évite l'avertissement Codable: `id` est un identifiant UI, pas une donnée métier persistée.
    enum CodingKeys: String, CodingKey {
        case timeframe, rsi, macd, trix, vmc, odp, bias
    }
}

struct AssistantAISection: Identifiable, Codable, Equatable {
    let id: UUID
    let type: AssistantAISectionType
    let title: String
    let icon: String
    let message: String
    let accentColorHex: String
    
    init(
        id: UUID = UUID(),
        type: AssistantAISectionType,
        title: String,
        icon: String,
        message: String,
        accentColorHex: String
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.icon = icon
        self.message = message
        self.accentColorHex = accentColorHex
    }
}

struct AssistantAIReport: Codable, Equatable {
    let generatedAt: Date
    let sections: [AssistantAISection]
    let summaryHeadline: String
    let trendRecommendation: String
    let marketConfluence: String
    let fundingRate: Double
    let technicalSummary: String
    let riskScore: Int
    let emotionScore: Int
    let recommendations: [String]
    let indicatorSnapshots: [AssistantAIIndicatorSnapshot]
    
    static var placeholder: AssistantAIReport {
        AssistantAIReport(
            generatedAt: Date(),
            sections: [
                AssistantAISection(
                    type: .summary,
                    title: "Résumé du jour",
                    icon: "sparkles",
                    message: "L’Assistant IA est prêt à générer un résumé dès que des données seront disponibles.",
                    accentColorHex: "#0A85FF"
                )
            ],
            summaryHeadline: "Assistant IA prêt",
            trendRecommendation: "Aucune recommandation disponible",
            marketConfluence: "Confluence neutre",
            fundingRate: 0.0,
            technicalSummary: "",
            riskScore: 50,
            emotionScore: 50,
            recommendations: [],
            indicatorSnapshots: []
        )
    }
}


