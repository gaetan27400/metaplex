//
//  DataExportImportView.swift
//  Journal de trading 2025
//
//  Vue pour exporter et importer les données de l'application
//

import SwiftUI
import UniformTypeIdentifiers

struct DataExportImportView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportError: String?
    @State private var importError: String?
    @State private var showingShareSheet = false
    @State private var showingFilePicker = false
    @State private var exportFileURL: URL?
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    
    private let exportService = DataExportImportService.shared
    
    var body: some View {
        NavigationStack {
            Form {
                // Export Section
                exportSection
                
                // Import Section
                importSection
                
                // Information Section
                informationSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(t("exportImport"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingShareSheet) {
                if let fileURL = exportFileURL {
                    ShareSheet(activityItems: [fileURL])
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Erreur", isPresented: .constant(exportError != nil || importError != nil)) {
                Button("OK") {
                    exportError = nil
                    importError = nil
                }
            } message: {
                Text(exportError ?? importError ?? "")
            }
            .alert("Succès", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    showingSuccessAlert = false
                }
            } message: {
                Text(successMessage)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        Section(
            header: Text(t("exporterLesDonnes")),
            footer: Text(t("yesterday"))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("sauvegardeComplte"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(t("toutesVosDonnesSerontExportes"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if isExporting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(t("exporting"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: exportData) {
                        HStack {
                            Image(systemName: "arrow.down.doc")
                            Text(t("exporterLesDonnes"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        Section(
            header: Text(t("importerLesDonnes")),
            footer: Text(t("yesterday"))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("restaurationComplte"))
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(t("yesterday"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if isImporting {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(t("importing"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: { showingFilePicker = true }) {
                        HStack {
                            Image(systemName: "arrow.up.doc")
                            Text(t("yesterday"))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Information Section
    
    private var informationSection: some View {
        Section(header: Text(t("statistiques"))) {
            VStack(alignment: .leading, spacing: 12) {
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
                
                InfoRow(
                    title: "États émotionnels",
                    value: "\(appState.moodEntries.count)",
                    icon: "heart.fill"
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private func exportData() {
        isExporting = true
        exportError = nil
        
        Task {
            do {
                // Récupérer toutes les données nécessaires
                var progression: Progression? = nil
                var badges: [Badge] = []
                var challenges: [Challenge] = []
                
                if let prestigeStore = appState.prestigeStore {
                    progression = try? await prestigeStore.getProgression()
                    badges = (try? await prestigeStore.getBadges()) ?? []
                }
                
                if let challengeStore = appState.challengeStore {
                    challenges = (try? await challengeStore.getAllChallenges()) ?? []
                }
                
                // Exporter vers un fichier
                let fileURL = try exportService.exportToFile(
                    trades: appState.trades,
                    exchanges: appState.exchanges,
                    systems: appState.systems,
                    alerts: appState.alerts,
                    moodEntries: appState.moodEntries,
                    progression: progression,
                    badges: badges,
                    challenges: challenges
                )
                
                await MainActor.run {
                    exportFileURL = fileURL
                    isExporting = false
                    showingShareSheet = true
                    successMessage = "Données exportées avec succès !"
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    exportError = error.localizedDescription
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importFromFile(url)
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
    
    private func importFromFile(_ fileURL: URL) {
        isImporting = true
        importError = nil
        
        Task {
            do {
                // Importer les données
                let export = try exportService.importFromFile(fileURL)
                
                // Sauvegarder dans les stores
                await saveImportedData(export)
                
                // Recharger les données depuis les stores
                appState.loadDataFromStores()
                
                await MainActor.run {
                    isImporting = false
                    successMessage = "Données importées avec succès ! \(export.trades.count) trades, \(export.systems.count) systèmes restaurés."
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importError = error.localizedDescription
                }
            }
        }
    }
    
    private func saveImportedData(_ export: AppDataExport) async {
        // Sauvegarder les trades
        for trade in export.trades {
            do {
                _ = try await appState.tradeStore.create(trade)
            } catch {
                print("❌ Erreur lors de l'import du trade \(trade.id): \(error)")
            }
        }
        
        // Sauvegarder les exchanges
        for exchange in export.exchanges {
            do {
                _ = try await appState.exchangeStore.create(exchange)
            } catch {
                print("❌ Erreur lors de l'import de l'exchange \(exchange.id): \(error)")
            }
        }
        
        // Sauvegarder les systèmes
        for system in export.systems {
            do {
                _ = try await appState.systemStore.create(system)
            } catch {
                print("❌ Erreur lors de l'import du système \(system.id): \(error)")
            }
        }
        
        // Sauvegarder les alertes
        for alert in export.alerts {
            do {
                _ = try await appState.alertStore.create(alert)
            } catch {
                print("❌ Erreur lors de l'import de l'alerte \(alert.id): \(error)")
            }
        }
        
        // Sauvegarder les mood entries
        for mood in export.moodEntries {
            do {
                try await appState.moodStore.addMood(mood)
            } catch {
                print("❌ Erreur lors de l'import du mood \(mood.id): \(error)")
            }
        }
        
        // Sauvegarder la progression
        if let progression = export.progression, let prestigeStore = appState.prestigeStore {
            do {
                // Vérifier si une progression existe déjà
                if (try? await prestigeStore.getProgression()) != nil {
                    _ = try await prestigeStore.updateProgression(progression)
                } else {
                    _ = try await prestigeStore.createProgression(progression)
                }
            } catch {
                print("❌ Erreur lors de l'import de la progression: \(error)")
            }
        }
        
        // Sauvegarder les badges
        if let prestigeStore = appState.prestigeStore {
            for badge in export.badges {
                do {
                    // Vérifier si le badge existe déjà
                    let existingBadges = (try? await prestigeStore.getBadges()) ?? []
                    if existingBadges.contains(where: { $0.id == badge.id }) {
                        _ = try await prestigeStore.updateBadge(badge)
                    } else {
                        _ = try await prestigeStore.createBadge(badge)
                    }
                } catch {
                    print("❌ Erreur lors de l'import du badge \(badge.id): \(error)")
                }
            }
        }
        
        // Sauvegarder les challenges
        if let challengeStore = appState.challengeStore {
            for challenge in export.challenges {
                do {
                    _ = try await challengeStore.createChallenge(challenge)
                } catch {
                    print("❌ Erreur lors de l'import du challenge \(challenge.id): \(error)")
                }
            }
        }
    }
}

// MARK: - Share Sheet
// Note: ShareSheet est défini dans Utils/ViewSnapshot.swift

#Preview {
    DataExportImportView()
        .environmentObject(AppState())
}

