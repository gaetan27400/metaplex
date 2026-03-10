import SwiftUI
import Charts

struct EmotionalJournalView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @State private var selectedEmotion: EmotionalState = .calm
    @State private var intensity: Double = 5
    @State private var notes: String = ""
    @State private var selectedContext: MoodContext = .beforeTrade
    @State private var showingAnalysis = false
    @State private var emotionalAnalysis: EmotionalAnalysis?
    @State private var showingHistory = false
    @State private var showingInsightsSheet: Bool = false
    @State private var showNotesField: Bool = false
    @State private var showingMoreOptions: Bool = false

    // ✅ Nouveaux champs "data brute" (optionnels)
    @State private var secondaryEmotion: EmotionalState? = nil
    @State private var durationCategory: MoodDurationCategory? = nil
    @State private var trigger: MoodTrigger? = nil
    @State private var intention: MoodIntention? = nil
    @State private var controlLevel: Double = 5
    @State private var isExceptional: Bool = false
    @State private var tags: [String] = []
    @State private var tagDraft: String = ""
    @State private var checklist: ChecklistBeforeTrade = .empty
    @State private var miniChecklist: MiniPreTradeChecklist = .empty
    @State private var quickActions: [MoodQuickActionEvent] = []

    private let coach: EmotionsCoachProviding = LocalEmotionsCoachMock()
    
    /// Accès simplifié au moodStore partagé (via appState)
    private var moodStore: any MoodStore {
        appState.moodStore
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        // ✅ Flow "log d'abord" (concis & pro)
                        compactEntryHeader
                        compactContextRow
                        if selectedContext == .beforeTrade {
                            miniChecklistRow
                        }
                        improvedEmotionSelector
                        modernIntensitySlider
                        triggerChipsRow
                        quickActionRow
                        if showNotesField {
                            modernNotesSection
                        }

                        // Historique ultra-compact (1 ligne)
                        compactHistorySection
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    // ✅ Réserve l’espace pour la barre d’action (évite que le CTA soit masqué)
                    .padding(.bottom, 220)
                }

                // ✅ CTA toujours visible, même si `safeAreaInset` est ignoré dans des stacks imbriquées
                saveBar
                    // ✅ Remonte au-dessus de la bottom bar custom (TradingJournalApp)
                    .padding(.bottom, 86)
            }
            .navigationTitle(t("emotions"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showingHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(AppColors.primary)
                        }

                        Button {
                            showingInsightsSheet = true
                        } label: {
                            Image(systemName: "sparkles")
                                .foregroundColor(AppColors.primary)
                        }
                    }
                }
            }
        }
        // ✅ Contrainte: tous les `.sheet(...)` sont chaînés sur la vue racine du `body` (NavigationView)
        .sheet(isPresented: $showingAnalysis) {
            if let analysis = emotionalAnalysis {
                EmotionalAnalysisView(analysis: analysis)
            }
        }
        .sheet(isPresented: $showingHistory) {
            EmotionalHistoryView()
        }
        .sheet(isPresented: $showingMoreOptions) {
            EmotionalMoreOptionsSheet(
                selectedContext: $selectedContext,
                notes: $notes,
                secondaryEmotion: $secondaryEmotion,
                durationCategory: $durationCategory,
                trigger: $trigger,
                intention: $intention,
                controlLevel: $controlLevel,
                isExceptional: $isExceptional,
                tags: $tags,
                tagDraft: $tagDraft,
                checklist: $checklist,
                miniChecklist: $miniChecklist
            )
        }
        .sheet(isPresented: $showingInsightsSheet) {
            insightsSheetContent
        }
    }
    
    // Optionnel (recommandé): extraction du contenu de la sheet "Insights" pour réduire l’imbrication.
    private var insightsSheetContent: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    if !appState.moodEntries.isEmpty {
                        quickStatsRow
                    }

                    emotionalStabilitySection
                    emotionTimelineSection
                    emotionTrendSection
                    emotionInsightSection
                    visualInsightsSection
                    compactHistorySection

                    // Supprimé : doublon avec le dashboard (Heatmap/Courbe unifiés P&L ↔ charge émotionnelle)

                    Button {
                        Task {
                            await loadAnalysis()
                            showingAnalysis = true
                        }
                    } label: {
                        Label("Analyse détaillée", systemImage: "brain.head.profile")
                            .font(AppTypography.headlineSmall)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(AppSpacing.lg)
                            .background(AppColors.accent.opacity(0.9))
                            .cornerRadius(AppRadius.large)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .padding(.bottom, AppSpacing.lg)
            }
            .background(Color.black)
            .navigationTitle(t("insights"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t("close")) { showingInsightsSheet = false }
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        // ✅ Bouton principal toujours accessible (ergonomie)
        .safeAreaInset(edge: .bottom) {
            saveBar
        }
    }

    // MARK: - Header (compact, orienté action)
    private var compactEntryHeader: some View {
        HStack(spacing: 12) {
            Text(selectedEmotion.emoji)
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 2) {
                // ✅ Contexte en premier
                Text(selectedContext.displayName)
                    .font(AppTypography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(t("name"))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                Text(coach.recommendation(emotionalState: selectedEmotion, intensity: Int(intensity), context: selectedContext, trigger: trigger))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textTertiary)
                    .lineLimit(2)
            }
            Spacer()
            Text(MoodEntry(emotionalState: selectedEmotion, intensity: Int(intensity), notes: nil, tradeId: nil, context: selectedContext).impact.badgeEmoji)
                .font(.system(size: 18))
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(Color(hex: selectedEmotion.color).opacity(0.18), lineWidth: 1)
                )
        )
        // Double tap → répéter la dernière entrée
        .onTapGesture(count: 2) {
            repeatLastEntry()
        }
    }

    // MARK: - Trigger chips (1 tap)
    private var triggerChipsRow: some View {
        let visible: [MoodTrigger] = [.fomo, .revenge, .news, .loss, .overconfidence, .fatigue]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visible, id: \.self) { t in
                    TriggerChip(title: t.chipLabel, isSelected: trigger == t) {
                        HapticFeedback.selection()
                        trigger = (trigger == t) ? nil : t
                    }
                }
                // accès aux autres via Options (sheet) déjà présent
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Action rapide (contextuelle)
    private var quickActionRow: some View {
        let suggested = coach.suggestedQuickAction(emotionalState: selectedEmotion, intensity: Int(intensity), context: selectedContext, trigger: trigger)
        return HStack(spacing: 10) {
            if let suggested {
                Button {
                    HapticFeedback.light()
                    let event = MoodQuickActionEvent(action: suggested)
                    quickActions.append(event)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: suggested.systemImage)
                        Text(suggested.displayName)
                            .fontWeight(.semibold)
                    }
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .fill(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.large)
                                    .stroke(AppColors.primary.opacity(0.18), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let last = quickActions.last {
                Text(t("name"))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Mini checklist (3)
    private var miniChecklistRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("prtrade"))
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("Suggérer") {
                    HapticFeedback.selection()
                    if let suggested = coach.suggestedMiniChecklist(
                        emotionalState: selectedEmotion,
                        intensity: Int(intensity),
                        context: selectedContext,
                        trigger: trigger
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            miniChecklist = suggested
                        }
                    }
                }
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.primary)
            }

            HStack(spacing: 10) {
                ToggleChip(title: "Plan OK", isOn: $miniChecklist.planOK)
                ToggleChip(title: "Taille OK", isOn: $miniChecklist.sizeOK)
                ToggleChip(title: "Stop défini", isOn: $miniChecklist.stopDefined)
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
        )
    }

    // MARK: - Contexte (compact)
    private var compactContextRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("contexte"))
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showNotesField.toggle()
                    }
                } label: {
                    Label(showNotesField ? "Masquer note" : "Ajouter note", systemImage: "text.bubble")
                        .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Picker("", selection: $selectedContext) {
                    Text(t("avant")).tag(MoodContext.beforeTrade)
                    Text(t("aprs")).tag(MoodContext.afterTrade)
                    Text(t("tuesday")).tag(MoodContext.duringMarket)
                }
                .pickerStyle(.segmented)

                Menu {
                    Button("Après une perte") {
                        selectedContext = .afterLoss
                        trigger = .previousLoss // preset rapide
                    }
                    Button("Après un gain") { selectedContext = .afterWin }
                    Button("Fin de journée") { selectedContext = .endOfDay }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .padding(8)
                        .background(
                            Circle().fill(AppColors.cardBackground)
                        )
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
        )
    }

    private var saveBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    showingMoreOptions = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                        Text(t("options"))
                            .fontWeight(.semibold)
                    }
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.primary)
                    .frame(minWidth: 110)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .fill(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.large)
                                    .stroke(AppColors.primary.opacity(0.25), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Button(action: addMood) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "heart.fill")
                            .font(.title3)
                        Text(t("valider"))
                            .font(AppTypography.headlineSmall)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.md)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: selectedEmotion.color), Color(hex: selectedEmotion.color).opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(AppRadius.large)
                }
                .buttonStyle(.plain)
                .disabled(intensity < 1)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Header Moderne
    private var modernHeader: some View {
        VStack(spacing: AppSpacing.md) {
            // État actuel avec design moderne
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                Text(t("tuesday"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    HStack(spacing: 8) {
                        Text(selectedEmotion.emoji)
                            .font(.system(size: 26))
                        
                        Text(selectedEmotion.displayName)
                            .font(AppTypography.titleMedium)
                            .fontWeight(.bold)
                    .foregroundColor(Color(hex: selectedEmotion.color))
                    }
            }
            
                Spacer()
                
                // Indicateur d'intensité circulaire
                ZStack {
                    Circle()
                        .stroke(Color(hex: selectedEmotion.color).opacity(0.3), lineWidth: 8)
                        .frame(width: 46, height: 46)
                    
                        Circle()
                        .trim(from: 0, to: intensity / 10)
                        .stroke(Color(hex: selectedEmotion.color), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 46, height: 46)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: intensity)
                    
                    Text("\(Int(intensity))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: selectedEmotion.color))
                }
            }
            }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(Color(hex: selectedEmotion.color).opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppShadow.medium, radius: AppShadow.mediumRadius, x: 0, y: 2)
    }
    
    // MARK: - Stats Rapides
    private var quickStatsRow: some View {
        HStack(spacing: AppSpacing.md) {
            StatChip(
                title: "Total",
                value: "\(appState.moodEntries.count)",
                color: AppColors.primary
            )
            
            StatChip(
                title: "Cette semaine",
                value: "\(weeklyMoodCount)",
                color: AppColors.success
            )
            
            StatChip(
                title: "Moyenne",
                value: String(format: "%.1f", averageIntensity),
                color: AppColors.warning
            )
        }
    }
    
    private var emotionalStabilitySection: some View {
        if appState.moodEntries.isEmpty {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            EmotionalStabilityCard(
                score: stabilityScore,
                trend: stabilityTrend,
                dominantEmotion: recentDominantEmotion
            )
        )
    }
    
    private var emotionTimelineSection: some View {
        if emotionTimelineEntries.isEmpty {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            EmotionTimelineView(entries: emotionTimelineEntries)
        )
    }
    
    private var emotionTrendSection: some View {
        if emotionTrendData.isEmpty {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            EmotionTrendChartSection(points: emotionTrendData)
        )
    }
    
    private var emotionInsightSection: some View {
        if appState.moodEntries.isEmpty {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            EmotionAIInsightCard(
                insight: emotionalAIInsight,
                stabilityScore: stabilityScore,
                dominantEmotion: recentDominantEmotion
            )
        )
    }
    
    // MARK: - Sélecteur d'Émotion Amélioré
    private var improvedEmotionSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("motion"))
                .font(AppTypography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            // ✅ plus compact : 4 colonnes sur iPhone standard (adaptive)
            let cols = [GridItem(.adaptive(minimum: 78), spacing: AppSpacing.sm)]
            LazyVGrid(columns: cols, spacing: AppSpacing.sm) {
                ForEach(EmotionalState.allCases, id: \.self) { emotion in
                    EmotionCard(
                        emotion: emotion,
                        isSelected: selectedEmotion == emotion,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                        selectedEmotion = emotion
                            }
                            HapticFeedback.selection()
                        },
                        onLongPress: {
                            // Long press -> enregistrement instantané
                            HapticFeedback.medium()
                            selectedEmotion = emotion
                            notes = ""
                            showNotesField = false
                            addMood()
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Slider d'Intensité Moderne
    private var modernIntensitySlider: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(t("intensit"))
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Text("\(Int(intensity))/10")
                    .font(AppTypography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: selectedEmotion.color))
            }
            // ✅ plus ergonomique + compact
            Slider(value: $intensity, in: 1...10, step: 1)
                .tint(Color(hex: selectedEmotion.color))
                
                HStack {
                    Text(t("ai"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                    Text(t("intense"))
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Sélecteur de Contexte Moderne
    private var modernContextSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(t("contexte"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: AppSpacing.sm) {
                ForEach(MoodContext.allCases, id: \.self) { context in
                    ContextChip(
                        context: context,
                        isSelected: selectedContext == context,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedContext = context
                            }
                            HapticFeedback.selection()
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Section Notes Moderne
    private var modernNotesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(t("no"))
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Text(t("no"))
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
            TextField("Décris ce que tu ressens...", text: $notes, axis: .vertical)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                .lineLimit(2...4)
                
                if !notes.isEmpty {
                    HStack {
                        Image(systemName: "text.bubble")
                            .foregroundColor(AppColors.primary)
                        Text(t("ai"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Boutons d'Action
    private var actionButtons: some View {
        VStack(spacing: AppSpacing.md) {
            // Bouton principal
        Button(action: addMood) {
                HStack(spacing: AppSpacing.sm) {
                Image(systemName: "heart.fill")
                        .font(.title3)
                Text(t("save"))
                        .font(AppTypography.headlineSmall)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.lg)
                .background(
                    LinearGradient(
                        colors: [Color(hex: selectedEmotion.color), Color(hex: selectedEmotion.color).opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(AppRadius.large)
                .shadow(color: Color(hex: selectedEmotion.color).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(notes.isEmpty && intensity < 3)
            .scaleEffect(notes.isEmpty && intensity < 3 ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: notes.isEmpty && intensity < 3)
            
                HStack(spacing: AppSpacing.sm) {
                Button {
                    showingInsightsSheet = true
                } label: {
                    Label("Insights", systemImage: "sparkles")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.primary.opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { showingHistory = true }) {
                    Label("Historique", systemImage: "clock.arrow.circlepath")
                        .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.primary)
            .frame(maxWidth: .infinity)
                .padding(AppSpacing.md)
                .background(AppColors.cardBackground)
                .cornerRadius(AppRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.primary.opacity(0.25), lineWidth: 1)
                )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Insights Visuels
    private var visualInsightsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
            Text(t("insights"))
                    .font(AppTypography.headlineSmall)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                if !appState.moodEntries.isEmpty {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(AppColors.warning)
                }
            }
            
            if !appState.moodEntries.isEmpty {
                AsyncContentView {
                    try await moodStore.getEmotionalInsights()
                } content: { insights in
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(insights.prefix(3), id: \.self) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                }
            } else {
                EmptyInsightCard()
            }
        }
    }
    
    // MARK: - Historique Compact
    private var compactHistorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
            Text(t("dernireEntre"))
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                if !appState.moodEntries.isEmpty {
                    Button(t("history")) {
                        showingHistory = true
                    }
                    .font(AppTypography.captionSmall)
                    .foregroundColor(AppColors.primary)
                }
            }
            
            if appState.moodEntries.isEmpty {
                EmptyHistoryCard()
            } else {
                // ✅ Trié par date décroissante — affiche la plus récente
                if let last = appState.moodEntries.sorted(by: { $0.timestamp > $1.timestamp }).first {
                    MoodHistoryRow(mood: last)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func addMood() {
        let mood = MoodEntry(
            emotionalState: selectedEmotion,
            intensity: Int(intensity),
            notes: notes.isEmpty ? nil : notes,
            context: selectedContext,
            durationCategory: durationCategory,
            secondaryEmotionalState: secondaryEmotion,
            trigger: trigger,
            controlLevel: Int(controlLevel),
            checklistBeforeTrade: (selectedContext == .beforeTrade) ? checklist : nil,
            tags: tags,
            isExceptional: isExceptional,
            intention: intention,
            aiSummary: nil,
            aiSignals: nil,
            source: .manual,
            miniChecklist: (selectedContext == .beforeTrade) ? miniChecklist : nil,
            quickActions: quickActions
        )
        
        Task {
            try await moodStore.addMood(mood)
            await MainActor.run {
                appState.moodEntries = appState.moodStore.moods
            }
        }
        
        // Reset form avec animation
        withAnimation(.spring(response: 0.5)) {
        notes = ""
        intensity = 5
        selectedEmotion = .calm
        showNotesField = false
        secondaryEmotion = nil
        durationCategory = nil
        trigger = nil
        intention = nil
        controlLevel = 5
        isExceptional = false
        tags = []
        tagDraft = ""
        checklist = .empty
        miniChecklist = .empty
        quickActions = []
        }
        
        HapticFeedback.success()
    }
    
    private func loadAnalysis() async {
        let period = DateInterval(start: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(), end: Date())
        emotionalAnalysis = try? await moodStore.getEmotionalAnalysis(for: period)
    }
    
    // MARK: - Computed Properties
    private var weeklyMoodCount: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return appState.moodEntries.filter { $0.timestamp >= weekAgo }.count
    }
    
    private var averageIntensity: Double {
        guard !appState.moodEntries.isEmpty else { return 0 }
        let total = appState.moodEntries.reduce(0) { $0 + $1.intensity }
        return Double(total) / Double(appState.moodEntries.count)
    }
    
    private var recentMoods: [MoodEntry] {
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        return appState.moodEntries.filter { $0.timestamp >= twoWeeksAgo }
    }
    
    private var previousMoods: [MoodEntry] {
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        return appState.moodEntries.filter { $0.timestamp >= fourWeeksAgo && $0.timestamp < twoWeeksAgo }
    }
    
    private func computeStabilityScore(for moods: [MoodEntry]) -> Double {
        guard !moods.isEmpty else { return 50 }
        
        let intensities = moods.map { Double($0.intensity) }
        let averageIntensity = intensities.reduce(0, +) / Double(intensities.count)
        let mean = averageIntensity
        let variance = intensities.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intensities.count)
        let volatility = sqrt(variance)
        
        let positiveEmotions: Set<EmotionalState> = [.confident, .calm, .focused, .excited]
        let negativeEmotions: Set<EmotionalState> = [.stressed, .fearful, .frustrated, .impatient]
        
        let positiveRatio = Double(moods.filter { positiveEmotions.contains($0.emotionalState) }.count) / Double(moods.count)
        let negativeRatio = Double(moods.filter { negativeEmotions.contains($0.emotionalState) }.count) / Double(moods.count)
        let highIntensityNegative = Double(
            moods.filter { negativeEmotions.contains($0.emotionalState) && $0.intensity >= 7 }.count
        ) / Double(moods.count)
        
        var score = 55.0
        score += positiveRatio * 35.0
        score -= min(20.0, volatility * 4.5)
        score -= negativeRatio * 15.0
        score -= highIntensityNegative * 20.0
        score += max(0, 12 - abs(averageIntensity - 5.5) * 2)
        
        return max(0, min(100, score))
    }
    
    private var stabilityScore: Int {
        Int(round(computeStabilityScore(for: recentMoods)))
    }
    
    private var stabilityTrend: Int {
        let recent = computeStabilityScore(for: recentMoods)
        let previous = computeStabilityScore(for: previousMoods)
        return Int(round(recent - previous))
    }
    
    private var recentDominantEmotion: EmotionalState? {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = appState.moodEntries.filter { $0.timestamp >= weekAgo }
        let counts = Dictionary(grouping: recent, by: { $0.emotionalState }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    private var emotionTimelineEntries: [TimelineEntry] {
        let calendar = Calendar.current
        let days = (0..<10).compactMap { offset in
            calendar.date(byAdding: .day, value: -9 + offset, to: Date())
        }
        
        return days.map { day in
            let dayMoods = appState.moodEntries.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            let counts = Dictionary(grouping: dayMoods, by: { $0.emotionalState }).mapValues { $0.count }
            let dominantEmotion = counts.max(by: { $0.value < $1.value })?.key
            let averageIntensity = dayMoods.isEmpty ? 0 : Double(dayMoods.reduce(0) { $0 + $1.intensity }) / Double(dayMoods.count)
            return TimelineEntry(date: day, dominantEmotion: dominantEmotion, averageIntensity: averageIntensity)
        }
    }
    
    private var emotionTrendData: [TrendPoint] {
        emotionTimelineEntries
            .filter { $0.averageIntensity > 0 }
            .map { TrendPoint(date: $0.date, averageIntensity: $0.averageIntensity, emotion: $0.dominantEmotion) }
    }
    
    private var emotionalAIInsight: String {
        guard !recentMoods.isEmpty else {
            return "Commence à noter tes émotions quotidiennement pour permettre au Coach IA de détecter des schémas exploitables."
        }
        
        let score = stabilityScore
        let trend = stabilityTrend
        let dominant = recentDominantEmotion
        let positiveEmotions: Set<EmotionalState> = [.confident, .calm, .focused, .excited]
        let positiveRatio = Double(recentMoods.filter { positiveEmotions.contains($0.emotionalState) }.count) / Double(recentMoods.count)
        
        if score >= 80 {
            return "Ta stabilité émotionnelle est excellente (\(score)/100). Continue ta routine actuelle : ton ratio d’émotions positives (\(Int(positiveRatio * 100))%) se reflète dans tes décisions."
        }
        
        if score <= 45 {
            if let dominant, [.stressed, .fearful].contains(dominant) {
                return "Tu traverses une zone sensible : \(dominant.displayName.lowercased()) revient souvent et ton score de stabilité tombe à \(score). Planifie une pause ou réduis le levier avant les prochaines sessions."
            }
            return "Ton score de stabilité est en baisse (\(score)/100). Identifie le contexte qui déclenche les émotions fortes et programme une routine de reset avant de trader."
        }
        
        if trend > 5 {
            return "Belle amélioration émotionnelle : ton score progresse de \(trend) points. Capitalise sur cette dynamique en gardant le même rituel avant session."
        }
        
        if trend < -5 {
            return "Ton équilibre émotionnel recule de \(abs(trend)) points. Reviens aux fondamentaux (respiration, plan écrit) pour éviter que cela ne se traduise sur le P&L."
        }
        
        if let dominant {
            return "Tu es principalement \(dominant.displayName.lowercased()) ces derniers jours. Profite-en pour noter ce qui fonctionne lorsque tu es dans cet état et identifie ce qui le perturbe."
        }
        
        return "Continue à suivre tes ressentis : tes émotions restent globalement équilibrées. Ajoute une note rapide après chaque trade pour enrichir ton historique."
    }

    private func repeatLastEntry() {
        guard let last = appState.moodEntries.sorted(by: { $0.timestamp > $1.timestamp }).first else { return }
        HapticFeedback.medium()
        // Repeat quickly: same emotion/intensity/context/trigger, keep options light.
        selectedEmotion = last.emotionalState
        intensity = Double(last.intensity)
        selectedContext = last.context
        trigger = last.trigger
        notes = ""
        // Enregistrer directement
        addMood()
    }
}

// MARK: - UI bits
private struct TriggerChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(AppTypography.captionMedium)
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .black : AppColors.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? AppColors.primary : AppColors.cardBackground)
                        .overlay(Capsule().stroke(AppColors.primary.opacity(0.18), lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

private struct ToggleChip: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn ? AppColors.success : AppColors.textSecondary)
                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isOn ? 0.10 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isOn ? AppColors.success.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TimelineEntry: Identifiable {
    let id = UUID()
    let date: Date
    let dominantEmotion: EmotionalState?
    let averageIntensity: Double
    
    var emoji: String {
        dominantEmotion?.emoji ?? "•"
    }
    
    var color: Color {
        if let emotion = dominantEmotion {
            return Color(hex: emotion.color)
        }
        return AppColors.textSecondary
    }
}

private struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let averageIntensity: Double
    let emotion: EmotionalState?
}

// MARK: - Emotion Card
struct EmotionCard: View {
    let emotion: EmotionalState
    let isSelected: Bool
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(emotion.emoji)
                    .font(.system(size: 22))
                
                Text(emotion.displayName)
                    .font(AppTypography.captionSmall)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isSelected ? Color(hex: emotion.color) : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                    )
            )
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.35) {
            onLongPress?()
        }
    }
}

// MARK: - Context Chip
struct ContextChip: View {
    let context: MoodContext
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: contextIcon)
                    .font(.title3)
                
                Text(context.displayName)
                    .font(AppTypography.captionSmall)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, AppSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isSelected ? AppColors.primary : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(isSelected ? Color.clear : AppColors.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var contextIcon: String {
        switch context {
        case .beforeTrade: return "arrow.up.circle"
        case .afterTrade: return "arrow.down.circle"
        case .duringMarket: return "chart.line.uptrend.xyaxis"
        case .afterLoss: return "minus.circle"
        case .afterWin: return "plus.circle"
        case .endOfDay: return "sunset"
        }
    }
}

private struct EmotionalStabilityCard: View {
    let score: Int
    let trend: Int
    let dominantEmotion: EmotionalState?
    
    private var trendText: String {
        if trend > 0 { return "+\(trend) pts" }
        if trend < 0 { return "\(trend) pts" }
        return "Stable"
    }
    
    private var trendColor: Color {
        if trend > 0 { return AppColors.success }
        if trend < 0 { return AppColors.error }
        return AppColors.textSecondary
    }
    
    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .stroke(AppColors.border.opacity(0.3), lineWidth: 10)
                    .frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 90, height: 90)
                    .animation(.easeInOut(duration: 0.4), value: score)
                
                VStack(spacing: 4) {
                    Text(t("score"))
                        .font(AppTypography.headlineSmall)
                        .fontWeight(.bold)
                    Text(t("100"))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(t("stabilitmotionnelle"))
                    .font(AppTypography.headlineSmall)
                    .foregroundColor(AppColors.textPrimary)
                
                if let dominantEmotion {
                    HStack(spacing: 6) {
                        Text(dominantEmotion.emoji)
                        Text(t("name"))
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Text(trendText)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(trendColor)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, 4)
                    .background(trendColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Spacer()
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

private struct EmotionTimelineView: View {
    let entries: [TimelineEntry]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(t("timelineDes10DerniersJours"))
                    .font(AppTypography.headlineSmall)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(entries) { entry in
                        EmotionTimelineItem(
                            emoji: entry.emoji,
                            dateLabel: dateFormatter.string(from: entry.date),
                            intensity: entry.averageIntensity,
                            color: entry.color
                        )
                    }
                }
                .padding(.vertical, AppSpacing.xs)
            }
        }
    }
}

private struct EmotionTimelineItem: View {
    let emoji: String
    let dateLabel: String
    let intensity: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(dateLabel)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
            
            Text(emoji)
                .font(.system(size: 26))
            
            ProgressView(value: min(max(intensity / 10, 0), 1))
                .tint(color)
                .frame(width: 48)
            
            Text(String(format: "%.1f/10", intensity))
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(AppSpacing.sm)
        .frame(width: 72)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(color.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

private struct EmotionTrendChartSection: View {
    let points: [TrendPoint]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("volutionDeLintensit"))
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            Chart {
                ForEach(points) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Intensité", point.averageIntensity)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppColors.accent.opacity(0.4), AppColors.accent.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Intensité", point.averageIntensity)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(AppColors.accent)
                    .lineStyle(.init(lineWidth: 2.5))
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Intensité", point.averageIntensity)
                    )
                    .foregroundStyle(AppColors.accent)
                    .symbolSize(50)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                        .foregroundStyle(AppColors.border.opacity(0.2))
                    if let date = value.as(Date.self) {
                        AxisValueLabel(dateFormatter.string(from: date))
                            .font(AppTypography.captionSmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [2, 4, 6, 8, 10]) { value in
                    AxisGridLine()
                        .foregroundStyle(AppColors.border.opacity(0.2))
                    AxisValueLabel {
                        Text("\(value.as(Int.self) ?? 0)")
                            .font(AppTypography.captionSmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .frame(height: 200)
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
    }
}

private struct EmotionAIInsightCard: View {
    let insight: String
    let stabilityScore: Int
    let dominantEmotion: EmotionalState?
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppColors.accent)
                Text(t("ai"))
                    .font(AppTypography.headlineSmall)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(insight)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: AppSpacing.sm) {
                Label("\(stabilityScore)/100", systemImage: "shield")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.primary)
                
                if let dominantEmotion {
                    Label(dominantEmotion.displayName, systemImage: "face.smiling")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(Color(hex: dominantEmotion.color))
                }
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Stat Chip
struct StatChip: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppTypography.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.sm)
        .background(AppColors.cardBackground)
        .cornerRadius(AppRadius.small)
    }
}

// MARK: - Insight Card
private struct InsightCard: View {
    let insight: String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(AppColors.warning)
                .font(.caption)
            
            Text(insight)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.warning.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.warning.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Empty Insight Card
struct EmptyInsightCard: View {
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "heart.text.square")
                .font(.title2)
                .foregroundColor(AppColors.textSecondary)
            
            Text(t("save"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Compact Mood Row
struct CompactMoodRow: View {
    let mood: MoodEntry
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(mood.emotionalState.emoji)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(mood.emotionalState.displayName)
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(Color(hex: mood.emotionalState.color))
                
                Text(mood.context.displayName)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(mood.intensity)/10")
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: mood.emotionalState.color))
                
                Text(mood.timestamp, style: .relative)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                HapticFeedback.error()
                showDeleteConfirmation = true
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            
            Button {
                HapticFeedback.medium()
                showEditSheet = true
            } label: {
                Label("Modifier", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .alert("Supprimer l'émotion", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                deleteMood()
            }
        } message: {
            Text(t("delete"))
        }
        .sheet(isPresented: $showEditSheet) {
            EditMoodView(mood: mood)
        }
    }
    
    private func deleteMood() {
        Task {
            try await appState.moodStore.deleteMood(mood.id)
        }
        HapticFeedback.success()
    }
}

// MARK: - Empty History Card
struct EmptyHistoryCard: View {
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "clock.badge.questionmark")
                .font(.title2)
                .foregroundColor(AppColors.textSecondary)
            
            Text(t("aucuntatEnregistr"))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Emotional History View
struct EmotionalHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            List {
                if filteredMoods.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.title2)
                            .foregroundColor(AppColors.textSecondary)
                        Text(t("aucuneEntre"))
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredMoods) { mood in
                        MoodHistoryRow(mood: mood)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    HapticFeedback.error()
                                    Task { try? await appState.moodStore.deleteMood(mood.id) }
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle(t("history"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t("close")) { dismiss() }
                        .foregroundColor(AppColors.primary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Rechercher (tag, note)…")
    }

    private var filteredMoods: [MoodEntry] {
        let sorted = appState.moodEntries.sorted { $0.timestamp > $1.timestamp }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { mood in
            if mood.summaryLine.localizedCaseInsensitiveContains(q) { return true }
            if let notes = mood.notes, notes.localizedCaseInsensitiveContains(q) { return true }
            if mood.tags.contains(where: { $0.localizedCaseInsensitiveContains(q) }) { return true }
            return false
        }
    }
}

// MARK: - Row (summaryLine)
private struct MoodHistoryRow: View {
    let mood: MoodEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(mood.emotionalState.emoji)
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(mood.summaryLine)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)

                    if mood.isExceptional {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.warning)
                    }
                }

                if !mood.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(mood.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(AppTypography.captionSmall)
                                .foregroundColor(AppColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.white.opacity(0.06)))
                        }
                    }
                } else if let notes = mood.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(mood.timestamp, style: .relative)
                .font(AppTypography.captionSmall)
                .foregroundColor(AppColors.textTertiary)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

// MARK: - Mood Entry Row (Legacy)
struct MoodEntryRow: View {
    let mood: MoodEntry
    
    var body: some View {
        HStack {
            Text(mood.emotionalState.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(mood.emotionalState.displayName)
                    .font(.headline)
                    .foregroundColor(Color(hex: mood.emotionalState.color))
                
                Text(mood.context.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let notes = mood.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(mood.intensity)/10")
                    .font(.headline)
                    .foregroundColor(Color(hex: mood.emotionalState.color))
                
                Text(mood.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Async Content View
struct AsyncContentView<Content: View>: View {
    let action: () async throws -> [String]
    @ViewBuilder let content: ([String]) -> Content
    
    @State private var data: [String] = []
    @State private var isLoading = true
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Chargement...")
            } else if let error = error {
                Text(t("error"))
                    .foregroundColor(AppColors.error)
            } else {
                content(data)
            }
        }
        .task {
            do {
                data = try await action()
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
}

// MARK: - Edit Mood View
struct EditMoodView: View {
    let mood: MoodEntry
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var selectedEmotion: EmotionalState
    @State private var intensity: Double
    @State private var notes: String
    @State private var selectedContext: MoodContext
    
    init(mood: MoodEntry) {
        self.mood = mood
        self._selectedEmotion = State(initialValue: mood.emotionalState)
        self._intensity = State(initialValue: Double(mood.intensity))
        self._notes = State(initialValue: mood.notes ?? "")
        self._selectedContext = State(initialValue: mood.context)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text(t("edit"))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(mood.timestamp, style: .date)
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    .padding(.top)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Emotion Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("motion"))
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                ForEach(EmotionalState.allCases, id: \.self) { emotion in
                                    EmotionCard(
                                        emotion: emotion,
                                        isSelected: selectedEmotion == emotion,
                                        onTap: {
                                            selectedEmotion = emotion
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Intensity
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("intensit"))
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Text("1")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(Int(intensity))/10")
                                        .font(.headline)
                                        .foregroundColor(Color(hex: selectedEmotion.color))
                                    Spacer()
                                    Text("10")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Slider(value: $intensity, in: 1...10, step: 1)
                                    .accentColor(Color(hex: selectedEmotion.color))
                            }
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                        // Context
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("contexte"))
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                ForEach(MoodContext.allCases, id: \.self) { context in
                                    ContextChip(
                                        context: context,
                                        isSelected: selectedContext == context,
                                        onTap: {
                                            selectedContext = context
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("no"))
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Ajoutez des notes...", text: $notes, axis: .vertical)
                                .textFieldStyle(CustomTextFieldStyle())
                                .lineLimit(3...6)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button(t("cancel")) {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button(t("save")) {
                            saveMood()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
    }
    
    private func saveMood() {
        // Créer une nouvelle instance avec le même ID que l'original
        let moodWithSameId = MoodEntry(
            id: mood.id,
            tradeId: mood.tradeId,
            emotionalState: selectedEmotion,
            intensity: Int(intensity),
            notes: notes.isEmpty ? nil : notes,
            context: selectedContext,
            timestamp: mood.timestamp
        )
        
        Task {
            try await appState.moodStore.updateMood(moodWithSameId)
        }
        
        HapticFeedback.success()
        dismiss()
    }
}

#Preview {
    EmotionalJournalView()
}

// MARK: - Button Styles
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            .foregroundColor(AppColors.textPrimary)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
            )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Plus d'options (sheet)
private struct EmotionalMoreOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedContext: MoodContext
    @Binding var notes: String
    @Binding var secondaryEmotion: EmotionalState?
    @Binding var durationCategory: MoodDurationCategory?
    @Binding var trigger: MoodTrigger?
    @Binding var intention: MoodIntention?
    @Binding var controlLevel: Double
    @Binding var isExceptional: Bool
    @Binding var tags: [String]
    @Binding var tagDraft: String
    @Binding var checklist: ChecklistBeforeTrade
    @Binding var miniChecklist: MiniPreTradeChecklist

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Presets rapides
                    presets

                    if selectedContext == .beforeTrade {
                        sectionCard(title: "Pré-trade (rapide)") {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                Toggle("Plan OK", isOn: $miniChecklist.planOK)
                                    .tint(AppColors.primary)
                                Toggle("Taille OK", isOn: $miniChecklist.sizeOK)
                                    .tint(AppColors.primary)
                                Toggle("Stop défini", isOn: $miniChecklist.stopDefined)
                                    .tint(AppColors.primary)
                            }
                        }
                    }

                    sectionCard(title: "Déclencheur") {
                        pickerRow(title: "Trigger", value: trigger?.displayName ?? "—") {
                            ForEach(MoodTrigger.allCases, id: \.self) { t in
                                Button(t.displayName) { trigger = t }
                            }
                            Button("Aucun", role: .destructive) { trigger = nil }
                        }
                    }

                    sectionCard(title: "Intention") {
                        pickerRow(title: "Intention", value: intention?.displayName ?? "—") {
                            ForEach(MoodIntention.allCases, id: \.self) { i in
                                Button(i.displayName) { intention = i }
                            }
                            Button("Aucune", role: .destructive) { intention = nil }
                        }
                    }

                    sectionCard(title: "Contrôle") {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                Text(t("niveauDeContrle"))
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Text("\(Int(controlLevel))/10")
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Slider(value: $controlLevel, in: 0...10, step: 1)
                                .tint(AppColors.primary)
                        }
                    }

                    sectionCard(title: "Durée") {
                        pickerRow(title: "Durée", value: durationCategory?.displayName ?? "—") {
                            ForEach(MoodDurationCategory.allCases, id: \.self) { d in
                                Button(d.displayName) { durationCategory = d }
                            }
                            Button("Aucune", role: .destructive) { durationCategory = nil }
                        }
                    }

                    sectionCard(title: "Deuxième émotion (optionnel)") {
                        pickerRow(title: "Secondaire", value: secondaryEmotion?.displayName ?? "—") {
                            ForEach(EmotionalState.allCases, id: \.self) { e in
                                Button("\(e.emoji) \(e.displayName)") { secondaryEmotion = e }
                            }
                            Button("Aucune", role: .destructive) { secondaryEmotion = nil }
                        }
                    }

                    if selectedContext == .beforeTrade {
                        sectionCard(title: "Checklist avant trade") {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                ForEach(ChecklistBeforeTradeItem.allCases, id: \.self) { item in
                                    Toggle(item.displayName, isOn: bindingForChecklist(item))
                                        .tint(AppColors.primary)
                                }
                            }
                        }
                    }

                    sectionCard(title: "Tags") {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: 10) {
                                TextField("Ajouter un tag (ex: FOMO)", text: $tagDraft)
                                    .textFieldStyle(CustomTextFieldStyle())
                                Button(t("add")) { addTag() }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .frame(width: 110)
                            }

                            if !tags.isEmpty {
                                FlowTagsView(tags: tags) { tag in
                                    tags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
                                }
                            }
                        }
                    }

                    sectionCard(title: "Note (optionnelle)") {
                        TextField("Notes…", text: $notes, axis: .vertical)
                            .textFieldStyle(CustomTextFieldStyle())
                            .lineLimit(2...5)
                    }

                    sectionCard(title: "Marquage") {
                        Toggle("Exceptionnel", isOn: $isExceptional)
                            .tint(AppColors.primary)
                    }
                }
                .padding()
                .padding(.bottom, AppSpacing.lg)
            }
            .background(Color.black)
            .navigationTitle("Plus d’options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t("close")) { dismiss() }
                        .foregroundColor(AppColors.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") { resetOptions() }
                        .foregroundColor(AppColors.primary)
                }
            }
        }
    }

    private var presets: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("presetsRapides"))
                .font(AppTypography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            HStack(spacing: 10) {
                presetChip(title: "Perte", icon: "minus.circle") {
                    selectedContext = .afterLoss
                    trigger = .previousLoss
                    intention = .recoverLoss
                }
                presetChip(title: "Marché bouge", icon: "chart.line.uptrend.xyaxis") {
                    selectedContext = .duringMarket
                    trigger = .marketMove
                }
                presetChip(title: "Attente", icon: "hourglass") {
                    trigger = .waiting
                }
            }
        }
    }

    private func presetChip(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(AppTypography.captionMedium)
                    .fontWeight(.semibold)
            }
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .stroke(AppColors.primary.opacity(0.18), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            content()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.border.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func pickerRow(title: String, value: String, @ViewBuilder actions: () -> some View) -> some View {
        Menu {
            actions()
        } label: {
            HStack {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text(value)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func bindingForChecklist(_ item: ChecklistBeforeTradeItem) -> Binding<Bool> {
        Binding(
            get: { checklist[item] },
            set: { checklist[item] = $0 }
        )
    }

    private func addTag() {
        let trimmed = tagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            tags.append(trimmed)
        }
        tagDraft = ""
    }

    private func resetOptions() {
        secondaryEmotion = nil
        durationCategory = nil
        trigger = nil
        intention = nil
        controlLevel = 5
        isExceptional = false
        tags = []
        tagDraft = ""
        checklist = .empty
        notes = ""
    }
}

private struct FlowTagsView: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 10) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 8) {
                    Text(tag)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(.white)
                    Button {
                        onRemove(tag)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color.white.opacity(0.06))
                )
            }
        }
    }
}
