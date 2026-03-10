import Foundation
import SwiftUI
import Combine

extension EnhancedDashboardView {
    var dashboardTopBar: some View {
        HStack(spacing: 12) {
            // Hamburger menu (sans texte)
            Menu {
                // ── Compte ──────────────────────────────
                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async { showProfile = true }
                }) { Label("Profil", systemImage: "person.circle.fill") }

                if appState.authManager.isAuthenticated {
                    Button(action: {
                        HapticFeedback.selection()
                        Task { await appState.authManager.signOut() }
                    }) { Label(Localizable.text("signOut", language: language), systemImage: "rectangle.portrait.and.arrow.right") }
                } else {
                    Button(action: {
                        HapticFeedback.selection()
                        DispatchQueue.main.async { showLogin = true }
                    }) { Label(Localizable.text("signIn", language: language), systemImage: "person.badge.key") }

                    Button(action: {
                        HapticFeedback.selection()
                        DispatchQueue.main.async { showSignUp = true }
                    }) { Label(Localizable.text("signUp", language: language), systemImage: "person.badge.plus") }
                }

                Divider()

                // ── Configuration ────────────────────────
                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async { showStorageSettings = true }
                }) { Label(Localizable.text("storageSettings", language: language), systemImage: "externaldrive") }

                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async { showSubscription = true }
                }) {
                    Label(
                        appState.isPremiumUser ? "Gérer l'abonnement PRO" : "Passer en PRO",
                        systemImage: appState.isPremiumUser ? "crown.fill" : "crown"
                    )
                }

                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async { showAPIConfig = true }
                }) { Label("Configuration API", systemImage: "key.horizontal") }

                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async { showDashboardSettings = true }
                }) { Label("Paramètres Dashboard", systemImage: "line.3.horizontal.decrease.circle") }

                Divider()

                // ── Légal ────────────────────────────────
                Button(action: {
                    if let url = URL(string: "https://trademindsetapp.com/privacy-policy") {
                        UIApplication.shared.open(url)
                    }
                }) { Label("Privacy Policy", systemImage: "lock.shield") }

                Button(action: {
                    if let url = URL(string: "https://trademindsetapp.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }) { Label("Terms of Service", systemImage: "doc.text") }

                Divider()

                // ── Réinitialisation ─────────────────────
                Button(role: .destructive, action: {
                    HapticFeedback.warning()
                    DispatchQueue.main.async { showResetDataConfirmation = true }
                }) { Label("Réinitialiser les données", systemImage: "trash") }

                // ── Développeur (DEBUG uniquement) ───────
                #if DEBUG
                Divider()
                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async { showDevMenu = true }
                }) { Label("Menu Développeur", systemImage: "wrench.and.screwdriver") }
                #endif
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 44, height: 44)
            }

            // Pills alignées comme la maquette
            Button {
                HapticFeedback.selection()
                showStorageSettings = true
            } label: {
                topPill(
                    icon: "server.rack",
                    title: "Serveur",
                    tint: FirebaseAvailability.isConfigured ? AppColors.primary : AppColors.error
                )
            }
            .buttonStyle(.plain)

            Button {
                HapticFeedback.selection()
                showSubscription = true
            } label: {
                topPill(
                    icon: appState.isPremiumUser ? "crown.fill" : "lock.fill",
                    title: appState.isPremiumUser ? "PRO" : "BASIC",
                    tint: appState.isPremiumUser ? AppColors.accent : AppColors.textSecondary
                )
            }
            .buttonStyle(.plain)

            // Sélecteur de langue dans la barre de navigation
            Menu {
                ForEach(Localizable.Language.allCases) { lang in
                    Button(action: {
                        HapticFeedback.selection()
                        LanguageManager.shared.setLanguage(lang)
                    }) {
                        let flagText = lang.flag
                        let langCode = lang.rawValue.uppercased()
                        Text("\(flagText) \(langCode)")
                    }
                }
            } label: {
                topPill(icon: "globe", title: language.rawValue.uppercased(), tint: AppColors.primary)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
        .background(
            AppColors.background
                .ignoresSafeArea(edges: .top)
        )
    }

    private func topPill(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .foregroundColor(tint)
        .frame(minWidth: 72, minHeight: 44)
        .background(
            Capsule()
                .fill(AppColors.cardBackground.opacity(0.75))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.55), lineWidth: 1.5)
        )
    }
}

// MARK: - Trades and Exchanges Combined View
struct TradesAndExchangesView: View {
    @EnvironmentObject var appState: AppState
    @Binding var language: Localizable.Language
    @State private var selectedSegment: Int = 0
    @State private var searchText: String = ""
    @State private var selectedSystem: UUID? = nil
    @State private var filters = TradeFilters()
    @State private var showingAdvancedFilters = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Control
                Picker("Section", selection: $selectedSegment) {
                    Text("Trades").tag(0)
                    Text("Exchanges").tag(1)
                    Text("Émotions").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selection
                if selectedSegment == 0 {
                    TradesListView(
                        trades: appState.trades,
                        searchText: $searchText,
                        selectedSystem: $selectedSystem,
                        filters: $filters,
                        showingAdvancedFilters: $showingAdvancedFilters,
                        systems: appState.systems,
                        exchanges: appState.exchanges
                    )
                } else if selectedSegment == 1 {
                    ExchangesView()
                } else {
                    EmotionalJournalView()
                }
            }
        }
        .navigationTitle({
            switch selectedSegment {
            case 0: return "Trades"
            case 1: return "Exchanges"
            case 2: return "Émotions"
            default: return "Trades"
            }
        }())
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension EnhancedDashboardView {
    // MARK: - Main Content
    var dashboardContent: some View {
        GeometryReader { proxy in
            let viewportHeight = proxy.size.height
            ScrollView {
                mainVStack(viewportHeight: viewportHeight)
                    // Padding bas pour laisser de la place au bouton sticky
                    .padding(.bottom, (showAdvancedMetrics || showAnalytics || showEmotionalSummary) ? 72 : 16)
            }
        }
    }

    // Bouton "Approfondir" sticky — HORS du ScrollView
    var stickyDeepenButton: some View {
        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isDetailsExpanded.toggle() } }) {
            HStack(spacing: 12) {
                // Icône animée
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: isDetailsExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(Localizable.text("deepen", language: language))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(Localizable.text("deepenSubtitle", language: language))
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Badge nombre de sections
                let sectionSuffix = detailsSectionsCount > 1 ? "s" : ""
                Text("\(detailsSectionsCount) section\(sectionSuffix)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(AppColors.primary.opacity(0.12)))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                AppColors.cardBackground
                    .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: -6)
            )
            .overlay(
                Rectangle()
                    .fill(AppColors.border.opacity(0.15))
                    .frame(height: 1),
                alignment: .top
            )
        }
        .buttonStyle(.plain)
    }
    
    private func mainVStack(viewportHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // ⚠️ MASQUÉ TEMPORAIREMENT - Défis désactivés
            // Challenges banner (optionnel, en haut)
            // if showChallenges { challengesBanner }

            // 📰 Bandeau d'actualités défilant
            NewsTickerBanner()
                .padding(.horizontal, -AppSpacing.lg) // pleine largeur

            // Filtres par type d'actif
            assetFilterChips
            
            // 5️⃣ Heatmap & Courbe — blocs unifiés (P&L ↔ charge émotionnelle)
            if showQuickActions {
                UnifiedHeatmapBlock(cache: dashboardCache, onOpenDetails: { showHeatmap = true })
                UnifiedCurveBlock(cache: dashboardCache, onOpenDetails: { showCumulativePnL = true })
            }

            // ✅ Long/Short juste sous Heatmap + P&L
            if showPerformances {
                dashboardSectionHeader(
                    title: Localizable.text("performanceLongShort", language: language),
                    subtitle: Localizable.text("performanceLongShortSubtitle", language: language)
                )
                performancesSection
            }

            // Raccourcis supprimés (doublons avec les blocs Heatmap/Courbe unifiés)
            
            // Section Main Metrics (2x2 grid)
            if showMainMetrics { mainMetricsSection }
            
            // ✅ Contenu "Approfondir" — affiché dans le scroll quand le sticky est ouvert
            if isDetailsExpanded && (showAdvancedMetrics || showAnalytics || showEmotionalSummary) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if showAdvancedMetrics {
                        dashboardDetailsSubsection(
                            title: Localizable.text("advancedMetrics", language: language),
                            subtitle: Localizable.text("advancedMetricsSubtitle", language: language)
                        ) {
                            advancedMetricsSection
                        }
                    }
                    if showAnalytics {
                        dashboardDetailsSubsection(
                            title: Localizable.text("advancedAnalytics", language: language),
                            subtitle: Localizable.text("advancedAnalyticsSubtitle", language: language)
                        ) {
                            analyticsSection
                        }
                    }
                    if showEmotionalSummary {
                        dashboardDetailsSubsection(
                            title: Localizable.text("emotions", language: language),
                            subtitle: Localizable.text("emotionalSummary", language: language)
                        ) {
                            emotionalSummarySection
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.22), value: isDetailsExpanded)
            }
            
            // Espacement minimal pour éviter que le contenu soit coupé par la barre de navigation
            Spacer()
                .frame(height: 80)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Step 5: Heatmap Preview
    @ViewBuilder
    private func heatmapPreviewCard(viewportHeight: CGFloat) -> some View {
        let heatmapHeight = max(120, min(180, viewportHeight * 0.18))
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Localizable.text("heatmap", language: language))
                        .font(AppTypography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    Text(Localizable.text("heatmapPreview", language: language))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Button {
                    HapticFeedback.selection()
                    showHeatmap = true
                } label: {
                    Label("Voir", systemImage: "arrow.up.right.square")
                        .font(AppTypography.captionMedium)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.primary)
            }
            
            MiniWeeklyHeatmapView(trades: filteredTrades)
                .frame(height: heatmapHeight)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
    
    // MARK: - Step 5: P&L Curve Preview
    @ViewBuilder
    private func pnlPreviewCard(viewportHeight: CGFloat) -> some View {
        let chartHeight = max(140, min(220, viewportHeight * 0.22))
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(Localizable.text("pnlCurve", language: language))
                        .font(AppTypography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    Text(Localizable.text("pnlCurvePreview", language: language))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Button {
                    HapticFeedback.selection()
                    showCumulativePnL = true
                } label: {
                    Label("Voir", systemImage: "arrow.up.right.square")
                        .font(AppTypography.captionMedium)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.primary)
            }
            
            MiniPnLCurveView(trades: filteredTrades, appState: appState)
                .frame(height: chartHeight)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }

    // MARK: - Dashboard Disclosure Section (non destructif)
    @ViewBuilder
    private func dashboardDisclosureSection<Content: View>(
        title: String,
        subtitle: String,
        trailing: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            content()
                .padding(.top, AppSpacing.sm)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppTypography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    Text(subtitle)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                
                Spacer()
                
                if let trailing, !trailing.isEmpty {
                    Text(trailing)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(AppColors.background.opacity(0.35))
                                .overlay(
                                    Capsule()
                                        .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                                )
                        )
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .rotationEffect(.degrees(isExpanded.wrappedValue ? 0 : -90))
                    .animation(.easeInOut(duration: 0.18), value: isExpanded.wrappedValue)
            }
            .contentShape(Rectangle())
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.18), value: isExpanded.wrappedValue)
    }
    
    // MARK: - Simple Section Header (Essentiel)
    @ViewBuilder
    private func dashboardSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Text(subtitle)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, AppSpacing.xs)
        .padding(.top, AppSpacing.xs)
    }
    
    // MARK: - Details Subsection (inside "Approfondir")
    @ViewBuilder
    private func dashboardDetailsSubsection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTypography.titleSmall)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Text(subtitle)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, AppSpacing.xs)
            
            content()
        }
    }

    // MARK: - UI: Asset Filter Chips
    private var assetFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AssetFilter.allCases) { filter in
                    Button(action: { assetFilter = filter }) {
                        Text(filter.displayName)
                            .font(.caption.weight(.medium))
                            .foregroundColor(assetFilter == filter ? .white : .secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(assetFilter == filter ? Color.tradingBlue.opacity(0.9) : Color.surface2)
                            )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Dashboard Settings Sheet
    struct DashboardSettingsView: View {
        @Binding var assetFilter: AssetFilter
        @Binding var showChallenges: Bool
        @Binding var showQuickActions: Bool
        @Binding var showMainMetrics: Bool
        @Binding var showAdvancedMetrics: Bool
        @Binding var showPerformances: Bool
        @Binding var showAnalytics: Bool
        
        var body: some View {
            NavigationStack {
                Form {
                    Section("Filtre d'actifs") {
                        Picker("Type", selection: $assetFilter) {
                            ForEach(AssetFilter.allCases) { f in
                                Text(f.displayName).tag(f)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    Section("Sections affichées") {
                        Toggle("Défis du Moment", isOn: $showChallenges)
                        Toggle("Raccourcis", isOn: $showQuickActions)
                        Toggle("Métriques Principales", isOn: $showMainMetrics)
                        Toggle("Métriques Avancées", isOn: $showAdvancedMetrics)
                        Toggle("Performances", isOn: $showPerformances)
                        Toggle("Analytics", isOn: $showAnalytics)
                    }
                }
                .navigationTitle("Dashboard")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Menu hamburger à gauche
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                // Section Profil
                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async {
                        showProfile = true
                    }
                }) {
                    Label("Profil", systemImage: "person.circle.fill")
                }
                
                // Section Compte/Connexion
                if appState.authManager.isAuthenticated {
                    Button(action: {
                        HapticFeedback.selection()
                        Task {
                            await appState.authManager.signOut()
                        }
                    }) {
                        Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    Button(action: {
                        HapticFeedback.selection()
                        DispatchQueue.main.async {
                            showLogin = true
                        }
                    }) {
                        Label("Se connecter", systemImage: "person.badge.key")
                    }
                    
                    Button(action: {
                        HapticFeedback.selection()
                        DispatchQueue.main.async {
                            showSignUp = true
                        }
                    }) {
                        Label("S'inscrire", systemImage: "person.badge.plus")
                    }
                }
                
                Divider()
                
                // Section Stockage/Serveur
                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async {
                        showStorageSettings = true
                    }
                }) {
                    Label("Paramètres Stockage", systemImage: "externaldrive")
                }
                
                // Section PRO
                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async {
                        showSubscription = true
                    }
                }) {
                    Label(
                        appState.isPremiumUser ? "Gérer l'abonnement PRO" : "Passer en PRO",
                        systemImage: appState.isPremiumUser ? "crown.fill" : "crown"
                    )
                }
                
                Divider()
                
                // ⚠️ MASQUÉ TEMPORAIREMENT - Missions/Défis désactivés
                // Section Navigation
                // Button(action: {
                //     HapticFeedback.selection()
                //     DispatchQueue.main.async {
                //         showChallengesHome = true
                //     }
                // }) {
                //     Label("Missions", systemImage: "target")
                // }
                
                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async {
                        showAPIConfig = true
                    }
                }) {
                    Label("Configuration API", systemImage: "key.horizontal")
                }
                
                Divider()
                
                // ⚠️ Sélecteur de langue retiré du menu hamburger - disponible uniquement dans la barre de navigation
                // Langue
                // languageMenu
                // Divider()
                
                // Paramètres Dashboard
                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async {
                        showDashboardSettings = true
                    }
                }) {
                    Label("Paramètres Dashboard", systemImage: "line.3.horizontal.decrease.circle")
                }
                
                // Options développeur (DEBUG uniquement)
                #if DEBUG
                Button(action: {
                    HapticFeedback.selection()
                    DispatchQueue.main.async {
                        showDevMenu = true
                    }
                }) {
                    Label("Menu Développeur", systemImage: "wrench.and.screwdriver")
                }
                #endif
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundColor(AppColors.primary)
            }
        }
        
        // Titre Dashboard au centre
        ToolbarItem(placement: .principal) {
            Text("Dashboard")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
        }
        
        // Badges à droite : Serveur, PRO/BASIC, Langue
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 8) {
                // Badge Serveur (Firebase)
                serverStatusBadge
                
                // Badge PRO/BASIC
                proStatusBadge
                
                // Badge Langue
                languageBadge
            }
        }
    }
    
    // Badge statut serveur (Firebase)
    private var serverStatusBadge: some View {
        Button(action: {
            HapticFeedback.selection()
            DispatchQueue.main.async {
                showStorageSettings = true
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: FirebaseAvailability.isConfigured ? "server.rack" : "exclamationmark.triangle")
                    .font(.caption)
                Text("Serveur")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(FirebaseAvailability.isConfigured ? AppColors.success.opacity(0.2) : AppColors.error.opacity(0.2))
            )
            .foregroundColor(FirebaseAvailability.isConfigured ? AppColors.success : AppColors.error)
        }
    }
    
    // Badge PRO/BASIC
    private var proStatusBadge: some View {
        Button(action: {
            HapticFeedback.selection()
            DispatchQueue.main.async {
                showSubscription = true
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: appState.isPremiumUser ? "crown.fill" : "lock.fill")
                    .font(.caption)
                Text(appState.isPremiumUser ? "PRO" : "BASIC")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(appState.isPremiumUser ? AppColors.accent.opacity(0.2) : AppColors.textSecondary.opacity(0.15))
            )
            .foregroundColor(appState.isPremiumUser ? AppColors.accent : AppColors.textSecondary)
        }
    }
    
    // Badge Langue
    private var languageBadge: some View {
        Menu {
            ForEach(Localizable.Language.allCases, id: \.self) { lang in
                Button(action: {
                    HapticFeedback.selection()
                    language = lang
                }) {
                    HStack {
                        Text("\(lang.flag) \(lang.rawValue.uppercased())")
                        if language == lang {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(language.rawValue.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(AppColors.primary.opacity(0.15))
                )
                .foregroundColor(AppColors.primary)
        }
    }
    
    private var toolbarTitleContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.circle.fill").foregroundColor(.tradingBlue)
            Text("Dashboard").font(.headline)
        }
    }
    
    // MARK: - Subviews to help type-checker
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc("title")).font(.title2.weight(.semibold))
            Text(loc("subtitle")).font(.footnote).foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }
    
    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            // Supprimé: doublons "Heatmap" / "Courbe P&L" (désormais unifiés via les blocs dashboard)
        }
    }
    
    private var mainMetricsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(loc("mainMetrics"))
                .font(AppTypography.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxs)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.xs),
                GridItem(.flexible(), spacing: AppSpacing.xs)
            ], spacing: AppSpacing.xs) {
                ProfessionalMetricCard(
                    value: String(format: "%.1f%%", stats.winRate),
                    title: loc("winRate"),
                    subtitle: "\(stats.wins)W / \(stats.losses)L",
                    color: AppColors.success,
                    icon: "chart.line.uptrend.xyaxis"
                )
                .onAppear {
                    print("📊 [MainMetrics] Win Rate affiché: \(stats.winRate)% avec \(stats.wins)W / \(stats.losses)L")
                    print("📊 [MainMetrics] filteredTrades utilisé: \(filteredTrades.count) trades")
                    print("📊 [MainMetrics] appState.trades total: \(appState.trades.count) trades")
                }
                
                ProfessionalMetricCard(
                    value: String(format: "$%.2f", stats.totalPnL),
                    title: loc("totalPnL"),
                    subtitle: "\(stats.totalTrades) trades",
                    color: AppColors.info,
                    icon: "dollarsign.circle.fill"
                )
                .onAppear {
                    print("📊 [MainMetrics] Total PnL affiché: $\(stats.totalPnL) avec \(stats.totalTrades) trades")
                }
                
                ProfessionalMetricCard(
                    value: String(format: "%.2f", stats.payoffRatio),
                    title: loc("payoffRatio"),
                    subtitle: "Gain/Perte",
                    color: AppColors.primary,
                    icon: "arrow.up.arrow.down.circle.fill"
                )
                
                ProfessionalMetricCard(
                    value: String(format: "$%.2f", stats.totalFees),
                    title: loc("fees"),
                    subtitle: "Total",
                    color: AppColors.accent,
                    icon: "creditcard.fill"
                )
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
                    
    private var advancedMetricsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: AppSpacing.xs),
                GridItem(.flexible(), spacing: AppSpacing.xs)
            ], spacing: AppSpacing.xs) {
                ProfessionalMetricCard(
                    value: String(format: "$%.2f", stats.maxDrawdown),
                    title: loc("maxDrawdown"),
                    subtitle: "Max loss",
                    color: AppColors.error,
                    icon: "arrow.down.circle.fill"
                )
                
                ProfessionalMetricCard(
                    value: String(format: "%.2f", stats.sharpeRatio),
                    title: loc("sharpeRatio"),
                    subtitle: "Return/Risk",
                    color: AppColors.primaryDark,
                    icon: "chart.bar.fill"
                )
                
                ProfessionalMetricCard(
                    value: String(format: "$%.2f", stats.expectancy),
                    title: loc("expectancy"),
                    subtitle: "Avg gain/trade",
                    color: Color(red: 0.0, green: 0.7, blue: 0.7), // Teal
                    icon: "arrow.triangle.2.circlepath.circle.fill"
                )
                
                ProfessionalMetricCard(
                    value: "\(stats.longestWinStreak)",
                    title: loc("bestStreak"),
                    subtitle: "\(stats.longestLossStreak) max losses",
                    color: AppColors.warning,
                    icon: "flame.fill"
                )
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }
                    
    private var performancesSection: some View {
        HStack(spacing: AppSpacing.md) {
                        PerformanceCard(
                            title: loc("longPerf"),
                            winRate: stats.longWinRate,
                            trades: stats.longTrades,
                            pnl: stats.longPnL,
                color: AppColors.success,
                            language: language
                        )
            
                        PerformanceCard(
                            title: loc("shortPerf"),
                            winRate: stats.shortWinRate,
                            trades: stats.shortTrades,
                            pnl: stats.shortPnL,
                color: AppColors.error,
                            language: language
                        )
                    }
    }
    
    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header avec titre et filtre - plus compact
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                Text(loc("advancedAnalyticsTitle"))
                        .font(AppTypography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    Text(loc("advancedAnalyticsSubtitleDetail"))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Filtre de période amélioré
            periodFilter
            }
            
            // Onglets d'analyse améliorés
            analyticsTabs
            
            // Contenu selon l'onglet sélectionné avec animation
            Group {
                switch selectedAnalyticsTab {
                case .analytics:
                    analyticsContent
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                case .timeMetrics:
                    timeMetricsContent
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                case .calendar:
                    calendarContent
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            // ✅ Laisser le contenu respirer (évite clipping/chevauchements)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedAnalyticsTab)
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .shadow(color: AppShadow.small, radius: AppShadow.smallRadius, x: 0, y: 2)
        )
            }
    
    // MARK: - Emotional Summary Section
    private var emotionalSummarySection: some View {
        ProfessionalEmotionalBalanceView(
            analysis: appState.emotionPerformanceAnalysis,
            moodEntries: appState.moodEntries,
            trades: filteredTrades
        )
    }
    
    // MARK: - Helper Functions for Emotional Summary
    private func getAverageEmotionalState() -> String {
        // Analyser les émotions récentes du journal émotionnel
        let recentMoods = getRecentMoods()
        
        if recentMoods.isEmpty {
            // Fallback sur les trades si pas de journal émotionnel
            return getEmotionalStateFromTrades()
        }
        
        // Analyser l'émotion dominante des dernières entrées
        let emotionGroups = Dictionary(grouping: recentMoods, by: { $0.emotionalState })
        let emotionCounts = emotionGroups.mapValues { $0.count }
        
        let dominantEmotion = emotionCounts.max(by: { $0.value < $1.value })?.key ?? .calm
        
        switch dominantEmotion {
        case .confident, .focused, .calm:
            return "😊 Confiant"
        case .stressed, .frustrated, .fearful:
            return "😟 Stressé"
        case .impatient, .greedy, .excited:
            return "😤 Agité"
        default:
            return "😐 Neutre"
        }
    }
    
    private func getEmotionalStateFromTrades() -> String {
        // Fallback : analyser les trades si pas de journal émotionnel
        let recentTrades = filteredTrades.suffix(10)
        let winRate = recentTrades.isEmpty ? 0 : Double(recentTrades.filter { $0.pnl > 0 }.count) / Double(recentTrades.count)
        
        if winRate >= 0.7 {
            return "😊 Confiant"
        } else if winRate >= 0.4 {
            return "😐 Neutre"
        } else {
            return "😟 Stressé"
        }
    }
    
    private func getRecentMoods() -> [MoodEntry] {
        // Récupérer les dernières entrées du journal émotionnel
        // Note: Cette fonction devrait être connectée au MoodStore
        // Pour l'instant, retournons un tableau vide
        return []
    }
    
    private func getAverageEmotionalStateDetail() -> String {
        let recentMoods = getRecentMoods()
        
        if recentMoods.isEmpty {
            // Fallback sur les trades
            let recentTrades = filteredTrades.suffix(10)
            let winRate = recentTrades.isEmpty ? 0 : Double(recentTrades.filter { $0.pnl > 0 }.count) / Double(recentTrades.count)
            
            if winRate >= 0.7 {
                return "Performance excellente sur 10 derniers trades"
            } else if winRate >= 0.4 {
                return "Performance équilibrée sur 10 derniers trades"
            } else {
                return "Période difficile sur 10 derniers trades"
            }
        }
        
        // Analyser les émotions récentes
        let emotionGroups = Dictionary(grouping: recentMoods, by: { $0.emotionalState })
        let emotionCounts = emotionGroups.mapValues { $0.count }
        let totalMoods = recentMoods.count
        
        if let dominantEmotion = emotionCounts.max(by: { $0.value < $1.value }) {
            let percentage = Int((Double(dominantEmotion.value) / Double(totalMoods)) * 100)
            return "\(percentage)% d'émotions \(dominantEmotion.key.displayName.lowercased()) sur \(totalMoods) entrées"
        }
        
        return "Analyse basée sur le journal émotionnel"
    }
    
    private func getEmotionalImpact() -> String {
        let recentMoods = getRecentMoods()
        
        if recentMoods.isEmpty {
            // Analyser l'impact émotionnel sur les trades récents
            return analyzeEmotionalImpactOnTrades()
        }
        
        // Calculer la corrélation émotions-P&L réelle
        let correlation = calculateEmotionPnLCorrelation(recentMoods)
        
        if correlation > 0.2 {
            return "📈 Positif"
        } else if correlation < -0.2 {
            return "📉 Négatif"
        } else {
            return "⚖️ Neutre"
        }
    }
    
    private func analyzeEmotionalImpactOnTrades() -> String {
        // Analyser les patterns émotionnels dans les trades récents
        let recentTrades = filteredTrades.suffix(20)
        
        if recentTrades.isEmpty {
            return "📊 Insuffisant"
        }
        
        // Analyser les séquences de gains/pertes
        let consecutiveWins = calculateConsecutiveWins(recentTrades)
        let consecutiveLosses = calculateConsecutiveLosses(recentTrades)
        
        // Analyser la volatilité émotionnelle (variations importantes de P&L)
        let pnls = recentTrades.map { $0.pnl }
        let volatility = calculatePnLVolatility(pnls)
        
        // Déterminer l'impact émotionnel
        if consecutiveLosses >= 3 {
            return "📉 Stress élevé"
        } else if consecutiveWins >= 3 {
            return "📈 Confiance élevée"
        } else if volatility > 1000 {
            return "⚠️ Instabilité"
        } else {
            return "⚖️ Équilibré"
        }
    }
    
    private func calculateConsecutiveWins(_ trades: ArraySlice<Trade>) -> Int {
        var maxWins = 0
        var currentWins = 0
        
        for trade in trades.reversed() {
            if trade.pnl > 0 {
                currentWins += 1
                maxWins = max(maxWins, currentWins)
            } else {
                currentWins = 0
            }
        }
        
        return maxWins
    }
    
    private func calculateConsecutiveLosses(_ trades: ArraySlice<Trade>) -> Int {
        var maxLosses = 0
        var currentLosses = 0
        
        for trade in trades.reversed() {
            if trade.pnl < 0 {
                currentLosses += 1
                maxLosses = max(maxLosses, currentLosses)
            } else {
                currentLosses = 0
            }
        }
        
        return maxLosses
    }
    
    private func calculatePnLVolatility(_ pnls: [Double]) -> Double {
        guard !pnls.isEmpty else { return 0 }
        
        let mean = pnls.reduce(0, +) / Double(pnls.count)
        let variance = pnls.map { pow($0 - mean, 2) }.reduce(0, +) / Double(pnls.count)
        return sqrt(variance)
    }
    
    private func calculateEmotionPnLCorrelation(_ moods: [MoodEntry]) -> Double {
        // Calculer la corrélation entre les émotions et les performances
        var positiveEmotions = 0
        var negativeEmotions = 0
        
        for mood in moods {
            switch mood.emotionalState {
            case .confident, .focused, .calm:
                positiveEmotions += 1
            case .stressed, .frustrated, .fearful, .impatient, .greedy:
                negativeEmotions += 1
            default:
                break
            }
        }
        
        let total = positiveEmotions + negativeEmotions
        if total == 0 { return 0 }
        
        // Corrélation simplifiée : ratio émotions positives vs négatives
        return Double(positiveEmotions - negativeEmotions) / Double(total)
    }
    
    private func getEmotionalImpactDetail() -> String {
        let recentMoods = getRecentMoods()
        
        if recentMoods.isEmpty {
            // Analyser l'impact émotionnel sur les trades récents
            let recentTrades = filteredTrades.suffix(20)
            
            if recentTrades.isEmpty {
                return "Pas assez de données pour analyser l'impact émotionnel"
            }
            
            let consecutiveLosses = calculateConsecutiveLosses(recentTrades)
            let consecutiveWins = calculateConsecutiveWins(recentTrades)
            let pnls = recentTrades.map { $0.pnl }
            let volatility = calculatePnLVolatility(pnls)
            
            if consecutiveLosses >= 3 {
                return "Série de \(consecutiveLosses) pertes consécutives - Stress émotionnel élevé"
            } else if consecutiveWins >= 3 {
                return "Série de \(consecutiveWins) gains consécutifs - Confiance élevée"
            } else if volatility > 1000 {
                return "Volatilité P&L élevée (\(Int(volatility))) - Instabilité émotionnelle"
            } else {
                return "Performance équilibrée - Émotions stables"
            }
        }
        
        // Expliquer la corrélation émotions-P&L
        let correlation = calculateEmotionPnLCorrelation(recentMoods)
        
        if correlation > 0.2 {
            return "Émotions positives corrélées aux gains (+\(Int(correlation * 100))%)"
        } else if correlation < -0.2 {
            return "Émotions négatives corrélées aux pertes (\(Int(correlation * 100))%)"
        } else {
            return "Pas de corrélation claire entre émotions et P&L"
        }
    }
    
    private func getEmotionalRisk() -> String {
        // Analyse des pertes consécutives
        let recentTrades = filteredTrades.suffix(10)
        var consecutiveLosses = 0
        var maxConsecutiveLosses = 0
        
        for trade in recentTrades.reversed() {
            if trade.pnl < 0 {
                consecutiveLosses += 1
                maxConsecutiveLosses = max(maxConsecutiveLosses, consecutiveLosses)
            } else {
                consecutiveLosses = 0
            }
        }
        
        if maxConsecutiveLosses >= 4 {
            return "🔴 Critique"
        } else if maxConsecutiveLosses >= 2 {
            return "🟡 Attention"
        } else {
            return "🟢 Stable"
        }
    }
    
    private func getEmotionalRiskDetail() -> String {
        let recentTrades = filteredTrades.suffix(10)
        var consecutiveLosses = 0
        var maxConsecutiveLosses = 0
        
        for trade in recentTrades.reversed() {
            if trade.pnl < 0 {
                consecutiveLosses += 1
                maxConsecutiveLosses = max(maxConsecutiveLosses, consecutiveLosses)
            } else {
                consecutiveLosses = 0
            }
        }
        
        if maxConsecutiveLosses >= 4 {
            return "Série de pertes importante - Attention"
        } else if maxConsecutiveLosses >= 2 {
            return "Quelques pertes consécutives - Vigilance"
        } else {
            return "Pas de série de pertes - Situation stable"
        }
    }
    
    private func getEmotionalAdvice() -> String {
        // Conseils basés sur les patterns de trading
        let recentTrades = filteredTrades.suffix(15)
        let winRate = recentTrades.isEmpty ? 0 : Double(recentTrades.filter { $0.pnl > 0 }.count) / Double(recentTrades.count)
        
        if winRate < 0.3 {
            return "🛑 Pause"
        } else if winRate < 0.5 {
            return "📚 Étudier"
        } else {
            return "🚀 Continuer"
        }
    }
    
    private func getEmotionalAdviceDetail() -> String {
        let recentTrades = filteredTrades.suffix(15)
        let winRate = recentTrades.isEmpty ? 0 : Double(recentTrades.filter { $0.pnl > 0 }.count) / Double(recentTrades.count)
        
        if winRate < 0.3 {
            return "Prenez du recul et analysez vos stratégies"
        } else if winRate < 0.5 {
            return "Étudiez vos patterns et améliorez votre approche"
        } else {
            return "Continuez avec votre stratégie actuelle"
        }
    }
    
    // MARK: - Emotional Stat Card Component
    struct EmotionalStatCard: View {
        let icon: String
        let title: String
        let value: String
        let detail: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding()
            .background(Color.surface3)
            .cornerRadius(12)
        }
            }
    
    private var periodFilter: some View {
                    Menu {
            ForEach(PeriodFilter.allCases, id: \.self) { period in
                Button(action: {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedPeriod = period
                    }
                }) {
                    HStack {
                        Text(period.rawValue)
                            .font(AppTypography.bodyMedium)
                        if selectedPeriod == period {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(AppColors.primary)
                                .font(.caption)
                        }
                    }
                }
                        }
                    } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
                
                Text(selectedPeriod.rawValue)
                    .font(AppTypography.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    private var analyticsTabs: some View {
        HStack(spacing: AppSpacing.xs) {
            Spacer()
            
            ForEach([AnalyticsTab.analytics, .timeMetrics, .calendar], id: \.self) { tab in
                Button(action: {
                    HapticFeedback.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedAnalyticsTab = tab
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                            .foregroundColor(selectedAnalyticsTab == tab ? .white : AppColors.textSecondary)
                        
                        Text(tab.localizedName(language: language))
                            .font(.system(size: 12, weight: selectedAnalyticsTab == tab ? .semibold : .medium))
                            .foregroundColor(selectedAnalyticsTab == tab ? .white : AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        Group {
                            if selectedAnalyticsTab == tab {
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.primary, AppColors.accent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: AppColors.primary.opacity(0.3), radius: 4, x: 0, y: 2)
                            } else {
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .fill(AppColors.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.medium)
                                            .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                                    )
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
    }
    
    private var analyticsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header du graphique - plus compact
            HStack {
                Text(loc("performanceByMonth"))
                    .font(AppTypography.titleSmall)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
            }
            
            // Graphique amélioré avec animation - plus compact
            VStack(spacing: AppSpacing.xs) {
                // Graphique en barres - hauteur réduite
                HStack(alignment: .bottom, spacing: AppSpacing.xxs) {
                    ForEach(Array(monthlyPerformance.enumerated()), id: \.offset) { index, value in
                        let maxValue = max(monthlyPerformance.max() ?? 1, abs(monthlyPerformance.min() ?? 1))
                        let normalizedHeight = maxValue > 0 ? abs(value) / maxValue : 0
                        let height = max(6, min(100, normalizedHeight * 100))
                        let isPositive = value >= 0
                        
                        VStack(spacing: 2) {
                            // Barre avec gradient
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isPositive ? AppColors.success : AppColors.error)
                                .frame(width: 20, height: height)
                            
                            // Label du mois
                            Text(monthAbbreviation(index))
                                .font(.system(size: 8))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 20)
                        }
                    }
                }
                .frame(height: 120)
                .padding(AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.small)
                        .fill(AppColors.background)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                        )
                )
                
                // Légende compacte
                HStack(spacing: AppSpacing.sm) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AppColors.success)
                            .frame(width: 8, height: 8)
                        Text(loc("gains"))
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(AppColors.error)
                            .frame(width: 8, height: 8)
                        Text(loc("pertes"))
                            .font(.system(size: 9))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Spacer()
                }
            }
            
            // Métriques de performance - plus compactes
            HStack(spacing: AppSpacing.xs) {
                MetricSummaryCard(
                    title: loc("bestMonth"),
                    value: bestMonth,
                    icon: "arrow.up.circle.fill",
                    color: AppColors.success
                )
                
                MetricSummaryCard(
                    title: loc("worstMonth"),
                    value: worstMonth,
                    icon: "arrow.down.circle.fill",
                    color: AppColors.error
                )
                
                MetricSummaryCard(
                    title: loc("average"),
                    value: averageMonth,
                    icon: "equal.circle.fill",
                    color: AppColors.primary
                )
            }
        }
    }
    
    // MARK: - Metric Summary Card Component
    struct MetricSummaryCard: View {
        let title: String
        let value: Double
        let icon: String
        let color: Color
        
        var body: some View {
                VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(color)
                    
                    Text(title)
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                Text(formatCompactCurrency(value))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(value >= 0 ? AppColors.success : AppColors.error)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .stroke(color.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        
        private func formatCompactCurrency(_ value: Double) -> String {
            let absValue = abs(value)
            let sign = value < 0 ? "-" : ""
            
            if absValue >= 1_000_000 {
                return "\(sign)$\(String(format: "%.1fM", absValue / 1_000_000))"
            } else if absValue >= 1_000 {
                return "\(sign)$\(String(format: "%.1fK", absValue / 1_000))"
            } else {
                return "\(sign)$\(String(format: "%.0f", absValue))"
            }
        }
    }
    
    // Helper pour l'abréviation du mois
    private func monthAbbreviation(_ index: Int) -> String {
        let months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        return index < months.count ? months[index] : "\(index + 1)"
    }
    
    // Helper pour formater la devise de manière compacte
    private func formatCompactCurrency(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        
        if absValue >= 1_000_000 {
            return "\(sign)$\(String(format: "%.1fM", absValue / 1_000_000))"
        } else if absValue >= 1_000 {
            return "\(sign)$\(String(format: "%.1fK", absValue / 1_000))"
        } else {
            return "\(sign)$\(String(format: "%.0f", absValue))"
        }
    }
    
    private var calendarContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Header - plus compact, sur une ligne
            HStack {
                Text("Calendrier des Trades")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Spacer()
            }
            
            // Calendrier amélioré - plus compact
                let calendar = Calendar.current
                let today = Date()
                let startOfMonth = calendar.dateInterval(of: .month, for: today)?.start ?? today
                let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
                let firstWeekday = calendar.component(.weekday, from: startOfMonth)
                
            VStack(spacing: AppSpacing.xs) {
                // En-têtes des jours de la semaine
                HStack(spacing: 0) {
                    ForEach(["L", "M", "M", "J", "V", "S", "D"], id: \.self) { day in
                        Text(day)
                            .font(.system(size: 9))
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 4)
                
                // Grille du calendrier - hauteur réduite
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    // Jours vides du début du mois
                    ForEach(0..<(firstWeekday - 1), id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 32)
                    }
                    
                    // Jours du mois avec données réelles
                    ForEach(1...daysInMonth, id: \.self) { day in
                        let dayDate = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) ?? today
                        let isToday = calendar.isDate(dayDate, inSameDayAs: today)
                        let dayTrades = appState.trades.filter { calendar.isDate($0.date, inSameDayAs: dayDate) }
                        let dayPnL = dayTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
                        let hasTrade = !dayTrades.isEmpty
                        let isPositive = dayPnL >= 0
                        
                        VStack(spacing: 2) {
                            Text("\(day)")
                                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                                .foregroundColor(AppColors.textPrimary)
                            
                            if hasTrade {
                                HStack(spacing: 1) {
                                Circle()
                                        .fill(isPositive ? AppColors.success : AppColors.error)
                                        .frame(width: 4, height: 4)
                                    
                                    if dayTrades.count > 1 {
                                        Text("\(dayTrades.count)")
                                            .font(.system(size: 6, weight: .bold))
                                            .foregroundColor(isPositive ? AppColors.success : AppColors.error)
                                    }
                                }
                            }
                        }
                        .frame(height: 32)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isToday ? AppColors.primary.opacity(0.2) : AppColors.background)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(isToday ? AppColors.primary : Color.clear, lineWidth: 1.5)
                                )
                        )
                    }
                }
            }
            .padding(AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.small)
                    .fill(AppColors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Légende compacte
            HStack(spacing: AppSpacing.sm) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.success)
                        .frame(width: 6, height: 6)
                    Text("Gagnant")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.error)
                        .frame(width: 6, height: 6)
                    Text("Perdant")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(AppColors.primary)
                        .frame(width: 6, height: 6)
                    Text("Aujourd'hui")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
    }
    
    // ⚠️ MASQUÉ TEMPORAIREMENT - Défis désactivés
    private var challengesBanner: some View {
        EmptyView()
    }
    
    // CODE ORIGINAL COMMENTÉ - À réactiver plus tard si besoin
    /*
    private var challengesBanner: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.title3)
                        .foregroundColor(.tradingBlue)
                    Text("Défis du Moment")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                Spacer()
                Button("Voir tout") {
                    showChallengesHome = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.tradingBlue)
            }
            
            // Défis quotidiens
            VStack(spacing: 8) {
                ChallengeBannerItem(
                    title: "Faire 3 trades gagnants",
                    progress: 0.6,
                    reward: "50 XP",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                ChallengeBannerItem(
                    title: "Analyser 5 graphiques",
                    progress: 0.3,
                    reward: "30 XP",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                )
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.tradingBlue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.tradingBlue.opacity(0.3), lineWidth: 1)
        )
    }
    */
    
    private func loc(_ key: String) -> String {
        Localizable.text(key, language: language)
    }
}
