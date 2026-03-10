import SwiftUI
import Charts
import UIKit

// Import du modèle SocialPlatform depuis SocialVerification
// Note: SocialPlatform est défini dans Models/Domain/SocialVerification.swift

struct ProfileView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject private var appState: AppState
    @State private var toast: ToastData?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // ✅ Rôle unique: Identité & compte (les sections Progression/Défis/Badges seront dans Mission)
                    ProfileHeaderView(toast: $toast)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)
                }
                // `TradingJournalApp` gère l’espace de la bottom bar via `safeAreaInset`.
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toast($toast)
            .navigationTitle(t("profile"))
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Header du Profil
struct ProfileHeaderView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var toast: ToastData?
    @StateObject private var profileViewModel = ProfileViewModel()
    
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Avatar + identité (strict)
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(AppColors.cardBackground)
                        .frame(width: 88, height: 88)
                    // Avatar placeholder (photo de profil pourra être branchée ici)
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.primary)
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(appState.authManager.currentUser?.displayName ?? "Trader")
                        .font(AppTypography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    Text(t("account"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            // ✅ Bloc UID Firebase + TradingView (distinct, sous la photo)
            profileIdentityBlock
            accountSection
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 2)
        .task {
            // Hydratation Firestore : users/{uid}
            await profileViewModel.fetchUser()
        }
    }

    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Divider().overlay(AppColors.border.opacity(0.25))
            
            if appState.authManager.isAuthenticated, let user = appState.authManager.currentUser {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.email)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            
                            HStack(spacing: 6) {
                                Image(systemName: user.isEmailVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(user.isEmailVerified ? .green : .orange)
                                Text(user.isEmailVerified ? "Email vérifié" : "Email non vérifié")
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        
                        Spacer()
                    }
                    
                    HStack(spacing: AppSpacing.sm) {
                        if !user.isEmailVerified {
                            Button {
                                HapticFeedback.selection()
                                Task {
                                    do {
                                        try await appState.authManager.sendEmailVerification()
                                        toast = ToastData(message: "Email de vérification envoyé", type: .success, duration: 1.8)
                                    } catch {
                                        toast = ToastData(message: "Impossible d'envoyer l'email", type: .error, duration: 2.0)
                                    }
                                }
                            } label: {
                                Label("Vérifier email", systemImage: "envelope.badge")
                                    .font(AppTypography.captionMedium)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            HapticFeedback.selection()
                            Task { await appState.authManager.signOut() }
                        } label: {
                            Label("Déconnexion", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(AppTypography.captionMedium)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text(t("account"))
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.top, AppSpacing.xs)
    }

    @ViewBuilder
    private var profileIdentityBlock: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // UID Firebase
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(t("uidFirebase"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(profileViewModel.uid ?? "—")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                
                Spacer()
                
                Button {
                    HapticFeedback.selection()
                    if let uid = profileViewModel.uid, !uid.isEmpty {
                        UIPasteboard.general.string = uid
                        toast = ToastData(message: "UID copié", type: .success, duration: 1.4)
                    } else {
                        toast = ToastData(message: "Aucun UID à copier", type: .warning, duration: 1.6)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(AppColors.cardBackground.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                                )
                        )
                }
                .accessibilityLabel("Copier l'UID Firebase")
            }
            
            Divider()
                .overlay(AppColors.border.opacity(0.25))
            
            // TradingView username
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    Text(t("name"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    if profileViewModel.isSaving {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else if profileViewModel.didSaveTradingViewUsername {
                        // ✅ Exigence: coche verte UNIQUEMENT si l'enregistrement a réussi
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .accessibilityLabel("Enregistré")
                    }
                }
                
                HStack(spacing: AppSpacing.sm) {
                    TextField("ex: monPseudoTV", text: $profileViewModel.tradingViewUsernameDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(AppColors.background.opacity(0.35))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                        .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                                )
                        )
                        .onChange(of: profileViewModel.tradingViewUsernameDraft) { _, _ in
                            profileViewModel.onDraftChanged()
                        }
                    
                    Button {
                        HapticFeedback.selection()
                        Task {
                            await profileViewModel.saveTradingViewUsername()
                            if profileViewModel.didSaveTradingViewUsername {
                                toast = ToastData(message: "TradingView enregistré", type: .success, duration: 1.6)
                            } else if let error = profileViewModel.errorMessage {
                                toast = ToastData(message: error, type: .error, duration: 2.2)
                            }
                        }
                    } label: {
                        Text(t("save"))
                    }
                    .buttonStyle(.appButton(variant: .outline, size: .small))
                    .disabled(profileViewModel.isSaving || profileViewModel.isLoading)
                }
                
                if let error = profileViewModel.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.error)
                } else if !profileViewModel.tradingViewUsername.isEmpty {
                    Text(t("profile"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.background.opacity(0.25))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - Anneau XP
struct XPProgressRing: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.border.opacity(0.3), lineWidth: 6)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    AppGradients.primary,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
    }
}

// MARK: - Sélecteur d'onglets (Mission)
struct MissionTabPicker: View {
    @Binding var selectedTab: MissionView.MissionTab
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(MissionView.MissionTab.allCases, id: \.self) { tab in
                    Button(action: {
                        HapticFeedback.selection()
                        withAnimation(AppAnimations.quick) {
                        selectedTab = tab
                        }
                    }) {
                        Text(tab.rawValue)
                            .font(AppTypography.labelMedium)
                            .fontWeight(.medium)
                            .foregroundColor(selectedTab == tab ? AppColors.textPrimary : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? AppColors.primary : Color.clear)
                            )
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xs)
        }
    }
}

// MARK: - Onglet Aperçu
struct ProfileOverviewTab: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedTab: MissionView.MissionTab
    @State private var progression: Progression?
    @State private var recentBadges: [Badge] = []
    @State private var todayXP: Int = 0
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                // Statistiques rapides
                QuickStatsView(progression: progression, todayXP: todayXP)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
                
                // Badges récents
                if !recentBadges.isEmpty {
                    RecentBadgesView(badges: recentBadges)
                        .padding(.horizontal, AppSpacing.lg)
                }
                
                // Actions rapides
                QuickActionsView(selectedTab: $selectedTab)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
            }
        }
        .background(AppColors.background)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        Task {
            do {
                let progression = try await appState.prestigeStore?.getProgression()
                let badges = try await appState.prestigeStore?.getRecentBadges(limit: 3) ?? []
                
                await MainActor.run {
                    self.progression = progression
                    self.recentBadges = badges
                    self.todayXP = progression?.dailyXP ?? 0
                    self.isLoading = false
                }
            } catch {
                print("Erreur lors du chargement des données: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Statistiques rapides
struct QuickStatsView: View {
    let progression: Progression?
    let todayXP: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("statistiquesDuJour"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            HStack(spacing: AppSpacing.md) {
                ProfileStatCard(
                    title: "XP Aujourd'hui",
                    value: "\(todayXP)",
                    icon: "star.fill",
                    color: AppColors.primary
                )
                
                ProfileStatCard(
                    title: "Niveau",
                    value: "\(progression?.level ?? 1)",
                    icon: "arrow.up.circle.fill",
                    color: AppColors.success
                )
                
                ProfileStatCard(
                    title: "Prestige",
                    value: "\(progression?.prestige ?? 0)",
                    icon: "crown.fill",
                    color: AppColors.warning
                )
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
}

struct ProfileStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(AppTypography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(title)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.background)
        )
    }
}

// MARK: - Badges récents
struct RecentBadgesView: View {
    let badges: [Badge]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("badgesRcents"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(badges) { badge in
                        BadgeCard(badge: badge)
                    }
                }
                .padding(.horizontal, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
}

struct BadgeCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack {
                Circle()
                    .fill(badgeRarityColor(badge.rarity).opacity(0.2))
                    .frame(width: 64, height: 64)
                
            Image(systemName: badge.icon)
                    .font(.system(size: 28))
                    .foregroundColor(badgeRarityColor(badge.rarity))
            }
            
            Text(badge.name)
                .font(AppTypography.captionMedium)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 80)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.background)
        )
    }
    
    private func badgeRarityColor(_ rarity: BadgeRarity) -> Color {
        switch rarity {
        case .common: return AppColors.textSecondary
        case .rare: return AppColors.primary
        case .epic: return AppColors.accent
        case .legendary: return AppColors.warning
        }
    }
}

// MARK: - Actions rapides
struct QuickActionsView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedTab: MissionView.MissionTab
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("actionsRapides"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                QuickActionButton(
                    title: "Voir ma progression",
                    subtitle: "Niveau, XP, prestige",
                    icon: "bolt.fill",
                    color: AppColors.primary
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = .progression
                    }
                }
                
                QuickActionButton(
                    title: "Voir mes défis",
                    subtitle: "Défis quotidiens et hebdomadaires",
                    icon: "target",
                    color: AppColors.success
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = .challenges
                    }
                }
                
                QuickActionButton(
                    title: "Badges",
                    subtitle: "Collection complète",
                    icon: "medal.fill",
                    color: AppColors.warning
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = .badges
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticFeedback.selection()
            action()
        }) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(subtitle)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.background)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Onglet Progression
struct ProfileProgressionTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var progression: Progression?
    @State private var xpEvents: [XPEvent] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                if isLoading {
                    ProgressView()
                        .padding(.top, AppSpacing.xxl)
                } else if let progression = progression {
                    // Graphique XP sur 7 jours
                    XPHistoryChart(xpEvents: xpEvents)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)
                    
                    // Détails de progression
                    ProgressionDetailsView(progression: progression)
                        .padding(.horizontal, AppSpacing.lg)
                    
                    // Historique XP récent
                    XPHistoryView(xpEvents: xpEvents)
                        .padding(.horizontal, AppSpacing.lg)
                    
                    // Section Prestige
                    PrestigeInfoCard(progression: progression)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                } else {
                    EmptyProgressionView()
                        .padding(.top, AppSpacing.xxl)
                }
            }
        }
        .background(AppColors.background)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        Task {
            do {
                let progression = try await appState.prestigeStore?.getProgression()
                let events = try await appState.prestigeStore?.getXPEvents(limit: 50) ?? []
                
                await MainActor.run {
                    self.progression = progression
                    self.xpEvents = events
                    self.isLoading = false
                }
            } catch {
                print("Erreur lors du chargement: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct XPHistoryChart: View {
    let xpEvents: [XPEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("volutionXp7Jours"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            if xpEvents.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textTertiary)
                    Text(t("noData"))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            } else {
                Chart {
                    ForEach(groupedXPByDay(xpEvents)) { dayData in
                        LineMark(
                            x: .value("Jour", dayData.day, unit: .day),
                            y: .value("XP", dayData.totalXP)
                        )
                        .foregroundStyle(AppColors.primary)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Jour", dayData.day, unit: .day),
                            yStart: .value("XP", 0),
                            yEnd: .value("XP", dayData.totalXP)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppColors.primary.opacity(0.3), AppColors.primary.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                            .foregroundStyle(AppColors.border.opacity(0.3))
                        AxisValueLabel(format: .dateTime.month().day())
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(AppColors.border.opacity(0.3))
                        AxisValueLabel()
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
    
    private func groupedXPByDay(_ events: [XPEvent]) -> [DayXPData] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let filtered = events.filter { $0.createdAt >= sevenDaysAgo }
        let grouped = Dictionary(grouping: filtered) { event in
            calendar.startOfDay(for: event.createdAt)
        }
        
        return grouped.map { (day, events) in
            DayXPData(day: day, totalXP: events.reduce(0) { $0 + $1.amount })
        }.sorted { $0.day < $1.day }
    }
}

struct DayXPData: Identifiable {
    let id = UUID()
    let day: Date
    let totalXP: Int
}

struct ProgressionDetailsView: View {
    let progression: Progression
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("ai"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                ProgressionDetailRow(
                    icon: "star.fill",
                    title: "XP Total",
                    value: "\(progression.totalXP)",
                    color: AppColors.primary
                )
                
                ProgressionDetailRow(
                    icon: "arrow.up.circle.fill",
                    title: "Niveau actuel",
                    value: "\(progression.level) / \(Progression.maxLevel)",
                    color: AppColors.success
                )
                
                ProgressionDetailRow(
                    icon: "crown.fill",
                    title: "Prestige",
                    value: "\(progression.prestige)",
                    color: AppColors.warning
                )
                
                if let lastPrestige = progression.lastPrestigeDate {
                    ProgressionDetailRow(
                        icon: "calendar",
                        title: "Dernier prestige",
                        value: lastPrestige.formatted(date: .abbreviated, time: .omitted),
                        color: AppColors.textSecondary
                    )
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
}

struct ProgressionDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

struct XPHistoryView: View {
    let xpEvents: [XPEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("historiqueXpRcent"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            if xpEvents.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.textTertiary)
                    Text(t("aucunvnementXp"))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xl)
            } else {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(xpEvents.prefix(10)) { event in
                        XPEventRow(event: event)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
}

struct XPEventRow: View {
    let event: XPEvent
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: iconForEventType(event.type))
                .font(.system(size: 16))
                .foregroundColor(AppColors.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(event.description)
                    .font(AppTypography.bodySmall)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(event.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textTertiary)
            }
            
            Spacer()
            
            Text(t("friday"))
                .font(AppTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.success)
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.small)
                .fill(AppColors.background)
        )
    }
    
    private func iconForEventType(_ type: XPEventType) -> String {
        switch type {
        case .checklist: return "checkmark.circle.fill"
        case .postMortem: return "doc.text.fill"
        case .discipline: return "shield.fill"
        case .playbook: return "book.fill"
        case .referral: return "person.2.fill"
        case .social: return "link.circle.fill"
        }
    }
}

struct EmptyProgressionView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 64))
                .foregroundColor(AppColors.textTertiary)
            
            Text(t("aucuneProgression"))
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            Text(t("commencezTraderPourGagnerDeLxp"))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
    }
}

// MARK: - Onglet Défis
struct ProfileChallengesTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var dailyChallenges: [Challenge] = []
    @State private var weeklyChallenges: [Challenge] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                if isLoading {
                    ProgressView()
                        .padding(.top, AppSpacing.xxl)
                } else {
                    // Défis quotidiens
                    if !dailyChallenges.isEmpty {
                        ChallengesSectionView(
                            title: "Défis quotidiens",
                            challenges: dailyChallenges
                        )
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)
                    }
                    
                    // Défis hebdomadaires
                    if !weeklyChallenges.isEmpty {
                        ChallengesSectionView(
                            title: "Défis hebdomadaires",
                            challenges: weeklyChallenges
                        )
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    
                    if dailyChallenges.isEmpty && weeklyChallenges.isEmpty {
                        ProfileEmptyChallengesView()
                            .padding(.top, AppSpacing.xxl)
                    }
                }
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .background(AppColors.background)
        .onAppear {
            loadChallenges()
        }
    }
    
    private func loadChallenges() {
        Task {
            isLoading = true
            do {
                // Charger les défis quotidiens
                var daily = try await appState.challengeEngine.getDailyChallenges()
                // Si aucun défi quotidien, en générer de nouveaux
                if daily.isEmpty {
                    daily = try await appState.challengeEngine.rollDaily()
                }
                
                // Charger les défis hebdomadaires
                var weekly = try await appState.challengeEngine.getWeeklyChallenges()
                // Si aucun défi hebdomadaire, en générer de nouveaux
                if weekly.isEmpty {
                    weekly = try await appState.challengeEngine.rollWeekly()
                }
                
                await MainActor.run {
                    self.dailyChallenges = daily
                    self.weeklyChallenges = weekly
                    self.isLoading = false
                }
            } catch {
                print("Erreur lors du chargement des défis: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct ChallengesSectionView: View {
    let title: String
    let challenges: [Challenge]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title)
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                ForEach(challenges) { challenge in
                    ProfileChallengeCard(challenge: challenge)
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
}

struct ProfileChallengeCard: View {
    let challenge: Challenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(challenge.title)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(challenge.description)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                if challenge.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.success)
                }
            }
            
            // Barre de progression
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text("\(challenge.currentValue)/\(challenge.targetValue)")
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Text("\(challenge.rewardXP) XP")
                        .font(AppTypography.captionMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(AppColors.border.opacity(0.3))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(AppColors.primary)
                            .frame(
                                width: geometry.size.width * CGFloat(challenge.currentValue) / CGFloat(challenge.targetValue),
                                height: 6
                            )
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.background)
        )
    }
}

struct ProfileEmptyChallengesView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "target")
                .font(.system(size: 64))
                .foregroundColor(AppColors.textTertiary)
            
            Text(t("aucunDfiDisponible"))
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            Text(t("ai"))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
    }
}

// MARK: - Carte d'information Prestige
struct PrestigeInfoCard: View {
    let progression: Progression
    @EnvironmentObject private var appState: AppState
    @State private var isPrestiging = false
    @State private var showPrestigeAlert = false
    @State private var prestigeError: String?
    
    var canPrestige: Bool {
        progression.level >= 50 && progression.prestige < 10
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.warning)
                
                Text(t("prestige"))
                    .font(AppTypography.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            if progression.prestige > 0 {
                HStack(spacing: AppSpacing.xs) {
                    Text(t("niveauDePrestige"))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Text("P\(progression.prestige)")
                        .font(AppTypography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.warning)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            Capsule()
                                .fill(AppColors.warning.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(AppColors.warning.opacity(0.5), lineWidth: 1)
                                )
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(t("commentAccderAuPrestige"))
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    PrestigeStepView(
                        number: 1,
                        title: "Atteindre le niveau 50",
                        description: "Gagnez de l'XP en tradant, complétant des défis et utilisant le journal",
                        isCompleted: progression.level >= 50
                    )
                    
                    PrestigeStepView(
                        number: 2,
                        title: "Prestiger",
                        description: "Réinitialisez votre niveau à 1 et gagnez +1 Prestige (max 10)",
                        isCompleted: progression.prestige > 0
                    )
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.background)
            )
            
            if canPrestige {
                Button(action: {
                    showPrestigeAlert = true
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        if isPrestiging {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "star.fill")
                        }
                        
                        Text(isPrestiging ? "Prestige en cours..." : "Prestiger maintenant")
                            .font(AppTypography.labelLarge)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [AppColors.warning, AppColors.warning.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppRadius.medium)
                }
                .disabled(isPrestiging)
            } else if progression.prestige >= 10 {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                    
                    Text(t("prestigeMaximumAtteint"))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.success)
                }
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.success.opacity(0.1))
                )
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(t("progressionVersLePrestige"))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textTertiary)
                    
                    HStack(spacing: AppSpacing.xs) {
                        Text("Niveau \(progression.level)/50")
                            .font(AppTypography.bodySmall)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Spacer()
                        
                        Text("\(50 - progression.level) niveau\(50 - progression.level > 1 ? "s" : "") restant\(50 - progression.level > 1 ? "s" : "")")
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textTertiary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .fill(AppColors.border.opacity(0.3))
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .fill(AppColors.warning)
                                .frame(
                                    width: geometry.size.width * CGFloat(progression.level) / 50.0,
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.cardBackground.opacity(0.5))
                )
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
        .alert("Prestiger", isPresented: $showPrestigeAlert) {
            Button("Annuler", role: .cancel) { }
            Button(t("confirm")) {
                performPrestige()
            }
        } message: {
            Text(t("ai"))
        }
        .alert("Erreur", isPresented: .constant(prestigeError != nil)) {
            Button("OK") {
                prestigeError = nil
            }
        } message: {
            if let error = prestigeError {
                Text(error)
            }
        }
    }
    
    private func performPrestige() {
        isPrestiging = true
        Task {
            do {
                _ = try await appState.prestigeEngine.prestige()
                await MainActor.run {
                    isPrestiging = false
                    HapticFeedback.success()
                }
            } catch {
                await MainActor.run {
                    isPrestiging = false
                    prestigeError = error.localizedDescription
                }
            }
        }
    }
}

struct PrestigeStepView: View {
    let number: Int
    let title: String
    let description: String
    let isCompleted: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(isCompleted ? AppColors.success : AppColors.textTertiary.opacity(0.3))
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text(t("number"))
                        .font(AppTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? AppColors.success : AppColors.textPrimary)
                
                Text(description)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}

// MARK: - Onglet Badges
struct ProfileBadgesTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var unlockedBadges: [Badge] = []
    @State private var allBadges: [Badge] = []
    @State private var selectedRarity: BadgeRarity? = nil
    @State private var isLoading = true
    @State private var selectedBadge: Badge? = nil
    @State private var showingBadgeDetail = false
    
    var filteredBadges: [Badge] {
        let badges = allBadges
        if let rarity = selectedRarity {
            return badges.filter { $0.rarity == rarity }
        }
        return badges
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                // Filtres de rareté
                if !allBadges.isEmpty {
                    BadgeRarityFilter(selectedRarity: $selectedRarity)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.md)
                }
                
                if isLoading {
                    ProgressView()
                        .padding(.top, AppSpacing.xxl)
                } else if allBadges.isEmpty {
                    EmptyBadgesView()
                        .padding(.top, AppSpacing.xxl)
                } else {
                    // Grille de badges
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: AppSpacing.md),
                        GridItem(.flexible(), spacing: AppSpacing.md),
                        GridItem(.flexible(), spacing: AppSpacing.md)
                    ], spacing: AppSpacing.md) {
                        ForEach(filteredBadges) { badge in
                            BadgeGridCard(badge: badge, isUnlocked: unlockedBadges.contains(where: { $0.id == badge.id }))
                                .onTapGesture {
                                    HapticFeedback.selection()
                                    selectedBadge = badge
                                    showingBadgeDetail = true
                                }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
        }
        .background(AppColors.background)
        .sheet(isPresented: $showingBadgeDetail) {
            if let badge = selectedBadge {
                BadgeDetailView(badge: badge, isUnlocked: unlockedBadges.contains(where: { $0.id == badge.id }))
            }
        }
        .onAppear {
            loadBadges()
        }
    }
    
    private func loadBadges() {
        Task {
            do {
                // Charger les badges débloqués
                let unlocked = try await appState.prestigeStore?.getBadges() ?? []
                
                // Créer tous les badges depuis BadgeDefinitions
                let allDefinitions = BadgeDefinitions.all
                var allBadgesList: [Badge] = []
                
                for definition in allDefinitions {
                    // Chercher si ce badge est débloqué
                    if let unlockedBadge = unlocked.first(where: { $0.id == definition.id }) {
                        allBadgesList.append(unlockedBadge)
                    } else {
                        // Créer un badge non débloqué
                        let lockedBadge = Badge(
                            id: definition.id,
                            name: definition.name,
                            description: definition.description,
                            icon: definition.icon,
                            rarity: definition.rarity,
                            unlockedAt: nil,
                            createdAt: Date(),
                            updatedAt: Date()
                        )
                        allBadgesList.append(lockedBadge)
                    }
                }
                
                await MainActor.run {
                    self.unlockedBadges = unlocked
                    self.allBadges = allBadgesList.sorted { badge1, badge2 in
                        // Trier : débloqués d'abord, puis par rareté
                        let unlocked1 = badge1.unlockedAt != nil
                        let unlocked2 = badge2.unlockedAt != nil
                        if unlocked1 != unlocked2 {
                            return unlocked1
                        }
                        return badge1.rarity.rawValue < badge2.rarity.rawValue
                    }
                    self.isLoading = false
                }
            } catch {
                print("Erreur lors du chargement des badges: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct BadgeRarityFilter: View {
    @Binding var selectedRarity: BadgeRarity?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                Button(action: {
                    HapticFeedback.selection()
                    selectedRarity = nil
                }) {
                    Text(t("tous"))
                        .font(AppTypography.labelMedium)
                        .foregroundColor(selectedRarity == nil ? AppColors.textPrimary : AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            Capsule()
                                .fill(selectedRarity == nil ? AppColors.primary : AppColors.background)
                        )
                }
                
                ForEach(BadgeRarity.allCases, id: \.self) { rarity in
                    Button(action: {
                        HapticFeedback.selection()
                        selectedRarity = rarity
                    }) {
                        Text(rarity.rawValue.capitalized)
                            .font(AppTypography.labelMedium)
                            .foregroundColor(selectedRarity == rarity ? AppColors.textPrimary : AppColors.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                Capsule()
                                    .fill(selectedRarity == rarity ? AppColors.primary : AppColors.background)
                            )
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xs)
        }
    }
}

struct BadgeGridCard: View {
    let badge: Badge  // Badge du modèle Progression
    let isUnlocked: Bool
    @EnvironmentObject private var appState: AppState
    
    var isSocialBadge: Bool {
        badge.id.hasPrefix("social_")
    }
    
    var socialPlatform: SocialPlatform? {
        if badge.id == "social_discord" { return .discord }
        if badge.id == "social_twitter" { return .twitter }
        if badge.id == "social_telegram" { return .telegram }
        if badge.id == "social_reddit" { return .reddit }
        if badge.id == "social_youtube" { return .youtube }
        if badge.id == "social_instagram" { return .instagram }
        if badge.id == "social_tiktok" { return .tiktok }
        if badge.id == "social_twitch" { return .twitch }
        return nil
    }
    
    var socialLink: URL? {
        guard let platform = socialPlatform else { return nil }
        // TODO: Remplacer par vos vrais liens
        switch platform {
        case .discord: return URL(string: "https://discord.gg/ygZwgCmadD")
        case .twitter: return URL(string: "https://twitter.com/votre-compte")
        case .telegram: return URL(string: "https://t.me/votre-groupe")
        case .reddit: return URL(string: "https://reddit.com/r/votre-subreddit")
        case .youtube: return URL(string: "https://youtube.com/@votre-chaine")
        case .instagram: return URL(string: "https://instagram.com/votre-compte")
        case .tiktok: return URL(string: "https://tiktok.com/@votre-compte")
        case .twitch: return URL(string: "https://twitch.tv/votre-chaine")
        case .linkedin: return URL(string: "https://linkedin.com/company/votre-entreprise")
        }
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ZStack {
                Circle()
                    .fill(badgeRarityColor(badge.rarity).opacity(isUnlocked ? 0.2 : 0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: badge.icon)
                    .font(.system(size: 36))
                    .foregroundColor(badgeRarityColor(badge.rarity).opacity(isUnlocked ? 1.0 : 0.4))
                
                if !isUnlocked {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Text(badge.name)
                .font(AppTypography.captionMedium)
                .fontWeight(.medium)
                .foregroundColor(isUnlocked ? AppColors.textPrimary : AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Bouton pour les badges sociaux non débloqués
            if isSocialBadge && !isUnlocked, socialLink != nil {
                Button(action: {
                    handleSocialLinkClick(platform: socialPlatform!)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text(t("rejoindre"))
                            .font(AppTypography.captionSmall)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(badgeRarityColor(badge.rarity))
                    )
                }
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(isUnlocked ? badgeRarityColor(badge.rarity).opacity(0.3) : AppColors.border.opacity(0.1), lineWidth: 1)
                )
        )
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
    
    private func handleSocialLinkClick(platform: SocialPlatform) {
        HapticFeedback.selection()
        
        // Marquer le clic dans UserDefaults
        let key = "social_link_clicked_\(platform.rawValue)"
        UserDefaults.standard.set(true, forKey: key)
        
        // Ouvrir le lien
        if let link = socialLink {
            UIApplication.shared.open(link)
        }
        
        // Donner de l'XP et vérifier les badges
        Task {
            // Donner de l'XP pour avoir cliqué sur le lien
            if let prestigeStore = appState.prestigeStore {
                let xpEvent = XPEvent(
                    id: UUID().uuidString,
                    type: .social,
                    amount: 50, // 50 XP pour rejoindre une communauté
                    description: "Rejoint \(platform.displayName)",
                    metadata: ["platform": platform.rawValue, "type": "social_link"],
                    createdAt: Date()
                )
                _ = try? await prestigeStore.createXPEvent(xpEvent)
            }
            
            // Vérifier les badges
            await appState.checkBadges()
        }
    }
    
    private func badgeRarityColor(_ rarity: BadgeRarity) -> Color {
        switch rarity {
        case .common: return AppColors.textSecondary
        case .rare: return AppColors.primary
        case .epic: return AppColors.accent
        case .legendary: return AppColors.warning
        }
    }
}

// MARK: - Vue de détail d'un badge
struct BadgeDetailView: View {
    let badge: Badge
    let isUnlocked: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    var badgeDefinition: BadgeDefinition? {
        BadgeDefinitions.all.first { $0.id == badge.id }
    }
    
    var unlockCriteria: String {
        guard let definition = badgeDefinition else {
            return "Critères non disponibles"
        }
        return formatCriteria(definition.criteria)
    }
    
    var isSocialBadge: Bool {
        badge.id.hasPrefix("social_")
    }
    
    var socialPlatform: SocialPlatform? {
        if badge.id == "social_discord" { return .discord }
        if badge.id == "social_twitter" { return .twitter }
        if badge.id == "social_telegram" { return .telegram }
        if badge.id == "social_reddit" { return .reddit }
        if badge.id == "social_youtube" { return .youtube }
        if badge.id == "social_instagram" { return .instagram }
        if badge.id == "social_tiktok" { return .tiktok }
        if badge.id == "social_twitch" { return .twitch }
        return nil
    }
    
    var socialLink: URL? {
        guard let platform = socialPlatform else { return nil }
        // TODO: Remplacer par vos vrais liens
        switch platform {
        case .discord: return URL(string: "https://discord.gg/ygZwgCmadD")
        case .twitter: return URL(string: "https://twitter.com/votre-compte")
        case .telegram: return URL(string: "https://t.me/votre-groupe")
        case .reddit: return URL(string: "https://reddit.com/r/votre-subreddit")
        case .youtube: return URL(string: "https://youtube.com/@votre-chaine")
        case .instagram: return URL(string: "https://instagram.com/votre-compte")
        case .tiktok: return URL(string: "https://tiktok.com/@votre-compte")
        case .twitch: return URL(string: "https://twitch.tv/votre-chaine")
        case .linkedin: return URL(string: "https://linkedin.com/company/votre-entreprise")
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Icône du badge
                    ZStack {
                        Circle()
                            .fill(badgeRarityColor(badge.rarity).opacity(isUnlocked ? 0.2 : 0.1))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: badge.icon)
                            .font(.system(size: 60))
                            .foregroundColor(badgeRarityColor(badge.rarity).opacity(isUnlocked ? 1.0 : 0.4))
                        
                        if !isUnlocked {
                            Circle()
                                .fill(Color.black.opacity(0.4))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "lock.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.top, AppSpacing.xxl)
                    .opacity(isUnlocked ? 1.0 : 0.6)
                    
                    // Nom et rareté
                    VStack(spacing: AppSpacing.sm) {
                        Text(badge.name)
                            .font(AppTypography.titleLarge)
                            .fontWeight(.bold)
                            .foregroundColor(isUnlocked ? AppColors.textPrimary : AppColors.textTertiary)
                        
                        HStack(spacing: AppSpacing.xs) {
                            Circle()
                                .fill(badgeRarityColor(badge.rarity))
                                .frame(width: 8, height: 8)
                            
                            Text(badge.rarity.rawValue.capitalized)
                                .font(AppTypography.labelMedium)
                                .foregroundColor(badgeRarityColor(badge.rarity))
                        }
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(t("description"))
                            .font(AppTypography.headlineSmall)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(badge.description)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .fill(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.large)
                                    .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // Date de déblocage si débloqué
                    if isUnlocked, let unlockedAt = badge.unlockedAt {
                        VStack(spacing: AppSpacing.xs) {
                            Text(t("dbloquLe"))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textTertiary)
                            
                            Text(unlockedAt, format: .dateTime.day().month().year())
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(badgeRarityColor(badge.rarity).opacity(0.1))
                        )
                    } else {
                        VStack(spacing: AppSpacing.lg) {
                            // Section "Comment débloquer"
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(AppColors.primary)
                                    
                                    Text(t("commentDbloquer"))
                                        .font(AppTypography.headlineSmall)
                                        .foregroundColor(AppColors.textPrimary)
                                }
                                
                                if isSocialBadge, let platform = socialPlatform, socialLink != nil {
                                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                        Text(t("no"))
                                            .font(AppTypography.bodyMedium)
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Button(action: {
                                            handleSocialLinkClick(platform: platform)
                                        }) {
                                            HStack(spacing: AppSpacing.sm) {
                                                Image(systemName: platform.icon)
                                                Text(t("name"))
                                            }
                                            .font(AppTypography.labelLarge)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 50)
                                            .background(
                                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                                    .fill(Color(hex: platform.color))
                                            )
                                        }
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        Text(unlockCriteria)
                                            .font(AppTypography.bodyMedium)
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineSpacing(4)
                                        
                                        if let definition = badgeDefinition {
                                            Text(formatDetailedCriteria(definition.criteria))
                                                .font(AppTypography.captionSmall)
                                                .foregroundColor(AppColors.textTertiary)
                                                .padding(.top, AppSpacing.xs)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .fill(AppColors.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.medium)
                                            .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            
                            // Indicateur de verrouillage
                            VStack(spacing: AppSpacing.sm) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.textTertiary)
                                
                                Text(t("yes"))
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textTertiary)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                }
                .padding(AppSpacing.lg)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("badge"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primary)
                }
            }
        }
    }
    
    private func badgeRarityColor(_ rarity: BadgeRarity) -> Color {
        switch rarity {
        case .common: return AppColors.textSecondary
        case .rare: return AppColors.primary
        case .epic: return AppColors.accent
        case .legendary: return AppColors.warning
        }
    }
    
    // MARK: - Helpers pour formater les critères
    
    private func formatCriteria(_ criteria: BadgeCriteria) -> String {
        switch criteria {
        case .firstTrade:
            return "Effectuer votre premier trade"
        case .firstWin:
            return "Réaliser votre premier trade gagnant"
        case .firstLoss:
            return "Vivre votre première perte"
        case .levelReached(let level):
            return "Atteindre le niveau \(level)"
        case .prestigeReached(let prestige):
            return "Atteindre le prestige \(prestige)"
        case .totalXP(let xp):
            return "Gagner \(xp) XP au total"
        case .totalTrades(let count):
            return "Effectuer \(count) trade\(count > 1 ? "s" : "")"
        case .stopLossRespected(let count):
            return "Respecter le stop-loss sur \(count) trade\(count > 1 ? "s" : "")"
        case .riskRewardRatio(let ratio, let minTrades):
            return "Maintenir un ratio risque/récompense ≥ \(String(format: "%.1f", ratio)) sur \(minTrades) trade\(minTrades > 1 ? "s" : "")"
        case .positionSizing(let count):
            return "Utiliser un position sizing cohérent sur \(count) trade\(count > 1 ? "s" : "")"
        case .maxDrawdown(let percent):
            return "Maintenir un drawdown maximum ≤ \(String(format: "%.1f", percent))%"
        case .tradesInRow(let days):
            return "Trader consécutivement pendant \(days) jour\(days > 1 ? "s" : "")"
        case .journalEntries(let count):
            return "Créer \(count) entrée\(count > 1 ? "s" : "") dans le journal émotionnel"
        case .weeklyConsistency(let weeks):
            return "Trader au moins 1 fois par semaine pendant \(weeks) semaine\(weeks > 1 ? "s" : "")"
        case .monthlyConsistency(let months, let minTrades):
            return "Trader au moins \(minTrades) fois par mois pendant \(months) mois"
        case .postMortems(let count):
            return "Effectuer \(count) post-mortem\(count > 1 ? "s" : "")"
        case .checklists(let count):
            return "Utiliser la checklist \(count) fois"
        case .playbooks(let count):
            return "Créer \(count) playbook\(count > 1 ? "s" : "")"
        case .winRate(let rate, let minTrades):
            return "Maintenir un taux de réussite ≥ \(String(format: "%.0f", rate))% sur \(minTrades) trade\(minTrades > 1 ? "s" : "") minimum"
        case .totalProfit(let profit):
            return "Gagner \(formatCurrency(profit)) de profit total"
        case .bestStreak(let wins):
            return "Enchaîner \(wins) victoire\(wins > 1 ? "s" : "") consécutive\(wins > 1 ? "s" : "")"
        case .systemMastery(let systemName, let count):
            return "Effectuer \(count) trade\(count > 1 ? "s" : "") avec le système \"\(systemName)\""
        case .averageWin(let amount, let minTrades):
            return "Avoir un gain moyen ≥ \(formatCurrency(amount)) sur \(minTrades) trade\(minTrades > 1 ? "s" : "") minimum"
        case .singleTradeProfit(let profit):
            return "Réaliser un profit de \(formatCurrency(profit)) sur un seul trade"
        case .perfectDay(let minTrades):
            return "Avoir \(minTrades) trade\(minTrades > 1 ? "s" : "") gagnant\(minTrades > 1 ? "s" : "") dans une journée"
        case .perfectWeek(let minTrades):
            return "Avoir \(minTrades) trade\(minTrades > 1 ? "s" : "") gagnant\(minTrades > 1 ? "s" : "") dans une semaine"
        case .zeroLossDay(let minTrades):
            return "Avoir \(minTrades) trade\(minTrades > 1 ? "s" : "") sans perte dans une journée"
        case .zeroLossWeek(let minTrades):
            return "Avoir \(minTrades) trade\(minTrades > 1 ? "s" : "") sans perte dans une semaine"
        case .comeback(let losses, let wins):
            return "Enchaîner \(losses) perte\(losses > 1 ? "s" : "") puis \(wins) victoire\(wins > 1 ? "s" : "") consécutive\(wins > 1 ? "s" : "")"
        case .emotionalStability(let days):
            return "Créer des entrées d'humeur pendant \(days) jour\(days > 1 ? "s" : "") consécutif\(days > 1 ? "s" : "")"
        case .recovery(let losses):
            return "Récupérer après \(losses) perte\(losses > 1 ? "s" : "") consécutive\(losses > 1 ? "s" : "")"
        case .challengesCompleted(let count):
            return "Compléter \(count) défi\(count > 1 ? "s" : "")"
        case .dailyChallengesStreak(let days):
            return "Compléter des défis quotidiens pendant \(days) jour\(days > 1 ? "s" : "") consécutif\(days > 1 ? "s" : "")"
        case .weeklyChallengesStreak(let weeks):
            return "Compléter des défis hebdomadaires pendant \(weeks) semaine\(weeks > 1 ? "s" : "") consécutive\(weeks > 1 ? "s" : "")"
        case .multipleSystems(let count):
            return "Utiliser \(count) système\(count > 1 ? "s" : "") de trading différent\(count > 1 ? "s" : "")"
        case .symbolMastery(let symbol, let count):
            return "Effectuer \(count) trade\(count > 1 ? "s" : "") sur \(symbol)"
        case .multipleSymbols(let count):
            return "Trader \(count) symbole\(count > 1 ? "s" : "") différent\(count > 1 ? "s" : "")"
        case .socialLinkClicked(let platform):
            return "Rejoindre notre communauté \(platform.displayName)"
        case .multipleSocialLinks(let count):
            return "Rejoindre \(count) communauté\(count > 1 ? "s" : "")"
        case .referralCount(let count):
            return "Parrainer \(count) utilisateur\(count > 1 ? "s" : "")"
        case .communityContribution(let count):
            return "Contribuer \(count) fois à la communauté"
        }
    }
    
    private func formatDetailedCriteria(_ criteria: BadgeCriteria) -> String {
        switch criteria {
        case .winRate(let rate, let minTrades):
            return "Vous devez avoir au moins \(minTrades) trades et un taux de réussite de \(String(format: "%.0f", rate))% ou plus."
        case .totalProfit(let profit):
            return "Votre profit total cumulé doit atteindre \(formatCurrency(profit))."
        case .bestStreak(let wins):
            return "Vous devez enchaîner \(wins) trades gagnants consécutifs."
        case .tradesInRow(let days):
            return "Vous devez trader au moins une fois par jour pendant \(days) jours consécutifs."
        case .weeklyConsistency(let weeks):
            return "Vous devez trader au moins une fois par semaine pendant \(weeks) semaines consécutives."
        case .monthlyConsistency(let months, let minTrades):
            return "Vous devez trader au moins \(minTrades) fois par mois pendant \(months) mois consécutifs."
        case .stopLossRespected(let count):
            return "Vous devez respecter votre stop-loss sur \(count) trades (basé sur votre P&L)."
        case .riskRewardRatio(let ratio, let minTrades):
            return "Vous devez maintenir un ratio risque/récompense d'au moins \(String(format: "%.1f", ratio)) sur \(minTrades) trades minimum."
        default:
            return ""
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        if amount >= 1000 {
            return String(format: "%.1fK", amount / 1000)
        }
        return String(format: "%.0f", amount)
    }
    
    private func handleSocialLinkClick(platform: SocialPlatform) {
        HapticFeedback.selection()
        
        // Marquer le clic dans UserDefaults
        let key = "social_link_clicked_\(platform.rawValue)"
        UserDefaults.standard.set(true, forKey: key)
        
        // Ouvrir le lien
        if let link = socialLink {
            UIApplication.shared.open(link)
        }
        
        // Donner de l'XP et vérifier les badges
        Task {
            // Donner de l'XP pour avoir cliqué sur le lien
            if let prestigeStore = appState.prestigeStore {
                let xpEvent = XPEvent(
                    id: UUID().uuidString,
                    type: .social,
                    amount: 50, // 50 XP pour rejoindre une communauté
                    description: "Rejoint \(platform.displayName)",
                    metadata: ["platform": platform.rawValue, "type": "social_link"],
                    createdAt: Date()
                )
                _ = try? await prestigeStore.createXPEvent(xpEvent)
            }
            
            // Vérifier les badges
            await appState.checkBadges()
            
            // Fermer la vue et montrer une notification
            await MainActor.run {
                HapticFeedback.success()
                dismiss()
            }
        }
    }
}

struct EmptyBadgesView: View {
    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "medal")
                .font(.system(size: 64))
                .foregroundColor(AppColors.textTertiary)
            
            Text(t("aucunBadge"))
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            Text(t("dbloquezDesBadgesEnCompltantDesDfis"))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
    }
}

// MARK: - Onglet Statistiques
struct ProfileStatsTab: View {
    @EnvironmentObject private var appState: AppState
    @State private var progression: Progression?
    @State private var xpEvents: [XPEvent] = []
    @State private var badges: [Badge] = []
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.lg) {
                if isLoading {
                    ProgressView()
                        .padding(.top, AppSpacing.xxl)
                } else {
                    // Statistiques globales
                    GlobalStatsView(
                        progression: progression,
                        totalXP: xpEvents.reduce(0) { $0 + $1.amount },
                        badgesUnlocked: badges.filter { $0.unlockedAt != nil }.count,
                        totalBadges: badges.count
                    )
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
                    
                    // Statistiques par type d'événement
                    XPByTypeStatsView(xpEvents: xpEvents)
                        .padding(.horizontal, AppSpacing.lg)
                    
                    // Statistiques de badges
                    BadgeStatsView(badges: badges)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                }
            }
        }
        .background(AppColors.background)
        .onAppear {
            loadStats()
        }
    }
    
    private func loadStats() {
        Task {
            do {
                let progression = try await appState.prestigeStore?.getProgression()
                let events = try await appState.prestigeStore?.getXPEvents(limit: 1000) ?? []
                let badges = try await appState.prestigeStore?.getBadges() ?? []
                
                await MainActor.run {
                    self.progression = progression
                    self.xpEvents = events
                    self.badges = badges
                    self.isLoading = false
                }
            } catch {
                print("Erreur lors du chargement: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct GlobalStatsView: View {
    let progression: Progression?
    let totalXP: Int
    let badgesUnlocked: Int
    let totalBadges: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("statistiquesGlobales"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                StatRow(
                    icon: "star.fill",
                    title: "XP Total gagné",
                    value: "\(totalXP)",
                    color: AppColors.primary
                )
                
                StatRow(
                    icon: "arrow.up.circle.fill",
                    title: "Niveau maximum atteint",
                    value: "\(progression?.level ?? 1)",
                    color: AppColors.success
                )
                
                StatRow(
                    icon: "crown.fill",
                    title: "Prestige actuel",
                    value: "\(progression?.prestige ?? 0)",
                    color: AppColors.warning
                )
                
                StatRow(
                    icon: "medal.fill",
                    title: "Badges débloqués",
                    value: "\(badgesUnlocked) / \(totalBadges)",
                    color: AppColors.accent
                )
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)
            
            Text(title)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

struct XPByTypeStatsView: View {
    let xpEvents: [XPEvent]
    
    var groupedXP: [XPEventType: Int] {
        Dictionary(grouping: xpEvents, by: { $0.type })
            .mapValues { events in events.reduce(0) { $0 + $1.amount } }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("type"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            if groupedXP.isEmpty {
                Text(t("noData"))
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(XPEventType.allCases, id: \.self) { type in
                        if let xp = groupedXP[type] {
                            XPTypeRow(type: type, xp: xp)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
}

struct XPTypeRow: View {
    let type: XPEventType
    let xp: Int
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: iconForEventType(type))
                .font(.system(size: 18))
                .foregroundColor(AppColors.primary)
                .frame(width: 24)
            
            Text(typeName(type))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text("\(xp) XP")
                .font(AppTypography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, AppSpacing.xs)
    }
    
    private func iconForEventType(_ type: XPEventType) -> String {
        switch type {
        case .checklist: return "checkmark.circle.fill"
        case .postMortem: return "doc.text.fill"
        case .discipline: return "shield.fill"
        case .playbook: return "book.fill"
        case .referral: return "person.2.fill"
        case .social: return "link.circle.fill"
        }
    }
    
    private func typeName(_ type: XPEventType) -> String {
        switch type {
        case .checklist: return "Checklist"
        case .postMortem: return "Post-mortem"
        case .discipline: return "Discipline"
        case .playbook: return "Playbook"
        case .referral: return "Parrainage"
        case .social: return "Réseaux sociaux"
        }
    }
}

struct BadgeStatsView: View {
    let badges: [Badge]
    
    var badgesByRarity: [BadgeRarity: Int] {
        Dictionary(grouping: badges.filter { $0.unlockedAt != nil }, by: { $0.rarity })
            .mapValues { $0.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("badgesParRaret"))
                .font(AppTypography.headlineMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            if badgesByRarity.isEmpty {
                Text(t("aucunBadgeDbloqu"))
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(BadgeRarity.allCases, id: \.self) { rarity in
                        if let count = badgesByRarity[rarity] {
                            BadgeRarityRow(rarity: rarity, count: count)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
}

struct BadgeRarityRow: View {
    let rarity: BadgeRarity
    let count: Int
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(badgeRarityColor(rarity))
                .frame(width: 12, height: 12)
            
            Text(rarity.rawValue.capitalized)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text("\(count)")
                .font(AppTypography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.vertical, AppSpacing.xs)
    }
    
    private func badgeRarityColor(_ rarity: BadgeRarity) -> Color {
        switch rarity {
        case .common: return AppColors.textSecondary
        case .rare: return AppColors.primary
        case .epic: return AppColors.accent
        case .legendary: return AppColors.warning
        }
    }
}

// MARK: - Paramètres du profil
struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var showingStorageMode = false
    @State private var showingAccount = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: {
                        showingAccount = true
                    }) {
                        HStack {
                            Label("Compte", systemImage: "person.circle")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    
                    Button(action: {
                        showingStorageMode = true
                    }) {
                        HStack {
                            Label("Mode de stockage", systemImage: "externaldrive")
                Spacer()
                            Text(appState.storageMode.rawValue.capitalized)
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                } header: {
                    Text(t("gnral"))
                }
                
                Section {
                    Toggle(isOn: .constant(false)) {
                        Label("Notifications push", systemImage: "bell")
                    }
                    
                    Toggle(isOn: .constant(false)) {
                        Label("Analyses IA quotidiennes", systemImage: "brain")
                    }
                } header: {
                    Text(t("no"))
                }
                
                Section {
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("Politique de confidentialité", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        Label("Conditions d'utilisation", systemImage: "doc.text")
                    }
                    
                    Link(destination: URL(string: "https://example.com/support")!) {
                        Label("Support", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text(t("informations"))
                }
                
                Section {
                    Button(role: .destructive, action: {
                        // TODO: Confirmer la suppression
                    }) {
                        Label("Supprimer le compte", systemImage: "trash")
                    }
                }
            }
            .navigationTitle(t("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAccount) {
                AccountView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showingStorageMode) {
                StorageModeSelectionView()
                    .environmentObject(appState)
            }
        }
    }
}

struct StorageModeSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(StorageMode.allCases, id: \.self) { mode in
                        Button(action: {
                            // TODO: Implémenter le changement de mode
                            dismiss()
                        }) {
                            HStack {
                                Text(mode.rawValue.capitalized)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                if appState.storageMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppColors.primary)
                                }
                            }
                        }
                    }
                } header: {
                    Text(t("choisirLeModeDeStockage"))
                } footer: {
                    Text(t("leModeLocalStockeLesDonnesUniquementSurVotreAppareilLeModeFirebaseSynchroniseVosDonnesDansLeCloud"))
                }
            }
            .navigationTitle(t("storageMode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState.shared)
}
