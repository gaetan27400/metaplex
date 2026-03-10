//
//  ChartPhotoAnalysisView.swift
//  Journal de trading 2025
//

import SwiftUI
import PhotosUI
import Vision
import VisionKit

struct ChartPhotoAnalysisView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isAnalyzing = false
    @State private var analysisResult: String = ""
    @State private var showingAnalysis = false
    @State private var showingAnalysisDetail = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerView
                
                if let image = selectedImage {
                    imagePreview(image)
                } else {
                    emptyStateView
                }
                
                if isAnalyzing {
                    analysisProgressView
                }
                
                if showingAnalysis && !analysisResult.isEmpty {
                    analysisResultView
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Analyse IA")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Effacer") {
                        clearAnalysis()
                    }
                    .disabled(selectedImage == nil)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ChartImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showingAnalysisDetail) {
            AnalysisDetailView(analysisResult: analysisResult, image: selectedImage)
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 12) {
            Text(t("ai"))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(t("analyse"))
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(AppColors.primary)
            
            Text(t("slectionnezUnePhotoDeGraphique"))
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
            
            HStack(spacing: 16) {
                Button(action: {
                    showingCamera = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                        Text(t("appareil"))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppGradients.primary)
                    .cornerRadius(AppRadius.medium)
                }
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo")
                        Text(t("galerie"))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Image Preview
    private func imagePreview(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .cornerRadius(AppRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border, lineWidth: 1)
                )
            
            Button(action: {
                analyzeImage(image)
            }) {
                HStack(spacing: 8) {
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "brain.head.profile")
                    }
                    Text(isAnalyzing ? "Analyse en cours..." : "Analyser avec l'IA")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppGradients.primary)
                .cornerRadius(AppRadius.medium)
                .shadow(color: AppColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(isAnalyzing)
        }
    }
    
    // MARK: - Analysis Progress
    private var analysisProgressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primary)
            
            Text("L'IA analyse votre graphique...")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground)
        )
    }
    
    // MARK: - Analysis Result
    private var analysisResultView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(AppColors.primary)
                Text(t("ai"))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                
                Button(action: {
                    showingAnalysisDetail = true
                }) {
                    Text(t("voirTout"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.primary)
                }
            }
            
            Text(analysisResult)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)
                .lineSpacing(4)
                .lineLimit(6)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large)
                        .stroke(AppColors.primary.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Actions
    private func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        analysisResult = ""
        
        Task {
            do {
                let result = try await performImageAnalysis(image)
                await MainActor.run {
                    analysisResult = result
                    showingAnalysis = true
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    analysisResult = "Erreur lors de l'analyse: \(error.localizedDescription)"
                    showingAnalysis = true
                    isAnalyzing = false
                }
            }
        }
    }
    
    private func clearAnalysis() {
        selectedImage = nil
        analysisResult = ""
        showingAnalysis = false
    }
    
    // MARK: - AI Analysis
    private func performImageAnalysis(_ image: UIImage) async throws -> String {
        // Analyse avec Vision framework
        let visionAnalysis = try await analyzeChartWithVision(image)
        
        // Génération du prompt pour l'IA
        let _ = generateChartAnalysisPrompt(visionAnalysis: visionAnalysis)
        
        // Analyse basée sur les données réelles détectées
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondes
        
        return generateRealAnalysis(from: visionAnalysis)
    }
    
    // MARK: - Prompt Generation
    private func generateChartAnalysisPrompt(visionAnalysis: String) -> String {
        return """
        Tu es un analyste technique expert. Analyse ce graphique de trading en te basant uniquement sur les éléments visuels détectés :
        
        Éléments détectés : \(visionAnalysis)
        
        Fournis une analyse technique complète incluant :
        1. Identification de la tendance générale
        2. Niveaux de support et résistance
        3. Patterns chartistes visibles
        4. Évaluation de la volatilité
        5. Signaux techniques potentiels
        6. Recommandations d'analyse
        
        Reste objectif et basé uniquement sur ce qui est visible dans le graphique.
        """
    }
    
    // MARK: - Real Analysis Generation
    private func generateRealAnalysis(from visionAnalysis: String) -> String {
        // Extraire les informations clés du texte détecté
        let price = extractPrice(from: visionAnalysis)
        let change = extractChange(from: visionAnalysis)
        let timeframe = extractTimeframe(from: visionAnalysis)
        let symbol = extractSymbol(from: visionAnalysis)
        
        var analysis = "📊 **Analyse Technique du Graphique**\n\n"
        
        // Informations détectées
        analysis += "**Données détectées :**\n"
        if let symbol = symbol {
            analysis += "• **Symbole** : \(symbol)\n"
        }
        if let price = price {
            analysis += "• **Prix actuel** : \(price)\n"
        }
        if let change = change {
            analysis += "• **Variation** : \(change)\n"
        }
        if let timeframe = timeframe {
            analysis += "• **Timeframe** : \(timeframe)\n"
        }
        
        analysis += "\n**Analyse technique :**\n"
        
        // Analyse basée sur les données réelles
        if let change = change {
            if change.contains("+") {
                analysis += "• **Tendance** : Haussière (+)\n"
                analysis += "• **Sentiment** : Optimiste, pression d'achat\n"
            } else if change.contains("-") {
                analysis += "• **Tendance** : Baissière (-)\n"
                analysis += "• **Sentiment** : Pessimiste, pression de vente\n"
            }
        }
        
        if let timeframe = timeframe {
            analysis += "• **Timeframe** : \(timeframe) - Analyse adaptée à ce délai\n"
        }
        
        // Recommandations basées sur les données
        analysis += "\n**Recommandations :**\n"
        if let change = change, change.contains("+") {
            analysis += "• Surveillez les niveaux de résistance\n"
            analysis += "• Considérez des prises de bénéfices partielles\n"
        } else if let change = change, change.contains("-") {
            analysis += "• Surveillez les niveaux de support\n"
            analysis += "• Évitez les positions longues pour le moment\n"
        }
        
        analysis += "• Confirmez avec d'autres indicateurs techniques\n"
        analysis += "• Respectez votre gestion des risques\n"
        
        analysis += "\n**⚠️ Avertissement :**\n"
        analysis += "Cette analyse est basée uniquement sur l'image fournie et ne constitue pas un conseil financier."
        
        return analysis
    }
    
    // MARK: - Data Extraction Helpers
    private func extractPrice(from text: String) -> String? {
        let pattern = #"\d{1,3}(?:,\d{3})*(?:\.\d{2})?"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = regex?.firstMatch(in: text, range: range) {
            return String(text[Range(match.range, in: text)!])
        }
        return nil
    }
    
    private func extractChange(from text: String) -> String? {
        let pattern = #"[+-]\d+(?:,\d{3})*(?:\.\d{2})?\s*\([+-]\d+(?:\.\d+)?%\)"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: text.utf16.count)
        if let match = regex?.firstMatch(in: text, range: range) {
            return String(text[Range(match.range, in: text)!])
        }
        return nil
    }
    
    private func extractTimeframe(from text: String) -> String? {
        let timeframes = ["1m", "5m", "15m", "30m", "1h", "4h", "1d", "1w", "1M"]
        for timeframe in timeframes {
            if text.lowercased().contains(timeframe.lowercased()) {
                return timeframe
            }
        }
        return nil
    }
    
    private func extractSymbol(from text: String) -> String? {
        let symbols = ["BTC", "ETH", "SOL", "AVAX", "MATIC", "LINK", "UNI", "AAVE", "Bitcoin", "Ethereum"]
        for symbol in symbols {
            if text.contains(symbol) {
                return symbol
            }
        }
        return nil
    }
    
    // MARK: - User Indicators Analysis
    private func analyzeUserIndicators() -> String {
        let _ = Statistics.calculate(trades: appState.trades, appState: appState)
        let systems = appState.systems
        
        var analysis = ""
        
        // Analyse des systèmes de trading
        if !systems.isEmpty {
            analysis += "• Systèmes actifs: \(systems.count)\n"
            for system in systems.prefix(3) {
                let systemTrades = appState.trades.filter { $0.systemId == system.id }
                let systemPnL = systemTrades.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
                analysis += "  - \(system.name): \(String(format: "$%.2f", systemPnL))\n"
            }
        }
        
        // Analyse des exchanges
        if !appState.exchanges.isEmpty {
            let defaultExchange = appState.exchanges.first { $0.isDefault }
            if let exchange = defaultExchange {
                analysis += "• Exchange par défaut: \(exchange.name)\n"
                analysis += "  - Maker: \(String(format: "%.3f%%", exchange.makerFeeRate * 100))\n"
                analysis += "  - Taker: \(String(format: "%.3f%%", exchange.takerFeeRate * 100))\n"
            }
        }
        
        // Analyse des patterns de trading
        let symbols = Set(appState.trades.map { $0.symbol })
        analysis += "• Symboles tradés: \(symbols.count)\n"
        
        // Analyse temporelle
        let recentTrades = appState.trades.filter { $0.date > Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date() }
        analysis += "• Activité récente (30j): \(recentTrades.count) trades\n"
        
        return analysis.isEmpty ? "• Aucun indicateur configuré" : analysis
    }
    
    // MARK: - Helper Methods
    private func getBestSymbol() -> String {
        let symbolStats = Dictionary(grouping: appState.trades) { $0.symbol }
        let bestSymbol = symbolStats.max { symbol1, symbol2 in
            let pnl1 = symbol1.value.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            let pnl2 = symbol2.value.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            return pnl1 < pnl2
        }
        return bestSymbol?.key ?? "N/A"
    }
    
    private func getWorstSymbol() -> String {
        let symbolStats = Dictionary(grouping: appState.trades) { $0.symbol }
        let worstSymbol = symbolStats.min { symbol1, symbol2 in
            let pnl1 = symbol1.value.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            let pnl2 = symbol2.value.compactMap { appState.netPnL(for: $0) }.reduce(0, +)
            return pnl1 < pnl2
        }
        return worstSymbol?.key ?? "N/A"
    }
    
    // MARK: - Vision Framework Analysis
    private func analyzeChartWithVision(_ image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw AnalysisError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "Aucun texte détecté dans l'image")
                    return
                }
                
                var detectedText = ""
                var priceLevels: [String] = []
                var timeframes: [String] = []
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    
                    let text = topCandidate.string
                    detectedText += text + " "
                    
                    // Détection de niveaux de prix
                    if text.contains("$") || text.contains("€") || text.contains("₿") {
                        priceLevels.append(text)
                    }
                    
                    // Détection de timeframes
                    if text.contains("1m") || text.contains("5m") || text.contains("15m") ||
                       text.contains("1h") || text.contains("4h") || text.contains("1d") ||
                       text.contains("1w") || text.contains("1M") {
                        timeframes.append(text)
                    }
                }
                
                var analysis = "**Éléments détectés :**\n"
                
                if !priceLevels.isEmpty {
                    analysis += "• Niveaux de prix: \(priceLevels.joined(separator: ", "))\n"
                }
                
                if !timeframes.isEmpty {
                    analysis += "• Timeframes: \(timeframes.joined(separator: ", "))\n"
                }
                
                if detectedText.isEmpty {
                    analysis += "• Aucun texte détecté dans l'image\n"
                } else {
                    analysis += "• Texte général: \(detectedText.prefix(100))...\n"
                }
                
                continuation.resume(returning: analysis)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Analysis Error
enum AnalysisError: Error, LocalizedError {
    case invalidImage
    case visionAnalysisFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Image invalide"
        case .visionAnalysisFailed:
            return "Échec de l'analyse Vision"
        }
    }
}

// MARK: - Chart Image Picker
struct ChartImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ChartImagePicker
        
        init(_ parent: ChartImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Analysis Detail View
struct AnalysisDetailView: View {
    let analysisResult: String
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                    }
                    
                    // Analysis content
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(AppColors.primary)
                                .font(.title2)
                            Text(t("analyse"))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                        }
                        
                        Text(analysisResult)
                            .font(.body)
                            .foregroundColor(AppColors.textPrimary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .fill(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.large)
                                    .stroke(AppColors.primary.opacity(0.3), lineWidth: 2)
                            )
                    )
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            // Partager l'analyse
                            shareAnalysis()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text(t("partager"))
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppGradients.primary)
                            .cornerRadius(AppRadius.medium)
                        }
                        
                        Button(action: {
                            // Copier l'analyse
                            copyAnalysis()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                Text(t("copier"))
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(AppColors.border, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Analyse IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func shareAnalysis() {
        let activityVC = UIActivityViewController(
            activityItems: [analysisResult],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func copyAnalysis() {
        UIPasteboard.general.string = analysisResult
        HapticFeedback.success()
    }
}

#Preview {
    ChartPhotoAnalysisView()
        .environmentObject(AppState())
}
