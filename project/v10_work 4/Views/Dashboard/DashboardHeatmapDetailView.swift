import SwiftUI

struct DashboardHeatmapDetailView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @ObservedObject var cache: DashboardAnalyticsCache
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                UnifiedHeatmapBlock(cache: cache)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
            }
            .navigationTitle(t("heatmap"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("close")) { dismiss() }
                }
            }
        }
    }
}


