//
//  QuickEntryView.swift
//  Journal de trading 2025
//
//  Vue de saisie rapide professionnelle pour enregistrer un trade en quelques secondes
//

import SwiftUI

struct QuickEntryView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var symbol = ""
    @State private var pnl = ""
    @State private var selectedType: TradeType = .long
    @State private var selectedExchange: UUID?
    @State private var selectedSystem: UUID?

    // ✅ Pré-trade (3 toggles visibles dans la saisie rapide)
    @State private var preTradeChecklist: MiniPreTradeChecklist = .empty
    private let emotionsCoach: EmotionsCoachProviding = LocalEmotionsCoachMock()
    
    @FocusState private var focusedField: Field?
    
    // Ajout de système
    @State private var showingAddSystem = false
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "fr"
    
    enum Field {
        case symbol, pnl
    }
    
    var recentSymbols: [String] {
        Array(Set(appState.trades.map { $0.symbol }))
            .sorted { symbol1, symbol2 in
                let count1 = appState.trades.filter { $0.symbol == symbol1 }.count
                let count2 = appState.trades.filter { $0.symbol == symbol2 }.count
                return count1 > count2
            }
            .prefix(5)
            .map { $0 }
    }
    
    var canSave: Bool {
        !symbol.isEmpty &&
        !pnl.isEmpty &&
        selectedExchange != nil &&
        selectedSystem != nil &&
        Double(pnl.replacingOccurrences(of: ",", with: ".")) != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Header
                        headerSection

                        // ✅ Pré-trade
                        preTradeMiniCard
                        
                        // Champs essentiels
                        essentialFieldsCard
                        
                        // Suggestions de symboles
                        if !recentSymbols.isEmpty && symbol.isEmpty {
                            symbolSuggestionsCard
                        }
                        
                        // Options rapides
                        quickOptionsCard
                        
                        // Bouton de sauvegarde
                        saveButtonCard
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        HapticFeedback.light()
                        dismiss()
                    }) {
                        Text(t("cancel"))
                            .foregroundColor(AppColors.textSecondary)
                            .font(AppTypography.bodyMedium)
                    }
                }
            }
            .onAppear {
                setupDefaults()
                if let last = appState.moodEntries.last,
                   let suggested = emotionsCoach.suggestedMiniChecklist(
                    emotionalState: last.emotionalState,
                    intensity: last.intensity,
                    context: .beforeTrade,
                    trigger: last.trigger
                   ) {
                    preTradeChecklist = suggested
                }
            }
            .sheet(isPresented: $showingAddSystem) {
                AddSystemView(language: Binding(
                    get: {
                        let lang = Localizable.Language(rawValue: selectedLanguage)
                        return lang ?? Localizable.Language.allCases.first!
                    },
                    set: { selectedLanguage = $0.rawValue }
                ))
                .onDisappear {
                    // Sélectionner automatiquement le dernier système créé
                    if let lastSystem = appState.systems.last {
                        selectedSystem = lastSystem.id
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(AppColors.primary)
                
                Text(t("ai"))
                    .font(AppTypography.headlineLarge)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Text(t("enregistrezUnTradeEnQuelquesSecondes"))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Essential Fields Card
    
    private var essentialFieldsCard: some View {
        VStack(spacing: AppSpacing.md) {
            // Symbole
            FormField(
                title: "Symbole",
                placeholder: "Ex: BTCUSDT",
                text: $symbol,
                icon: "chart.line.uptrend.xyaxis",
                keyboardType: .default
            )
            .focused($focusedField, equals: .symbol)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .pnl
            }
            .autocapitalization(.allCharacters)
            
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            // Type (Long/Short)
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(AppColors.primary)
                        .font(.system(size: 12))
                    
                    Text(t("type"))
                        .font(AppTypography.labelLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                HStack(spacing: AppSpacing.sm) {
                    QuickEntryTypeButton(
                        title: "Long",
                        icon: "arrow.up",
                        isSelected: selectedType == .long,
                        color: AppColors.success,
                        action: {
                            HapticFeedback.selection()
                            selectedType = .long
                        }
                    )
                    
                    QuickEntryTypeButton(
                        title: "Short",
                        icon: "arrow.down",
                        isSelected: selectedType == .short,
                        color: AppColors.error,
                        action: {
                            HapticFeedback.selection()
                            selectedType = .short
                        }
                    )
                }
            }
            
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            // P&L Net
            FormField(
                title: "P&L Net",
                placeholder: "0.00",
                text: $pnl,
                icon: "dollarsign.circle.fill",
                keyboardType: .decimalPad
            )
            .focused($focusedField, equals: .pnl)
            .submitLabel(.done)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Symbol Suggestions Card
    
    private var symbolSuggestionsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "clock.fill")
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 12))
                
                Text(t("symbolesRcents"))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(recentSymbols, id: \.self) { recentSymbol in
                        Button(action: {
                            HapticFeedback.light()
                            symbol = recentSymbol
                            focusedField = .pnl
                        }) {
                            Text(recentSymbol)
                                .font(AppTypography.labelMedium)
                                .fontWeight(.medium)
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(
                                    Capsule()
                                        .fill(AppColors.primary.opacity(0.1))
                                        .overlay(
                                            Capsule()
                                                .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xxs)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Quick Options Card
    
    private var quickOptionsCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 14))
                
                Text(t("options"))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
            }
            
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            // Exchange et Système
            HStack(spacing: AppSpacing.md) {
                PickerField(
                    title: "Exchange",
                    selection: $selectedExchange,
                    options: appState.exchanges.map { ($0.id, $0.name) },
                    icon: "building.2.fill"
                )
                
                SystemPickerField(
                    title: "Système",
                    selection: $selectedSystem,
                    systems: appState.systems,
                    icon: "chart.bar.fill",
                    onAddSystem: {
                        showingAddSystem = true
                    }
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Save Button Card
    
    private var saveButtonCard: some View {
        Button(action: {
            HapticFeedback.success()
            hideKeyboard()
            saveTrade()
        }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                
                Text(t("save"))
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(canSave ? AppColors.primary : AppColors.textTertiary)
            )
        }
        .disabled(!canSave)
        .opacity(canSave ? 1.0 : 0.5)
    }
    
    // MARK: - Helper Functions
    
    private func setupDefaults() {
        if selectedExchange == nil {
            selectedExchange = appState.exchanges.first { $0.isDefault }?.id
        }
        if selectedSystem == nil {
            selectedSystem = appState.systems.first?.id
        }
    }
    
    private func saveTrade() {
        guard let exchangeId = selectedExchange,
              let systemId = selectedSystem,
              let pnlValue = Double(pnl.replacingOccurrences(of: ",", with: ".")) else {
            return
        }
        
        // Créer un trade avec P&L direct
        let trade = Trade(
            date: Date(),
            symbol: symbol.uppercased(),
            type: selectedType,
            entryPrice: nil,
            exitPrice: nil,
            quantity: nil,
            leverage: 1.0,
            exchangeId: exchangeId,
            orderRole: .taker,
            systemId: systemId,
            session: .us,
            flashPnLNet: pnlValue
        )
        
        appState.addTrade(trade)
        dismiss()
    }

    // MARK: - Pré-trade mini checklist (Trade)
    private var preTradeMiniCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(t("prtrade"))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Button("Suggérer") {
                    HapticFeedback.selection()
                    let emotion = appState.moodEntries.last?.emotionalState ?? .calm
                    let intensity = appState.moodEntries.last?.intensity ?? 5
                    let trigger = appState.moodEntries.last?.trigger
                    if let suggested = emotionsCoach.suggestedMiniChecklist(
                        emotionalState: emotion,
                        intensity: intensity,
                        context: .beforeTrade,
                        trigger: trigger
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            preTradeChecklist = suggested
                        }
                    }
                }
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.primary)
            }

            HStack(spacing: AppSpacing.sm) {
                PreTradeToggleChip(title: "Plan OK", isOn: $preTradeChecklist.planOK)
                PreTradeToggleChip(title: "Taille OK", isOn: $preTradeChecklist.sizeOK)
                PreTradeToggleChip(title: "Stop défini", isOn: $preTradeChecklist.stopDefined)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
}

// (PreTradeToggleChip est maintenant partagé dans `Views/Trades/PreTradeToggleChip.swift`)


// MARK: - Quick Entry Type Button

struct QuickEntryTypeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                Text(title)
                    .font(AppTypography.labelMedium)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isSelected ? .white : color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1.5)
            )
        }
    }
}

