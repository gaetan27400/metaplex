import SwiftUI

struct ChallengesHomeView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: ChallengeTab = .daily
    @State private var dailyChallenges: [Challenge] = []
    @State private var weeklyChallenges: [Challenge] = []
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum ChallengeTab: String, CaseIterable {
        case daily = "Quotidien"
        case weekly = "Hebdomadaire"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header avec XP et rerolls
                ChallengesHeaderView()
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                
                // Sélecteur d'onglets
                ChallengeTabPicker(selectedTab: $selectedTab)
                    .padding(.horizontal)
                
                // Contenu des défis
                if isLoading {
                    ProgressView("Chargement des défis...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TabView(selection: $selectedTab) {
                        DailyChallengesView(challenges: dailyChallenges) {
                            Task { await loadDailyChallenges() }
                        }
                        .tag(ChallengeTab.daily)
                        
                        WeeklyChallengesView(challenges: weeklyChallenges) {
                            Task { await loadWeeklyChallenges() }
                        }
                        .tag(ChallengeTab.weekly)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
            .background(Color.surface1.ignoresSafeArea())
            .navigationTitle(t("challenges"))
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadChallenges()
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadChallenges() {
        Task {
            await loadDailyChallenges()
            await loadWeeklyChallenges()
        }
    }
    
    @MainActor
    private func loadDailyChallenges() async {
        isLoading = true
        do {
            dailyChallenges = try await appState.challengeEngine.getDailyChallenges()
            if dailyChallenges.isEmpty {
                // Générer de nouveaux défis quotidiens
                dailyChallenges = try await appState.challengeEngine.rollDaily()
            }
        } catch {
            errorMessage = "Erreur lors du chargement des défis quotidiens: \(error.localizedDescription)"
            showingError = true
        }
        isLoading = false
    }
    
    @MainActor
    private func loadWeeklyChallenges() async {
        isLoading = true
        do {
            weeklyChallenges = try await appState.challengeEngine.getWeeklyChallenges()
            if weeklyChallenges.isEmpty {
                // Générer de nouveaux défis hebdomadaires
                weeklyChallenges = try await appState.challengeEngine.rollWeekly()
            }
        } catch {
            errorMessage = "Erreur lors du chargement des défis hebdomadaires: \(error.localizedDescription)"
            showingError = true
        }
        isLoading = false
    }
}

// MARK: - Header des défis
struct ChallengesHeaderView: View {
    @EnvironmentObject private var appState: AppState
    @State private var progression: Progression?
    @State private var todayRerolls = 0
    
    var body: some View {
        VStack(spacing: 16) {
            // Anneau XP et infos
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.surface2)
                        .frame(width: 60, height: 60)
                    
                    if let progression = progression {
                        XPProgressRing(progress: Double(progression.xpInLevel) / Double(progression.xpRequiredForNextLevel))
                            .frame(width: 68, height: 68)
                    }
                    
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundColor(.tradingBlue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(t("dfisActifs"))
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if progression?.prestige ?? 0 > 0 {
                            Text("Prestige \(progression?.prestige ?? 0)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.tradingBlue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    
                    if let progression = progression {
                        Text("Niveau \(progression.level)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    
                        Text("\(progression.xpInLevel)/\(progression.xpRequiredForNextLevel) XP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Rerolls disponibles
                VStack(spacing: 4) {
                    Text(t("today"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.tradingGreen)
                    
                    Text(t("rerolls"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.surface2)
                .cornerRadius(12)
            }
            
            // Actions rapides
            HStack(spacing: 12) {
                ChallengesQuickActionButton(
                    title: "Nouveaux Défis",
                    icon: "arrow.clockwise",
                    color: .tradingBlue
                ) {
                    // Générer de nouveaux défis
                }
                
                ChallengesQuickActionButton(
                    title: "Historique",
                    icon: "clock.arrow.circlepath",
                    color: .secondary
                ) {
                    // Voir l'historique
                }
            }
        }
        .padding()
        .background(Color.surface2)
        .cornerRadius(16)
        .onAppear {
            loadProgression()
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

// MARK: - Sélecteur d'onglets
struct ChallengeTabPicker: View {
    @Binding var selectedTab: ChallengesHomeView.ChallengeTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(ChallengesHomeView.ChallengeTab.allCases, id: \.self) { tab in
                Button(action: {
                    Haptics.tap()
                    selectedTab = tab
                }) {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTab == tab ? Color.tradingBlue : Color.clear)
                        )
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Vue des défis quotidiens
struct DailyChallengesView: View {
    let challenges: [Challenge]
    let onRefresh: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if challenges.isEmpty {
                    EmptyChallengesView(
                        title: "Aucun défi quotidien",
                        subtitle: "Les défis quotidiens se renouvellent à 06h00",
                        icon: "sun.max"
                    ) {
                        onRefresh()
                    }
                } else {
                    ForEach(challenges) { challenge in
                        ChallengeCard(challenge: challenge)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Vue des défis hebdomadaires
struct WeeklyChallengesView: View {
    let challenges: [Challenge]
    let onRefresh: () -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if challenges.isEmpty {
                    EmptyChallengesView(
                        title: "Aucun défi hebdomadaire",
                        subtitle: "Les défis hebdomadaires se renouvellent le lundi à 06h00",
                        icon: "calendar"
                    ) {
                        onRefresh()
                    }
                } else {
                    ForEach(challenges) { challenge in
                        ChallengeCard(challenge: challenge)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Carte de défi
struct ChallengeCard: View {
    @EnvironmentObject private var appState: AppState
    let challenge: Challenge
    @State private var isCompleting = false
    
    var progressPercentage: Double {
        guard challenge.targetValue > 0 else { return 0 }
        return Double(challenge.currentValue) / Double(challenge.targetValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header du défi
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Récompense XP
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.tradingBlue)
                    Text("\(challenge.rewardXP) XP")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.tradingBlue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Barre de progression
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(t("progression"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(challenge.currentValue)/\(challenge.targetValue)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.tradingBlue)
                }
                
                ProgressView(value: progressPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: .tradingBlue))
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
            
            // Mutateurs
            if !challenge.mutators.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(challenge.mutators, id: \.self) { mutator in
                            Text(mutator.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .foregroundColor(.orange)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Actions
            HStack(spacing: 12) {
                if !challenge.isCompleted {
                    Button(action: {
                        completeChallenge()
                    }) {
                        HStack(spacing: 6) {
                            if isCompleting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(t("tuesday"))
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.tradingGreen)
                        .cornerRadius(20)
                    }
                    .disabled(isCompleting || challenge.currentValue < challenge.targetValue)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.tradingGreen)
                        Text(t("termin"))
                            .fontWeight(.medium)
                            .foregroundColor(.tradingGreen)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    rerollChallenge()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text(t("reroll"))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.surface3)
                    .cornerRadius(16)
                }
            }
            
            // Date d'expiration
            Text(t("saturday"))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.surface2)
        .cornerRadius(16)
    }
    
    private func completeChallenge() {
        guard !challenge.isCompleted else { return }
        
        isCompleting = true
        Task {
            do {
                _ = try await appState.challengeEngine.complete(challengeId: challenge.id)
                await MainActor.run {
                    isCompleting = false
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    isCompleting = false
                    Haptics.warning()
                    print("Erreur lors de la completion du défi: \(error)")
                }
            }
        }
    }
    
    private func rerollChallenge() {
        Task {
            do {
                _ = try await appState.challengeEngine.reroll(challengeId: challenge.id)
                await MainActor.run {
                    Haptics.success()
                }
            } catch {
                await MainActor.run {
                    Haptics.warning()
                    print("Erreur lors du reroll: \(error)")
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - Vue vide
struct EmptyChallengesView: View {
    let title: String
    let subtitle: String
    let icon: String
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onRefresh) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text(t("add"))
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.tradingBlue)
                .cornerRadius(25)
            }
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Bouton d'action rapide (Challenges scope)
struct ChallengesQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            Haptics.tap()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.surface3)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ChallengesHomeView()
        .environmentObject(AppState())
}
