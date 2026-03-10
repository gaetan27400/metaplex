//
//  AlertSettingsView.swift
//  Journal de trading 2025
//

import SwiftUI
import Combine

struct AlertSettingsView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @StateObject private var viewModel = AlertSettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Push Notifications Section
                pushNotificationsSection
                
                // Storage Section
                storageSection
                
                // Quiet Hours Section
                quietHoursSection
                
                // Grouping Section
                groupingSection
                
                // Default Filters Section
                defaultFiltersSection
                
                // Webhook Section
                webhookSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(t("alertSettings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.loadSettings()
        }
    }
    
    // MARK: - Push Notifications Section
    
    private var pushNotificationsSection: some View {
        Section(header: Text(t("no")), footer: Text(t("no"))) {
            Toggle("Activer les notifications", isOn: $viewModel.pushNotificationsEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            if viewModel.pushNotificationsEnabled {
                Toggle("Notifications en arrière-plan", isOn: $viewModel.backgroundNotifications)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Toggle("Son des notifications", isOn: $viewModel.notificationSound)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Toggle("Badge sur l'icône", isOn: $viewModel.notificationBadge)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
        }
    }
    
    // MARK: - Storage Section
    
    private var storageSection: some View {
        Section(header: Text(t("stockageDesAlertes")), footer: Text(t("leStockageLocalGardeVosAlertesPrivesSurCetAppareilUniquement"))) {
            Picker("Mode de stockage", selection: $viewModel.alertStorageMode) {
                ForEach(StorageMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if viewModel.alertStorageMode == .local {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("stockageLocalUniquement"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(t("lesAlertesSontStockesUniquementSurCetAppareilEllesNeSerontPasSynchronisesAvecDautresAppareils"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Quiet Hours Section
    
    private var quietHoursSection: some View {
        Section(header: Text(t("heuresSilencieuses")), footer: Text(t("pendantLesHeuresSilencieusesSeulesLesAlertesDeHautePrioritSerontEnvoyes"))) {
            Toggle("Activer les heures silencieuses", isOn: $viewModel.quietHoursEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            if viewModel.quietHoursEnabled {
                DatePicker("Début", selection: $viewModel.quietHoursStart, displayedComponents: .hourAndMinute)
                
                DatePicker("Fin", selection: $viewModel.quietHoursEnd, displayedComponents: .hourAndMinute)
                
                Toggle("Jours de semaine seulement", isOn: $viewModel.quietHoursWeekdaysOnly)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
        }
    }
    
    // MARK: - Grouping Section
    
    private var groupingSection: some View {
        Section(header: Text(t("no")), footer: Text(t("no"))) {
            Picker("Mode de regroupement", selection: $viewModel.groupingMode) {
                Text(t("ai")).tag(AlertGroupingMode.immediate)
                Text(t("rsumQuotidien")).tag(AlertGroupingMode.daily)
                Text(t("ai")).tag(AlertGroupingMode.weekly)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if viewModel.groupingMode == .daily || viewModel.groupingMode == .weekly {
                DatePicker("Heure d'envoi", selection: $viewModel.digestTime, displayedComponents: .hourAndMinute)
            }
        }
    }
    
    // MARK: - Default Filters Section
    
    private var defaultFiltersSection: some View {
        Section(header: Text(t("filtresParDfaut")), footer: Text(t("cesFiltresSerontAppliqusParDfautLorsDeLouvertureDeLaListeDesAlertes"))) {
            Toggle("Afficher seulement les non lues", isOn: $viewModel.showUnreadOnly)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            Picker("Sévérité minimale", selection: $viewModel.minimumSeverity) {
                Text(t("toutes")).tag(AlertSeverity?.none)
                ForEach(AlertSeverity.allCases, id: \.self) { severity in
                    Text(severity.displayName).tag(AlertSeverity?.some(severity))
                }
            }
            
            TextField("Symboles favoris (séparés par des virgules)", text: $viewModel.favoriteSymbols)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
    
    // MARK: - Webhook Section
    
    private var webhookSection: some View {
        Section(header: Text(t("ok")), footer: Text(t("configurezCetteUrlDansTradingviewPourRecevoirDesAlertesAutomatiquementLaClSecrteDoitCorrespondreCelleConfigureSurLeServeur"))) {
            VStack(alignment: .leading, spacing: 8) {
                Text(t("ok"))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(t("ai"))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                
                Button("Copier l'URL") {
                    UIPasteboard.general.string = "https://your-domain.com/tvWebhook"
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            SecureField("Clé secrète", text: $viewModel.webhookSecret)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}

// MARK: - Alert Grouping Mode

enum AlertGroupingMode: String, CaseIterable {
    case immediate = "immediate"
    case daily = "daily"
    case weekly = "weekly"
    
    var displayName: String {
        switch self {
        case .immediate: return "Immédiat"
        case .daily: return "Quotidien"
        case .weekly: return "Hebdomadaire"
        }
    }
}

// MARK: - View Model

class AlertSettingsViewModel: ObservableObject {
    @Published var pushNotificationsEnabled = false
    @Published var backgroundNotifications = true
    @Published var notificationSound = true
    @Published var notificationBadge = true
    @Published var alertStorageMode: StorageMode = .local
    @Published var quietHoursEnabled = false
    @Published var quietHoursStart = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    @Published var quietHoursEnd = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @Published var quietHoursWeekdaysOnly = true
    @Published var groupingMode: AlertGroupingMode = .immediate
    @Published var digestTime = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @Published var showUnreadOnly = false
    @Published var minimumSeverity: AlertSeverity? = nil
    @Published var favoriteSymbols = ""
    @Published var webhookSecret = ""
    
    func loadSettings() {
        // TODO: Load settings from UserDefaults or other storage
        pushNotificationsEnabled = UserDefaults.standard.bool(forKey: "pushNotificationsEnabled")
        alertStorageMode = StorageMode(rawValue: UserDefaults.standard.string(forKey: "alertStorageMode") ?? "local") ?? .local
        quietHoursEnabled = UserDefaults.standard.bool(forKey: "quietHoursEnabled")
        groupingMode = AlertGroupingMode(rawValue: UserDefaults.standard.string(forKey: "groupingMode") ?? "immediate") ?? .immediate
        showUnreadOnly = UserDefaults.standard.bool(forKey: "showUnreadOnly")
        favoriteSymbols = UserDefaults.standard.string(forKey: "favoriteSymbols") ?? ""
        webhookSecret = UserDefaults.standard.string(forKey: "webhookSecret") ?? ""
    }
    
    func saveSettings() {
        // TODO: Save settings to UserDefaults or other storage
        UserDefaults.standard.set(pushNotificationsEnabled, forKey: "pushNotificationsEnabled")
        UserDefaults.standard.set(alertStorageMode.rawValue, forKey: "alertStorageMode")
        UserDefaults.standard.set(quietHoursEnabled, forKey: "quietHoursEnabled")
        UserDefaults.standard.set(groupingMode.rawValue, forKey: "groupingMode")
        UserDefaults.standard.set(showUnreadOnly, forKey: "showUnreadOnly")
        UserDefaults.standard.set(favoriteSymbols, forKey: "favoriteSymbols")
        UserDefaults.standard.set(webhookSecret, forKey: "webhookSecret")
    }
}

#Preview {
    AlertSettingsView()
}