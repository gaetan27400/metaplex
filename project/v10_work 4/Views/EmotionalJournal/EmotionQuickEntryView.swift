//
//  EmotionQuickEntryView.swift
//  Journal de trading 2025
//
//  Saisie rapide d'émotion depuis le menu +
//  ✅ Utilise appState.moodStore (même store que EmotionalJournalView)
//  ✅ Interface identique : mêmes émotions, mêmes contextes, mêmes options
//

import SwiftUI

struct EmotionQuickEntryView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // ✅ Mêmes champs que EmotionalJournalView
    @State private var selectedEmotion: EmotionalState = .calm
    @State private var intensity: Double = 5
    @State private var selectedContext: MoodContext = .beforeTrade
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var showSuccess = false
    
    // ✅ Champs avancés (identiques à EmotionalJournalView)
    @State private var secondaryEmotion: EmotionalState? = nil
    @State private var durationCategory: MoodDurationCategory? = nil
    @State private var trigger: MoodTrigger? = nil
    @State private var intention: MoodIntention? = nil
    @State private var controlLevel: Double = 5
    @State private var isExceptional: Bool = false
    @State private var tags: [String] = []
    @State private var checklist: ChecklistBeforeTrade = .empty
    @State private var miniChecklist: MiniPreTradeChecklist = .empty
    @State private var quickActions: [MoodQuickActionEvent] = []
    @State private var showNotesField: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header
                    VStack(spacing: AppSpacing.sm) {
                        Text(selectedEmotion.emoji)
                            .font(.system(size: 60))
                        
                        Text(t("ajouterUneEmotion"))
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text(t("enregistrezVotretatmotionnelActuel"))
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, AppSpacing.lg)
                    
                    // ✅ Sélection d'émotion — IDENTIQUE à EmotionalJournalView (grille avec tous les EmotionalState)
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(t("motion"))
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.textSecondary)
                        
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
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // ✅ Intensité — IDENTIQUE
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Text(t("intensit"))
                                .font(AppTypography.labelMedium)
                                .foregroundColor(AppColors.textSecondary)
                            Spacer()
                            Text("\(Int(intensity))/10")
                                .font(AppTypography.titleSmall)
                                .fontWeight(.bold)
                                .foregroundColor(Color(hex: selectedEmotion.color))
                        }
                        
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
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // ✅ Contexte — TOUS les 6 contextes, identique à EmotionalJournalView
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(t("contexte"))
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.textSecondary)
                        
                        // Ligne 1 : les 3 principaux (segmented)
                        HStack(spacing: AppSpacing.sm) {
                            Picker("", selection: $selectedContext) {
                                Text(t("avant")).tag(MoodContext.beforeTrade)
                                Text(t("aprs")).tag(MoodContext.afterTrade)
                                Text(t("tuesday")).tag(MoodContext.duringMarket)
                            }
                            .pickerStyle(.segmented)
                            
                            // Menu pour les 3 autres contextes
                            Menu {
                                Button("Après une perte") {
                                    selectedContext = .afterLoss
                                    trigger = .previousLoss
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
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // ✅ Mini checklist pré-trade (identique)
                    if selectedContext == .beforeTrade {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(t("prtrade"))
                                .font(AppTypography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            HStack(spacing: 10) {
                                quickToggle(title: "Plan OK", isOn: $miniChecklist.planOK)
                                quickToggle(title: "Taille OK", isOn: $miniChecklist.sizeOK)
                                quickToggle(title: "Stop défini", isOn: $miniChecklist.stopDefined)
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                    }
                    
                    // ✅ Trigger chips — IDENTIQUES à EmotionalJournalView
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Déclencheur")
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.textSecondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([MoodTrigger.fomo, .revenge, .news, .loss, .overconfidence, .fatigue], id: \.self) { t in
                                    Button {
                                        HapticFeedback.selection()
                                        trigger = (trigger == t) ? nil : t
                                    } label: {
                                        Text(t.chipLabel)
                                            .font(AppTypography.captionMedium)
                                            .fontWeight(.semibold)
                                            .foregroundColor(trigger == t ? .black : AppColors.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(trigger == t ? AppColors.primary : AppColors.cardBackground)
                                                    .overlay(Capsule().stroke(AppColors.primary.opacity(0.18), lineWidth: 1))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // Notes (optionnel)
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Notes")
                            .font(AppTypography.labelMedium)
                            .foregroundColor(AppColors.textSecondary)
                        
                        TextField(t("options"), text: $notes, axis: .vertical)
                            .font(AppTypography.bodySmall)
                            .lineLimit(3...5)
                            .padding(AppSpacing.md)
                            .background(AppColors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(AppColors.border.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    
                    // Bouton sauvegarder
                    Button {
                        saveMood()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else if showSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                                Text(t("termin"))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.white)
                                Text(t("valider"))
                                    .foregroundColor(.white)
                            }
                        }
                        .font(AppTypography.labelLarge)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.md)
                        .background(
                            LinearGradient(
                                colors: showSuccess
                                    ? [.green, .green.opacity(0.8)]
                                    : [Color(hex: selectedEmotion.color), Color(hex: selectedEmotion.color).opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
                    }
                    .disabled(isSaving || showSuccess)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(t("ajouterUneEmotion"))
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
    
    // MARK: - Quick Toggle (identique au ToggleChip de EmotionalJournalView)
    
    private func quickToggle(title: String, isOn: Binding<Bool>) -> some View {
        Button {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.9)) {
                isOn.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn.wrappedValue ? AppColors.success : AppColors.textSecondary)
                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(isOn.wrappedValue ? 0.10 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isOn.wrappedValue ? AppColors.success.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Save (✅ utilise appState.moodStore — même store partagé)
    
    private func saveMood() {
        isSaving = true
        
        // ✅ Création identique à EmotionalJournalView.addMood()
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
            // ✅ Sauvegarde via appState.moodStore (partagé avec toute l'app)
            try? await appState.moodStore.addMood(mood)
            
            // ✅ Mettre à jour la liste locale d'AppState
            await MainActor.run {
                appState.moodEntries = appState.moodStore.moods
                
                isSaving = false
                showSuccess = true
                HapticFeedback.success()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }
}
