//
//  ExchangesView.swift
//  Journal de trading 2025
//

import SwiftUI

struct ExchangesView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @State private var showingAddExchange = false
    @State private var showingEditExchange = false
    @State private var selectedExchange: Exchange?
    @State private var searchText = ""
    
    var filteredExchanges: [Exchange] {
        if searchText.isEmpty {
            return appState.exchanges.sorted {
                if $0.isDefault != $1.isDefault {
                    return $0.isDefault
                }
                return $0.name < $1.name
            }
        }
        return appState.exchanges.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }.sorted {
            if $0.isDefault != $1.isDefault {
                return $0.isDefault
            }
            return $0.name < $1.name
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 16))
                    
                    TextField("Rechercher...", text: $searchText)
                        .foregroundColor(AppColors.textPrimary)
                        .font(AppTypography.bodyMedium)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.textSecondary)
                                .font(.system(size: 16))
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.cardBackground)
                )
                
                Button(action: { showingAddExchange = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(AppColors.primary.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
            
            // Exchanges list
            if filteredExchanges.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.2")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(searchText.isEmpty ? "Aucun exchange configuré" : "Aucun résultat")
                        .font(.headline)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text(searchText.isEmpty ? "Ajoutez votre premier exchange pour commencer" : "Essayez une autre recherche")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Ajouter un Exchange") {
                        showingAddExchange = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(filteredExchanges) { exchange in
                            ExchangeCardView(
                                exchange: exchange,
                                isDefault: exchange.isDefault,
                                onSetDefault: {
                                    appState.setDefaultExchange(exchange)
                                },
                                onDelete: {
                                    appState.deleteExchange(exchange)
                                },
                                onEdit: {
                                    selectedExchange = exchange
                                    showingEditExchange = true
                                }
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.sm)
                    // `TradingJournalApp` gère désormais l'espace de la bottom bar via `safeAreaInset`.
                    .padding(.bottom, AppSpacing.lg)
                }
            }
        }
        .background(Color.black)
        .sheet(isPresented: $showingAddExchange) {
            AddExchangeView()
        }
        .sheet(isPresented: $showingEditExchange) {
            if let exchange = selectedExchange {
                EditExchangeView(exchange: exchange)
            }
        }
    }
}

struct ExchangeCardView: View {
    let exchange: Exchange
    let isDefault: Bool
    let onSetDefault: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 16) {
            cardContent
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
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
                onEdit()
            } label: {
                Label("Modifier", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .alert("Supprimer l'exchange", isPresented: $showDeleteConfirmation) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                onDelete()
            }
        } message: {
            Text(t("delete"))
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 16) {
            // Exchange header
            HStack {
                // Exchange icon
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(exchange.name.prefix(1)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.primary)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(exchange.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    if isDefault {
                        Text(t("exchangeParDfaut"))
                            .font(.caption)
                            .foregroundColor(AppColors.success)
                    }
                }
                
                Spacer()

                Menu {
                    Button {
                        HapticFeedback.medium()
                        onEdit()
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }

                    Divider()

                    Button(role: .destructive) {
                        HapticFeedback.error()
                        showDeleteConfirmation = true
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.04))
                                .overlay(Circle().stroke(Color.white.opacity(0.08), lineWidth: 1))
                        )
                }
                .contentShape(Circle())
            }
            
            // Fees section with improved layout
            VStack(spacing: 12) {
                Text(t("ai"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 20) {
                    // Maker fees
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("maker"))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(String(format: "%.3f%%", exchange.makerFeeRate * 100))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 30)
                    
                    // Taker fees
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(t("taker"))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(String(format: "%.3f%%", exchange.takerFeeRate * 100))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            
            // Action button
            if !isDefault {
                Button("Définir comme prioritaire") {
                    onSetDefault()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

struct AddExchangeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var name = ""
    @State private var makerFeeRate = 0.001 // 0.1%
    @State private var takerFeeRate = 0.001 // 0.1%
    @State private var isDefault = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations Exchange") {
                    TextField("Nom de l'exchange", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Exchange par défaut", isOn: $isDefault)
                }
                
                Section("Frais de Trading") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("ai"))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("0.1", value: $makerFeeRate, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Text("%") // TODO: Traduire avec clé appropriée
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("ai"))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("0.1", value: $takerFeeRate, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Text("%") // TODO: Traduire avec clé appropriée
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button("Ajouter l'Exchange") {
                        addExchange()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle(t("newExchange"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t("cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addExchange() {
        let exchange = Exchange(
            name: name,
            makerFeeRate: makerFeeRate,
            takerFeeRate: takerFeeRate,
            isDefault: isDefault
        )
        
        appState.addExchange(exchange)
        dismiss()
    }
}


// MARK: - Edit Exchange View
struct EditExchangeView: View {
    let exchange: Exchange
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var name: String
    @State private var makerFeeRate: Double
    @State private var takerFeeRate: Double
    @State private var isDefault: Bool
    
    init(exchange: Exchange) {
        self.exchange = exchange
        self._name = State(initialValue: exchange.name)
        self._makerFeeRate = State(initialValue: exchange.makerFeeRate)
        self._takerFeeRate = State(initialValue: exchange.takerFeeRate)
        self._isDefault = State(initialValue: exchange.isDefault)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations Exchange") {
                    TextField("Nom de l'exchange", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("Exchange par défaut", isOn: $isDefault)
                }
                
                Section("Frais de Trading") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("ai"))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("0.1", value: $makerFeeRate, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Text("%") // TODO: Traduire avec clé appropriée
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("ai"))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        HStack {
                            TextField("0.1", value: $takerFeeRate, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Text("%") // TODO: Traduire avec clé appropriée
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    Button("Enregistrer les modifications") {
                        saveExchange()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .navigationTitle(t("editExchange"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(t("cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveExchange() {
        var updatedExchange = exchange
        updatedExchange.name = name
        updatedExchange.makerFeeRate = makerFeeRate
        updatedExchange.takerFeeRate = takerFeeRate
        updatedExchange.isDefault = isDefault
        
        appState.updateExchange(updatedExchange)
        dismiss()
    }
}

#Preview {
    ExchangesView()
        .environmentObject(AppState())
}
