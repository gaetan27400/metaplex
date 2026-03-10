import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var progression: Progression?
    @State private var showingPurchase = false
    @State private var isPurchasing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header avec anneau XP
                    PaywallHeaderView(progression: progression)
                    
                    // Bénéfices Pro
                    ProBenefitsView()
                    
                    // Estimation de déverrouillage
                    UnlockEstimateView(progression: progression)
                    
                    // Boutons d'action
                    ActionButtonsView(
                        showingPurchase: $showingPurchase,
                        isPurchasing: $isPurchasing
                    )
                    
                    // Conditions et restauration
                    FooterLinksView()
                }
                .padding()
            }
            .background(Color.surface1.ignoresSafeArea())
            .navigationTitle(t("proPlan"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadProgression()
            }
        }
    }
    
    private func loadProgression() {
        Task {
            do {
                let progression = try await appState.prestigeEngine.getProgression()
                await MainActor.run {
                    self.progression = progression
                }
            } catch {
                print("Erreur lors du chargement de la progression: \(error)")
            }
        }
    }
}

// MARK: - Header avec anneau XP
struct PaywallHeaderView: View {
    let progression: Progression?
    
    var body: some View {
        VStack(spacing: 16) {
            // Anneau XP principal
            ZStack {
                Circle()
                    .fill(Color.surface2)
                    .frame(width: 120, height: 120)
                
                if let progression = progression {
                    XPProgressRing(progress: Double(progression.xpInLevel) / Double(progression.xpRequiredForNextLevel))
                        .frame(width: 128, height: 128)
                }
                
                VStack(spacing: 4) {
                    if let progression = progression {
                        Text("Niveau \(progression.level)")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        if progression.prestige > 0 {
                            Text("Prestige \(progression.prestige)")
                                .font(.caption)
                                .foregroundColor(.tradingBlue)
                        }
                    }
                }
            }
            
            Text(t("dbloquezToutLePotentiel"))
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(t("passezAuNiveauSuprieurAvecLePassPro"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.surface2)
        .cornerRadius(20)
    }
}

// MARK: - Bénéfices Pro
struct ProBenefitsView: View {
    let benefits = [
        ProBenefit(
            icon: "bolt.fill",
            title: "Déverrouillage instantané",
            description: "Accédez immédiatement à toutes les fonctionnalités avancées"
        ),
        ProBenefit(
            icon: "star.fill",
            title: "+30% XP Boost",
            description: "Gagnez 30% d'XP supplémentaire sur tous les événements de processus"
        ),
        ProBenefit(
            icon: "arrow.clockwise",
            title: "+2 Rerolls quotidiens",
            description: "3 rerolls par jour au lieu d'1 pour personnaliser vos défis"
        ),
        ProBenefit(
            icon: "crown.fill",
            title: "Thèmes Prestige",
            description: "Débloquez des thèmes exclusifs et des cosmétiques"
        ),
        ProBenefit(
            icon: "chart.line.uptrend.xyaxis",
            title: "Analyses avancées",
            description: "Statistiques détaillées et insights de performance"
        ),
        ProBenefit(
            icon: "bell.badge.fill",
            title: "Alertes TradingView",
            description: "Intégration complète avec notifications push"
        )
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("inclusDansLePassPro"))
                .font(.title3)
                .fontWeight(.bold)
            
            LazyVStack(spacing: 12) {
                ForEach(benefits) { benefit in
                    ProBenefitRow(benefit: benefit)
                }
            }
        }
        .padding()
        .background(Color.surface2)
        .cornerRadius(16)
    }
}

struct ProBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

struct ProBenefitRow: View {
    let benefit: ProBenefit
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: benefit.icon)
                .font(.title3)
                .foregroundColor(.tradingBlue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(benefit.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(benefit.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.tradingGreen)
        }
    }
}

// MARK: - Estimation de déverrouillage
struct UnlockEstimateView: View {
    let progression: Progression?
    
    var timeToUnlock: String {
        guard let progression = progression else { return "Calcul en cours..." }
        
        // Calculer l'XP nécessaire pour atteindre le niveau 12 (première fonctionnalité avancée)
        let targetLevel = 12
        let currentLevel = progression.level
        
        if currentLevel >= targetLevel {
            return "Fonctionnalités déjà débloquées !"
        }
        
        let xpNeeded = calculateXPForLevels(from: currentLevel, to: targetLevel)
        
        // Estimation basée sur 50 XP par jour (défis + processus)
        let daysToUnlock = max(1, xpNeeded / 50)
        
        if daysToUnlock == 1 {
            return "Débloquez dans ~1 jour"
        } else if daysToUnlock < 7 {
            return "Débloquez dans ~\(daysToUnlock) jours"
        } else {
            let weeks = daysToUnlock / 7
            return "Débloquez dans ~\(weeks) semaine\(weeks > 1 ? "s" : "")"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(t("yes"))
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
            }
            
            Text(timeToUnlock)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.tradingBlue)
            
            Text(t("ouDbloquezInstantanmentAvecLePassPro"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.surface2)
        .cornerRadius(16)
    }
    
    private func calculateXPForLevels(from startLevel: Int, to endLevel: Int) -> Int {
        var totalXP = 0
        for level in startLevel..<endLevel {
            totalXP += max(100, 100 + (level - 1) * 20)
        }
        return totalXP
    }
}

// MARK: - Boutons d'action
struct ActionButtonsView: View {
    @Binding var showingPurchase: Bool
    @Binding var isPurchasing: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Bouton principal - Abonnement
            Button(action: {
                showingPurchase = true
            }) {
                HStack(spacing: 12) {
                    if isPurchasing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "crown.fill")
                    }
                    
                    Text(t("essayerProGratuit"))
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.tradingBlue, .tradingGreen],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .disabled(isPurchasing)
            
            // Bouton secondaire - Restaurer
            Button(action: {
                restorePurchases()
            }) {
                Text(t("restaurerLesAchats"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.tradingBlue)
            }
            .disabled(isPurchasing)
            
            // Prix et conditions
            VStack(spacing: 4) {
                Text(t("499moisAnnulationToutMoment"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(t("ai"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.tradingGreen)
            }
        }
    }
    
    private func restorePurchases() {
        // TODO: Implémenter la restauration des achats StoreKit 2
        print("Restauration des achats...")
    }
}

// MARK: - Liens du footer
struct FooterLinksView: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                Button("Conditions d'utilisation") {
                    // Ouvrir les conditions
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button("Politique de confidentialité") {
                    // Ouvrir la politique
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button("Support") {
                    // Ouvrir le support
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Text(t("account"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(AppState())
}
