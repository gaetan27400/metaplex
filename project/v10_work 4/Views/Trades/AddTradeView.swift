//
//  AddTradeView.swift
//  Journal de trading 2025
//
//  Formulaire professionnel pour ajouter un nouveau trade
//

import SwiftUI

struct AddTradeView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var symbol = ""
    @State private var selectedType: TradeType = .long
    @State private var entryPrice = ""
    @State private var exitPrice = ""
    @State private var quantity = ""
    @State private var selectedExchange: UUID?
    @State private var selectedSystem: UUID?
    @State private var selectedSession: Session = .us
    @State private var leverage = 1.0
    @State private var leverageText = "1"
    @State private var selectedOrderRole: OrderRole = .taker
    
    // ✅ Pré-trade (visible dans saisie manuelle + rapide)
    @State private var preTradeChecklist: MiniPreTradeChecklist = .empty
    private let emotionsCoach: EmotionsCoachProviding = LocalEmotionsCoachMock()
    
    @State private var calculatedFees: Double = 0
    @State private var calculatedPnL: Double = 0
    @State private var showingCalculations = false
    
    // Mode rapide PNL
    @State private var isQuickMode = false
    @State private var quickPnL = ""
    
    // Ajout de système
    @State private var showingAddSystem = false
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "fr"
    
    var selectedExchangeData: Exchange? {
        if let exchangeId = selectedExchange {
            return appState.exchanges.first { $0.id == exchangeId }
        }
        return appState.exchanges.first { $0.isDefault }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Header
                        headerSection
                        
                        // Mode de saisie
                        modeSelectorCard

                        // ✅ Pré-trade (3 toggles)
                        preTradeMiniCard
                        
                        // Informations principales
                        mainInfoCard
                        
                        // Paramètres avancés
                        advancedSettingsCard
                        
                        // Calculs
                        if showingCalculations {
                            calculationsCard
                        }
                        
                        // Actions
                        actionButtonsCard
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(AppColors.textPrimary)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .onAppear {
                print("🔍 [AddTradeView] onAppear - Initialisation")
                print("🔍 [AddTradeView] AppState instance: \(appState === AppState.shared ? "shared ✅" : "DIFFÉRENTE ❌")")
                print("🔍 [AddTradeView] Exchanges: \(appState.exchanges.count)")
                print("🔍 [AddTradeView] Systems: \(appState.systems.count)")
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
            Text(t("add"))
                .font(AppTypography.headlineLarge)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            Text(t("enregistrezVosTransactionsDeTrading"))
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Mode Selector Card
    
    private var modeSelectorCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("ai"))
                .font(AppTypography.labelLarge)
                .foregroundColor(AppColors.textSecondary)
            
            HStack(spacing: AppSpacing.sm) {
                ModeButton(
                    title: "Classique",
                    icon: "slider.horizontal.3",
                    isSelected: !isQuickMode,
                    action: {
                        HapticFeedback.selection()
                        isQuickMode = false
                        hideKeyboard()
                    }
                )
                
                ModeButton(
                    title: "Rapide",
                    icon: "bolt.fill",
                    isSelected: isQuickMode,
                    action: {
                        HapticFeedback.selection()
                        isQuickMode = true
                        hideKeyboard()
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

    // MARK: - Pré-trade mini checklist
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
    
    // MARK: - Main Info Card
    
    private var mainInfoCard: some View {
        VStack(spacing: AppSpacing.md) {
            // Symbole
            FormField(
                title: "Symbole",
                placeholder: "BTCUSDT",
                text: $symbol,
                icon: "chart.line.uptrend.xyaxis"
            )
            
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            // Type de trade
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(t("type"))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textSecondary)
                
                HStack(spacing: AppSpacing.sm) {
                    TypeButton(
                        title: "Long",
                        icon: "arrow.up",
                        isSelected: selectedType == .long,
                        color: AppColors.success,
                        action: {
                            HapticFeedback.selection()
                            selectedType = .long
                        }
                    )
                    
                    TypeButton(
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
            
            // Prix
            if isQuickMode {
                FormField(
                    title: "P&L Net",
                    placeholder: "0.00",
                    text: $quickPnL,
                    icon: "dollarsign.circle.fill",
                    keyboardType: .decimalPad
                )
            } else {
                HStack(spacing: AppSpacing.md) {
                    FormField(
                        title: "Prix d'entrée",
                        placeholder: "0.00",
                        text: $entryPrice,
                        icon: "arrow.down.circle.fill",
                        keyboardType: .decimalPad
                    )

                    FormField(
                        title: "Prix de sortie",
                        placeholder: "0.00",
                        text: $exitPrice,
                        icon: "arrow.up.circle.fill",
                        keyboardType: .decimalPad
                    )
                }
            }
            
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            // Quantité et Levier
            VStack(spacing: AppSpacing.md) {
                FormField(
                    title: "Quantité",
                    placeholder: "0.00",
                    text: $quantity,
                    icon: "number.circle.fill",
                    keyboardType: .decimalPad
                )
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "gauge")
                            .foregroundColor(AppColors.primary)
                            .font(.system(size: 14))
                        
                        Text(t("levier"))
                            .font(AppTypography.labelLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    HStack(spacing: AppSpacing.sm) {
                        // Slider plus long (prend tout l'espace disponible)
                        Slider(value: $leverage, in: 1...100, step: 1)
                            .tint(AppColors.primary)
                            .onChange(of: leverage) { oldValue, newValue in
                                leverageText = "\(Int(newValue))"
                            }
                        
                        // Champ de saisie manuelle (compact)
                        TextField("1", text: $leverageText)
                            .keyboardType(.numberPad)
                            .font(AppTypography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primary)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 50)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.cardBackground.opacity(0.5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .onChange(of: leverageText) { oldValue, newValue in
                                // Filtrer uniquement les chiffres
                                let filtered = newValue.filter { $0.isNumber }
                                if let value = Int(filtered), value > 0 {
                                    let clampedValue = max(1, min(100, value))
                                    leverage = Double(clampedValue)
                                    if filtered != "\(clampedValue)" {
                                        leverageText = "\(clampedValue)"
                                    }
                                } else if filtered.isEmpty {
                                    leverageText = ""
                                }
                            }
                            .onSubmit {
                                if let value = Int(leverageText), value > 0 {
                                    let clampedValue = max(1, min(100, value))
                                    leverage = Double(clampedValue)
                                    leverageText = "\(clampedValue)"
                                } else {
                                    leverageText = "\(Int(leverage))"
                                }
                            }
                        
                        Text(t("exchanges"))
                            .font(AppTypography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(width: 12)
                    }
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.background)
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Advanced Settings Card
    
    private var advancedSettingsCard: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 14))
                
                Text(t("settings"))
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
            
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            // Rôle d'ordre
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(AppColors.primary)
                        .font(.system(size: 14))
                    
                    Text(t("rleDordre"))
                        .font(AppTypography.labelLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                HStack(spacing: AppSpacing.sm) {
                    RoleButton(
                        title: "Maker",
                        isSelected: selectedOrderRole == .maker,
                        action: {
                            HapticFeedback.selection()
                            selectedOrderRole = .maker
                        }
                    )
                    
                    RoleButton(
                        title: "Taker",
                        isSelected: selectedOrderRole == .taker,
                        action: {
                            HapticFeedback.selection()
                            selectedOrderRole = .taker
                        }
                    )
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Calculations Card
    
    private var calculationsCard: some View {
        CalculationsView(
            entryPrice: Double(entryPrice.replacingOccurrences(of: ",", with: ".")) ?? 0,
            exitPrice: Double(exitPrice.replacingOccurrences(of: ",", with: ".")) ?? 0,
            quantity: Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 0,
            leverage: leverage,
            exchange: selectedExchangeData,
            orderRole: selectedOrderRole,
            tradeType: selectedType
        )
    }
    
    // MARK: - Action Buttons Card
    
    private var actionButtonsCard: some View {
        VStack(spacing: AppSpacing.sm) {
            if !isQuickMode {
                Button(action: {
                    HapticFeedback.medium()
                    hideKeyboard()
                    calculateAndShowTrade()
                }) {
                    HStack {
                        Image(systemName: "calculator.fill")
                        Text(t("calculerPl"))
                    }
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .fill(AppColors.primary.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(AppColors.primary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .disabled(!canCalculate)
                .opacity(canCalculate ? 1.0 : 0.5)
            }
            
            Button(action: {
                print("🔍 [AddTradeView] Bouton 'Enregistrer' cliqué")
                print("🔍 [AddTradeView] canSave: \(canSave)")
                print("🔍 [AddTradeView] canCalculate: \(canCalculate)")
                HapticFeedback.success()
                hideKeyboard()
                saveTrade()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(t("save"))
                }
                .font(AppTypography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.primary)
                )
            }
            .disabled(!canSave)
            .opacity(canSave ? 1.0 : 0.5)
        }
    }
    
    // MARK: - Helper Functions
    
    private var canCalculate: Bool {
        return !symbol.isEmpty &&
               !entryPrice.isEmpty &&
               !exitPrice.isEmpty &&
               !quantity.isEmpty &&
               selectedExchange != nil &&
               selectedSystem != nil
    }
    
    private var canSave: Bool {
        if isQuickMode {
            return !symbol.isEmpty &&
                   !quickPnL.isEmpty &&
                   selectedExchange != nil &&
                   selectedSystem != nil
        } else {
            // Permettre l'enregistrement si tous les champs requis sont remplis
            // Les calculs seront faits automatiquement dans saveTrade()
            return canCalculate
        }
    }
    
    private func setupDefaults() {
        print("🔍 [AddTradeView] setupDefaults() appelé")
        leverageText = "\(Int(leverage))"
        print("🔍 [AddTradeView] Exchanges disponibles: \(appState.exchanges.count)")
        print("🔍 [AddTradeView] Systems disponibles: \(appState.systems.count)")
        
        if selectedExchange == nil {
            selectedExchange = appState.exchanges.first { $0.isDefault }?.id
            print("🔍 [AddTradeView] selectedExchange initialisé: \(selectedExchange?.uuidString ?? "nil")")
        }
        if selectedSystem == nil {
            selectedSystem = appState.systems.first?.id
            print("🔍 [AddTradeView] selectedSystem initialisé: \(selectedSystem?.uuidString ?? "nil")")
        }
    }
    
    private func calculateTrade() {
        guard let entry = parseDecimalString(entryPrice),
              let exit = parseDecimalString(exitPrice),
              let qty = parseDecimalString(quantity),
              let exchange = selectedExchangeData else { return }
        
        let notional = entry * qty * leverage
        let feeRate = selectedOrderRole == .maker ? exchange.makerFeeRate : exchange.takerFeeRate
        let fees = notional * feeRate
        
        let grossPnL = (exit - entry) * qty * leverage
        let netPnL = grossPnL - fees
        
        calculatedFees = fees
        calculatedPnL = netPnL
        showingCalculations = true
    }
    
    private func saveTrade() {
        print("🔍 [AddTradeView] saveTrade() appelé")
        print("🔍 [AddTradeView] selectedExchange: \(selectedExchange?.uuidString ?? "nil")")
        print("🔍 [AddTradeView] selectedSystem: \(selectedSystem?.uuidString ?? "nil")")
        print("🔍 [AddTradeView] symbol: '\(symbol)'")
        print("🔍 [AddTradeView] entryPrice: '\(entryPrice)'")
        print("🔍 [AddTradeView] exitPrice: '\(exitPrice)'")
        print("🔍 [AddTradeView] quantity: '\(quantity)'")
        print("🔍 [AddTradeView] isQuickMode: \(isQuickMode)")
        
        guard let exchangeId = selectedExchange,
              let systemId = selectedSystem else {
            print("❌ [AddTradeView] ERREUR: selectedExchange ou selectedSystem est nil")
            print("❌ [AddTradeView] Exchanges disponibles: \(appState.exchanges.map { $0.name })")
            print("❌ [AddTradeView] Systems disponibles: \(appState.systems.map { $0.name })")
            return
        }
        
        let trade: Trade
        
        if isQuickMode {
            guard let pnl = parseDecimalString(quickPnL) else { return }
            let qty = parseDecimalString(quantity) ?? 1.0
            let basePrice = 50000.0
            let entry = basePrice
            let exit = basePrice + (pnl / qty)
            
            trade = Trade(
                date: Date(),
                symbol: symbol.uppercased(),
                type: selectedType,
                entryPrice: entry,
                exitPrice: exit,
                quantity: qty,
                leverage: leverage,
                exchangeId: exchangeId,
                orderRole: selectedOrderRole,
                systemId: systemId,
                session: selectedSession,
                flashPnLNet: pnl
            )
        } else {
            guard let entry = parseDecimalString(entryPrice),
                  let exit = parseDecimalString(exitPrice),
                  let qty = parseDecimalString(quantity) else {
                print("❌ [AddTradeView] ERREUR: Impossible de parser entryPrice ou quantity")
                print("❌ [AddTradeView] entryPrice: '\(entryPrice)'")
                print("❌ [AddTradeView] quantity: '\(quantity)'")
                return
            }

            // Calculer le P&L si pas encore calculé
            let pnl: Double
            if showingCalculations {
                pnl = calculatedPnL
            } else {
                // Calculer automatiquement le P&L
                let exchange = appState.exchanges.first { $0.id == exchangeId }
                let feeTuple = PnLCalculator.fees(
                    entryPrice: entry,
                    exitPrice: exit,
                    quantity: qty,
                    makerRate: exchange?.makerFeeRate ?? 0.001,
                    takerRate: exchange?.takerFeeRate ?? 0.001,
                    role: selectedOrderRole
                )

                let grossPnL: Double
                if selectedType == .long {
                    grossPnL = (exit - entry) * qty * leverage
                } else {
                    grossPnL = (entry - exit) * qty * leverage
                }
                pnl = grossPnL - feeTuple.total
            }

            trade = Trade(
                date: Date(),
                symbol: symbol.uppercased(),
                type: selectedType,
                entryPrice: entry,
                exitPrice: exit,
                quantity: qty,
                leverage: leverage,
                exchangeId: exchangeId,
                orderRole: selectedOrderRole,
                systemId: systemId,
                session: selectedSession,
                flashPnLNet: pnl,
                status: .closed,
                currentPrice: nil,
                lastPriceUpdate: nil,
                closedAt: Date()
            )
        }
        
        print("💾 [AddTradeView] Début de la sauvegarde du trade: \(trade.symbol)")
        print("🔍 [AddTradeView] AppState instance: \(appState === AppState.shared ? "shared ✅" : "DIFFÉRENTE ❌")")
        print("🔍 [AddTradeView] Nombre de trades avant ajout: \(appState.trades.count)")
        
        // Vérifier que l'AppState est bien le singleton
        guard appState === AppState.shared else {
            print("❌ [AddTradeView] ERREUR CRITIQUE: AppState n'est pas le singleton!")
            print("❌ [AddTradeView] Instance reçue: \(appState)")
            print("❌ [AddTradeView] Instance attendue: \(AppState.shared)")
            return
        }
        
        // Ajouter le trade (sauvegarde SQLite en arrière-plan)
        appState.addTrade(trade)
        
        print("🔍 [AddTradeView] Nombre de trades après ajout: \(appState.trades.count)")
        
        // Vérifier que le trade a bien été ajouté
        let tradeAdded = appState.trades.contains { $0.id == trade.id }
        if tradeAdded {
            print("✅ [AddTradeView] Trade confirmé dans appState.trades")
        } else {
            print("⚠️ [AddTradeView] Trade non trouvé dans appState.trades immédiatement après ajout")
        }
        
        // Fermer la vue immédiatement (la sauvegarde SQLite se fait en arrière-plan)
        dismiss()
    }
    
    private func parseDecimalString(_ string: String) -> Double? {
        let cleanedString = string.replacingOccurrences(of: ",", with: ".")
        return Double(cleanedString)
    }
    
    private func calculateAndShowTrade() {
        guard let entry = parseDecimalString(entryPrice),
              let exit = parseDecimalString(exitPrice),
              let qty = parseDecimalString(quantity),
              let exchange = selectedExchangeData else {
            return
        }
        
        // Calculer les frais et le P&L
        let feeTuple = PnLCalculator.fees(
            entryPrice: entry,
            exitPrice: exit,
            quantity: qty,
            makerRate: exchange.makerFeeRate,
            takerRate: exchange.takerFeeRate,
            role: selectedOrderRole
        )
        
        let grossPnL: Double
        if selectedType == .long {
            grossPnL = (exit - entry) * qty * leverage
        } else {
            grossPnL = (entry - exit) * qty * leverage
        }
        
        calculatedFees = feeTuple.total
        calculatedPnL = grossPnL - feeTuple.total
        showingCalculations = true
        
        HapticFeedback.success()
    }
}

// MARK: - Supporting Views


struct ModeButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
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
            .foregroundColor(isSelected ? .white : AppColors.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isSelected ? AppColors.primary : AppColors.primary.opacity(0.1))
            )
        }
    }
}

struct TypeButton: View {
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
        }
    }
}

struct RoleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.labelMedium)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(isSelected ? AppColors.primary : AppColors.background)
                )
        }
    }
}

struct CalculationsView: View {
    let entryPrice: Double
    let exitPrice: Double
    let quantity: Double
    let leverage: Double
    let exchange: Exchange?
    let orderRole: OrderRole
    let tradeType: TradeType
    
    var notional: Double {
        entryPrice * quantity * leverage
    }
    
    var feeRate: Double {
        guard let exchange = exchange else { return 0 }
        return orderRole == .maker ? exchange.makerFeeRate : exchange.takerFeeRate
    }
    
    var fees: Double {
        notional * feeRate
    }
    
    var grossPnL: Double {
        (exitPrice - entryPrice) * quantity * leverage
    }
    
    var netPnL: Double {
        grossPnL - fees
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "calculator.fill")
                    .foregroundColor(AppColors.primary)
                    .font(.system(size: 14))
                
                Text(t("calculsAutomatiques"))
                    .font(AppTypography.labelLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            VStack(spacing: AppSpacing.sm) {
                CalculationRow(
                    title: "Notionnel",
                    value: String(format: "$%.2f", notional),
                    color: AppColors.textPrimary
                )
                
                CalculationRow(
                    title: "Frais (\(String(format: "%.3f%%", feeRate * 100)))",
                    value: String(format: "$%.2f", fees),
                    color: AppColors.warning
                )
                
                CalculationRow(
                    title: "P&L Brut",
                    value: String(format: "$%.2f", grossPnL),
                    color: grossPnL >= 0 ? AppColors.success : AppColors.error
                )
                
                Divider()
                    .background(AppColors.border.opacity(0.3))
                
                CalculationRow(
                    title: "P&L Net",
                    value: String(format: "$%.2f", netPnL),
                    color: netPnL >= 0 ? AppColors.success : AppColors.error,
                    isBold: true
                )
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(AppColors.background)
            )
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
}

struct CalculationRow: View {
    let title: String
    let value: String
    let color: Color
    var isBold: Bool = false
    
    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(isBold ? AppTypography.bodyMedium : AppTypography.bodySmall)
                .fontWeight(isBold ? .semibold : .regular)
                .foregroundColor(color)
        }
    }
}

