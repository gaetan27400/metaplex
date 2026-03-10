//
//  StorageSettingsView.swift
//  Journal de trading 2025
//

import SwiftUI

struct StorageSettingsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @State private var showingMigrationWizard = false
    @State private var selectedMode: StorageMode = .local
    @State private var showingExportImport = false
    
    private var isFirebaseReady: Bool {
        FirebaseAvailability.isConfigured
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Storage Mode Section
                storageModeSection
                
                // Migration Section
                migrationSection
                
                // Information Section
                informationSection
                
                // Export/Import Section
                exportImportSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(t("storage"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingMigrationWizard) {
                MigrationWizardView(
                    currentMode: appState.storageMode,
                    targetMode: selectedMode
                )
            }
            .sheet(isPresented: $showingExportImport) {
                DataExportImportView()
                    .environmentObject(appState)
            }
            .onAppear {
                selectedMode = appState.storageMode
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Storage Mode Section
    
    private var storageModeSection: some View {
        Section(header: Text(t("modeDeStockage")), footer: Text(t("choisissezEntreLeStockageLocalprivOuFirebasesynchronis"))) {
            Picker("Mode actuel", selection: $selectedMode) {
                ForEach(StorageMode.allCases) { mode in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.displayName)
                            .font(.headline)
                        
                        Text(modeDescription(mode))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            if selectedMode == .firebase && !isFirebaseReady {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Firebase non configuré", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.headline)
                    
                    Text(t("ai"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }
            
            if selectedMode != appState.storageMode {
                Button("Appliquer les changements") {
                    showingMigrationWizard = true
                }
                .disabled(selectedMode == .firebase && !isFirebaseReady)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Migration Section
    
    private var migrationSection: some View {
        Section(header: Text(t("migration")), footer: Text(t("add"))) {
            VStack(alignment: .leading, spacing: 12) {
                Text(t("migrationDesDonnes"))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(t("migrezVosDonnesEntreLesDiffrentsModesDeStockageCetteOprationPeutPrendreQuelquesMinutes"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Button("Local → Firebase") {
                        selectedMode = .firebase
                        showingMigrationWizard = true
                    }
                    .disabled(!isFirebaseReady)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                    
                    Button("Firebase → Local") {
                        selectedMode = .local
                        showingMigrationWizard = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
            
            if appState.isMigrating {
                VStack(spacing: 8) {
                    ProgressView(value: appState.migrationProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    Text(appState.migrationStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Export/Import Section
    
    private var exportImportSection: some View {
        Section(
            header: Text(t("sauvegardeEtRestauration")),
            footer: Text(t("save"))
        ) {
            Button(action: { showingExportImport = true }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("exportImport"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(t("save"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
    
    // MARK: - Information Section
    
    private var informationSection: some View {
        Section(header: Text(t("informations")), footer: Text(t("cesStatistiquesVousDonnentUneVueDensembleDeVosDonnesStockes"))) {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    title: "Mode actuel",
                    value: appState.storageMode.displayName,
                    icon: "internaldrive"
                )
                
                InfoRow(
                    title: "Trades",
                    value: "\(appState.trades.count)",
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                InfoRow(
                    title: "Exchanges",
                    value: "\(appState.exchanges.count)",
                    icon: "building.2"
                )
                
                InfoRow(
                    title: "Systèmes",
                    value: "\(appState.systems.count)",
                    icon: "gear"
                )
                
                InfoRow(
                    title: "Alertes",
                    value: "\(appState.alerts.count)",
                    icon: "bell"
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func modeDescription(_ mode: StorageMode) -> String {
        switch mode {
        case .local:
            return "Stockage local uniquement sur cet appareil"
        case .firebase:
            return "Synchronisation avec Firebase et autres appareils"
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Migration Wizard

struct MigrationWizardView: View {
    let currentMode: StorageMode
    let targetMode: StorageMode
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text(t("migrationDesDonnes"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(t("name"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Migration details
                VStack(alignment: .leading, spacing: 16) {
                    Text(t("donnesMigrer"))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        MigrationItem(
                            title: "Trades",
                            count: appState.trades.count,
                            icon: "chart.line.uptrend.xyaxis"
                        )
                        
                        MigrationItem(
                            title: "Exchanges",
                            count: appState.exchanges.count,
                            icon: "building.2"
                        )
                        
                        MigrationItem(
                            title: "Systèmes",
                            count: appState.systems.count,
                            icon: "gear"
                        )
                        
                        MigrationItem(
                            title: "Alertes",
                            count: appState.alerts.count,
                            icon: "bell"
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Progress
                if appState.isMigrating {
                    VStack(spacing: 12) {
                        ProgressView(value: appState.migrationProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        
                        Text(appState.migrationStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    if !appState.isMigrating {
                        Button("Commencer la Migration") {
                            Task {
                                await appState.switchStorageMode(to: targetMode)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(t("cancel")) {
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.dark)
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Migration Item

struct MigrationItem: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    StorageSettingsView()
        .environmentObject(AppState())
}