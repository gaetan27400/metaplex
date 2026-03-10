import SwiftUI
import Charts

struct EmotionalAnalysisView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let analysis: EmotionalAnalysis
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header avec émotion dominante
                    dominantEmotionCard
                    
                    // Métriques clés
                    metricsGrid
                    
                    // Corrélation performance
                    performanceCorrelationCard
                    
                    // Insights
                    insightsSection
                    
                    // Recommandations
                    recommendationsSection
                }
                .padding()
            }
            .navigationTitle(t("emotionalAnalysis"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Carte Émotion Dominante
    private var dominantEmotionCard: some View {
        VStack(spacing: 16) {
            Text(t("motionDominante"))
                .font(.headline)
            
            HStack {
                Text(analysis.dominantEmotion.emoji)
                    .font(.system(size: 60))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(analysis.dominantEmotion.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: analysis.dominantEmotion.color))
                    
                    Text("Intensité moyenne: \(String(format: "%.1f", analysis.averageIntensity))/10")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Volatilité: \(String(format: "%.1f", analysis.emotionalVolatility))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(hex: analysis.dominantEmotion.color).opacity(0.1))
        .cornerRadius(16)
    }
    
    // MARK: - Grille de Métriques
    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("mtriquesCls"))
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                MetricCard(
                    title: "Intensité Moyenne",
                    value: String(format: "%.1f", analysis.averageIntensity),
                    subtitle: "/10",
                    color: .blue
                )
                
                MetricCard(
                    title: "Volatilité",
                    value: String(format: "%.1f", analysis.emotionalVolatility),
                    subtitle: "Écart-type",
                    color: .orange
                )
                
                MetricCard(
                    title: "Corrélation Performance",
                    value: String(format: "%.2f", analysis.correlationWithPerformance),
                    subtitle: analysis.correlationWithPerformance > 0 ? "Positive" : "Négative",
                    color: analysis.correlationWithPerformance > 0 ? .green : .red
                )
                
                MetricCard(
                    title: "Période",
                    value: "\(Int(analysis.period.duration / 86400))",
                    subtitle: "jours",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Carte Corrélation Performance
    private var performanceCorrelationCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("impactSurLaPerformance"))
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("corrlationmotionperformance"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(correlationDescription)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Indicateur visuel
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: abs(analysis.correlationWithPerformance))
                        .stroke(
                            analysis.correlationWithPerformance > 0 ? Color.green : Color.red,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                    
                    Text(String(format: "%.0f", abs(analysis.correlationWithPerformance) * 100))
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Section Insights
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("insights"))
                .font(.headline)
            
            if analysis.insights.isEmpty {
                Text(t("aucunInsightDisponiblePourCettePriode"))
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(analysis.insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            Text(insight)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Section Recommandations
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("recommandations"))
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(generateRecommendations(), id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text(recommendation)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    private var correlationDescription: String {
        let correlation = analysis.correlationWithPerformance
        
        if correlation > 0.5 {
            return "Tes émotions influencent positivement tes performances. Continue à cultiver cet état d'esprit !"
        } else if correlation > 0.2 {
            return "Légère corrélation positive entre tes émotions et tes performances."
        } else if correlation > -0.2 {
            return "Tes émotions n'ont pas d'impact significatif sur tes performances."
        } else if correlation > -0.5 {
            return "Tes émotions affectent légèrement tes performances. Travaille sur la gestion émotionnelle."
        } else {
            return "Attention ! Tes émotions impactent négativement tes performances. Il est temps de travailler sur la discipline émotionnelle."
        }
    }
    
    // MARK: - Helper Methods
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        
        // Recommandations basées sur l'émotion dominante
        switch analysis.dominantEmotion {
        case .stressed, .fearful:
            recommendations.append("Pratique la méditation ou des exercices de respiration avant de trader")
            recommendations.append("Évite de trader quand tu te sens stressé - prends une pause")
        case .greedy:
            recommendations.append("Définis des objectifs de profit clairs et respecte-les")
            recommendations.append("Utilise des stop-loss stricts pour éviter les pertes importantes")
        case .frustrated:
            recommendations.append("Après une perte, prends le temps de faire le point avant de retrader")
            recommendations.append("Analyse tes erreurs sans jugement pour progresser")
        case .confident:
            recommendations.append("Continue à cultiver cette confiance, mais reste humble")
            recommendations.append("Profite de cette période positive pour tester de nouvelles stratégies")
        default:
            break
        }
        
        // Recommandations basées sur la volatilité
        if analysis.emotionalVolatility > 3 {
            recommendations.append("Ta volatilité émotionnelle est élevée - travaille sur la stabilité")
            recommendations.append("Considère réduire la taille de tes positions pour diminuer le stress")
        }
        
        // Recommandations basées sur la corrélation
        if analysis.correlationWithPerformance < -0.3 {
            recommendations.append("Travaille sur la gestion émotionnelle - tes émotions affectent tes résultats")
            recommendations.append("Considère un coaching ou des techniques de relaxation")
        }
        
        return recommendations
    }
}


#Preview {
    EmotionalAnalysisView(analysis: EmotionalAnalysis(
        period: DateInterval(start: Date().addingTimeInterval(-86400 * 30), end: Date()),
        dominantEmotion: .confident,
        averageIntensity: 7.2,
        emotionalVolatility: 2.1,
        correlationWithPerformance: 0.4,
        insights: [
            "Tu es dans une zone de confiance optimale",
            "Tes émotions influencent positivement tes performances"
        ]
    ))
}
