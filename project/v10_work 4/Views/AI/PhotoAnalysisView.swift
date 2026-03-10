//
//  PhotoAnalysisView.swift
//  Journal de trading 2025
//
//  Vue intégrée pour l'analyse de photos dans l'onglet IA
//  Supporte l'analyse mono-image et multi-timeframe
//

import SwiftUI
import PhotosUI
import VisionKit

struct PhotoAnalysisView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    @EnvironmentObject var appState: AppState
    
    // MARK: - State
    @State private var timeframeImages: [TimeframeImage] = []
    @State private var showingTimeframePicker = false
    @State private var selectedTimeframe: AnalysisTimeframe = .h1
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var pendingImage: UIImage?
    @State private var isAnalyzing = false
    @State private var analysisResult: ChartAnalysis?
    @State private var errorMessage: String?
    @State private var scanLineOffset: CGFloat = 0
    @State private var showFullScreenScan = false
    @State private var isGeneratingPDF = false
    @State private var photoPDFData: Data? = nil
    @State private var showPhotoPDFSheet = false
    @State private var showPhotoShareSheet = false
    
    private var isMultiMode: Bool {
        timeframeImages.count > 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header
            headerSection
            
            // Instructions
            Text(t("photoAnalysisInstructionsMulti"))
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
            
            // Sélecteur de timeframes avec images
            timeframeSelector
            
            // Boutons d'action
            actionButtons
            
            // Aperçu des images sélectionnées
            if !timeframeImages.isEmpty {
                imagePreviewGrid
            }
            
            // Indicateur d'analyse
            if isAnalyzing {
                analysingIndicator
            }
            
            // Message d'erreur
            if let error = errorMessage {
                ErrorCard(message: error)
            }
            
            // Résultats de l'analyse
            if let analysis = analysisResult {
                analysisResultsView(analysis: analysis)
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            MultiPhotoImagePicker(selectedImage: $pendingImage)
        }
        .sheet(isPresented: $showingCamera) {
            MultiPhotoCameraView(selectedImage: $pendingImage)
        }
        .sheet(isPresented: $showingTimeframePicker) {
            timeframePickerSheet
        }
        .sheet(isPresented: $showPhotoPDFSheet, onDismiss: { photoPDFData = nil }) {
            if let data = photoPDFData {
                PDFActivityView(data: data, filename: "TradeMindset_Analyse_Graphique.pdf")
            }
        }
        .sheet(isPresented: $showPhotoShareSheet) {
            if let analysis = analysisResult {
                let shareText = buildShareText(analysis: analysis)
                ShareSheet(activityItems: [shareText])
            }
        }
        .fullScreenCover(isPresented: $showFullScreenScan) {
            if let firstImage = timeframeImages.first?.image {
                scanFullScreenView(image: firstImage)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            loadSharedImage()
        }
        .onChange(of: pendingImage) { _, newValue in
            if let image = newValue {
                addImageForTimeframe(image: image, timeframe: selectedTimeframe)
                pendingImage = nil
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "camera.viewfinder")
                .font(.title2)
                .foregroundColor(.white)
                .padding(AppSpacing.sm)
                .background(
                    LinearGradient(
                        colors: [AppColors.warning, AppColors.warning.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(t("photoAnalysis"))
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                HStack(spacing: 4) {
                    Text(t("photoAnalysisTitle"))
                        .font(AppTypography.captionSmall)
                        .foregroundColor(AppColors.warning.opacity(0.8))
                    
                    if isMultiMode {
                        Text("•")
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.warning.opacity(0.5))
                        Text(t("multiTimeframeMode"))
                            .font(AppTypography.captionSmall)
                            .foregroundColor(.cyan.opacity(0.9))
                    }
                }
            }
            
            Spacer()
            
            // Badge nombre d'images
            if !timeframeImages.isEmpty {
                Text("\(timeframeImages.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(isMultiMode ? Color.cyan : AppColors.warning)
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Timeframe Selector
    
    private var timeframeSelector: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(t("selectTimeframePhoto"))
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(AnalysisTimeframe.allCases) { tf in
                        let hasImage = timeframeImages.contains { $0.timeframe == tf }
                        
                        Button(action: {
                            selectedTimeframe = tf
                            if !hasImage {
                                showingTimeframePicker = true
                            }
                        }) {
                            VStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(hasImage ? Color.cyan.opacity(0.15) : AppColors.cardBackground)
                                        .frame(width: 56, height: 42)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(
                                                    hasImage ? Color.cyan.opacity(0.6) :
                                                    selectedTimeframe == tf ? AppColors.warning.opacity(0.5) :
                                                    AppColors.border.opacity(0.3),
                                                    lineWidth: hasImage ? 1.5 : 1
                                                )
                                        )
                                    
                                    if hasImage {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.cyan)
                                    } else {
                                        Image(systemName: tf.icon)
                                            .font(.system(size: 14))
                                            .foregroundColor(
                                                selectedTimeframe == tf ? AppColors.warning : AppColors.textTertiary
                                            )
                                    }
                                }
                                
                                Text(tf.displayName)
                                    .font(.system(size: 10, weight: hasImage ? .semibold : .regular))
                                    .foregroundColor(
                                        hasImage ? .cyan :
                                        selectedTimeframe == tf ? AppColors.textPrimary :
                                        AppColors.textTertiary
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack(spacing: AppSpacing.md) {
            // Bouton ajouter photo
            Button(action: {
                showingTimeframePicker = true
            }) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "plus.circle.fill")
                    Text(t("addTimeframePhoto"))
                }
                .font(AppTypography.labelMedium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(AppSpacing.md)
                .background(
                    LinearGradient(
                        colors: [AppColors.warning, AppColors.warning.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            }
            
            // Bouton analyser (si au moins 1 image)
            if !timeframeImages.isEmpty {
                Button(action: {
                    Task { await analyzeImages() }
                }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "brain.head.profile")
                        Text(isMultiMode ? t("analyzeMulti") : t("analyzeSingle"))
                    }
                    .font(AppTypography.labelMedium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.md)
                    .background(
                        LinearGradient(
                            colors: isMultiMode ? [.cyan, .cyan.opacity(0.7)] : [AppColors.primary, AppColors.primary.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
                .disabled(isAnalyzing)
            }
        }
    }
    
    // MARK: - Image Preview Grid
    
    private var imagePreviewGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text(t("selectedImages"))
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                if timeframeImages.count > 1 {
                    Button(action: { timeframeImages.removeAll(); analysisResult = nil; errorMessage = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text(t("clearAll"))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(AppColors.error.opacity(0.8))
                    }
                }
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(timeframeImages.sorted(by: { $0.timeframe.sortOrder < $1.timeframe.sortOrder })) { tfImage in
                        VStack(spacing: 4) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: tfImage.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 70)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isAnalyzing ? Color.cyan.opacity(0.6) : AppColors.border.opacity(0.3), lineWidth: isAnalyzing ? 2 : 1)
                                    )
                                
                                // Bouton supprimer
                                Button(action: {
                                    withAnimation(.spring(response: 0.3)) {
                                        timeframeImages.removeAll { $0.id == tfImage.id }
                                        if timeframeImages.isEmpty {
                                            analysisResult = nil
                                            errorMessage = nil
                                        }
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                }
                                .offset(x: 4, y: -4)
                            }
                            
                            // Badge timeframe
                            Text(tfImage.timeframe.displayName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.8))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Message info multi-UT
            if isMultiMode {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan)
                    Text(t("multiTimeframeInfo"))
                        .font(.system(size: 11))
                        .foregroundColor(.cyan.opacity(0.8))
                }
                .padding(AppSpacing.sm)
                .background(Color.cyan.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Analysing Indicator
    
    private var analysingIndicator: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 8, height: 8)
                    .scaleEffect(scanLineOffset > 0 ? 1.3 : 0.7)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: scanLineOffset)
                
                Text(isMultiMode ? t("analyzingMultiUT") : t("analyzingSingleUT"))
                    .font(AppTypography.labelMedium)
                    .foregroundColor(.cyan)
                
                Spacer()
                
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.cyan)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                scanStep(icon: "checkmark.circle.fill", text: t("imagesLoaded"), active: true, done: true)
                if isMultiMode {
                    scanStep(icon: scanLineOffset > 0.2 ? "checkmark.circle.fill" : "circle.dotted",
                             text: t("crossReferencing"), active: true, done: scanLineOffset > 0.2)
                }
                scanStep(icon: scanLineOffset > 0.3 ? "checkmark.circle.fill" : "circle.dotted",
                         text: t("detectingPatterns"), active: true, done: scanLineOffset > 0.3)
                scanStep(icon: scanLineOffset > 0.6 ? "checkmark.circle.fill" : "circle.dotted",
                         text: t("technicalAnalysis"), active: scanLineOffset > 0.3, done: scanLineOffset > 0.6)
                if isMultiMode {
                    scanStep(icon: scanLineOffset > 0.8 ? "checkmark.circle.fill" : "circle.dotted",
                             text: t("confluenceDetection"), active: scanLineOffset > 0.6, done: scanLineOffset > 0.8)
                }
                scanStep(icon: "circle.dotted", text: t("generatingReport"),
                         active: scanLineOffset > (isMultiMode ? 0.8 : 0.6), done: false)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.cyan.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: isMultiMode ? 12 : 8).repeatForever(autoreverses: false)) {
                scanLineOffset = 1.0
            }
        }
        .onDisappear { scanLineOffset = 0 }
    }
    
    // MARK: - Analysis Results

    private func analysisResultsView(analysis: ChartAnalysis) -> some View {
        VStack(spacing: 0) {
            // ── Barre d'actions Share / PDF ───────────────────────
            HStack(spacing: 10) {
                // Bouton Partager texte
                Button(action: { shareAnalysisText(analysis: analysis) }) {
                    Label("Partager", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#FF5500"), Color(hex: "#FF8C00")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }

                // Bouton Générer PDF
                Button(action: { generatePhotoPDF(analysis: analysis) }) {
                    HStack(spacing: 6) {
                        if isGeneratingPDF {
                            ProgressView().scaleEffect(0.7).tint(.white)
                        } else {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 12))
                        }
                        Text("PDF")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#6600CC"), Color(hex: "#0066CC")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                }
                .disabled(isGeneratingPDF)

                Spacer()
            }
            .padding(.horizontal, AppSpacing.xs)
            .padding(.bottom, AppSpacing.sm)


            // ── Résultats ─────────────────────────────────────────
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    let lang = LanguageManager.shared.currentLanguage

                    // Badge multi-UT si applicable
                    if isMultiMode {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.cyan)
                            Text(t("multiTimeframeAnalysis"))
                                .font(AppTypography.labelMedium)
                                .foregroundColor(.cyan)
                            Text("(\(timeframeImages.count) \(t("utCount")))")
                                .font(AppTypography.captionSmall)
                                .foregroundColor(.cyan.opacity(0.7))
                        }
                        .padding(AppSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(Color.cyan.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                    }

                    AnalysisCard(icon: "🔎", title: Localizable.text("quickRead", language: lang), content: analysis.resume)
                    AnalysisCard(icon: "🧱", title: Localizable.text("marketStructure", language: lang), content: analysis.structure)
                    AnalysisCard(icon: "📍", title: Localizable.text("keyZones", language: lang), content: analysis.zones)
                    AnalysisCard(icon: "📈", title: Localizable.text("trendMomentum", language: lang), content: analysis.momentum)
                    AnalysisCard(icon: "🕯️", title: Localizable.text("patterns", language: lang), content: analysis.patterns)
                    AnalysisCard(icon: "📊", title: Localizable.text("indicators", language: lang), content: analysis.indicateurs)
                    AnalysisCard(icon: "🧭", title: Localizable.text("multiTimeframe", language: lang), content: analysis.mtf)

                    TradePlanCard(plan: analysis.plan, isMultiTimeframe: isMultiMode)

                    if let confluences = analysis.confluences, !confluences.isEmpty {
                        AnalysisCard(icon: "🔗", title: t("confluences"), content: confluences, accentColor: .cyan)
                    }
                    if let risques = analysis.risques, !risques.isEmpty {
                        AnalysisCard(icon: "⚠️", title: t("identifiedRisks"), content: risques, accentColor: AppColors.error)
                    }

                    AnalysisCard(icon: "🧠", title: Localizable.text("marketPsychology", language: lang), content: analysis.psychologie)

                    if let scenario = analysis.scenarioAlternatif, !scenario.isEmpty {
                        AnalysisCard(icon: "🔄", title: t("alternativeScenario"), content: scenario, accentColor: AppColors.warning)
                    }
                }
                .padding(.vertical, AppSpacing.sm)
            }
        }
    }

    // MARK: - Share & PDF Actions

    private func shareAnalysisText(analysis: ChartAnalysis) {
        showPhotoShareSheet = true
    }

    private func generatePhotoPDF(analysis: ChartAnalysis) {
        guard !isGeneratingPDF else { return }
        HapticFeedback.medium()
        isGeneratingPDF = true
        let images = timeframeImages
        Task.detached(priority: .userInitiated) {
            let data = PhotoAnalysisPDFService.generate(
                analysis: analysis,
                timeframeImages: images,
                symbol: nil
            )
            await MainActor.run {
                photoPDFData = data
                showPhotoPDFSheet = true
                isGeneratingPDF = false
            }
        }
    }

    private func buildShareText(analysis: ChartAnalysis) -> String {
        var text = "📊 Analyse Technique — TradeMindset\n\n"
        text += "🔎 Résumé\n\(analysis.resume)\n\n"
        text += "🎯 Plan de Trade\n"
        text += "• Biais : \(analysis.plan.biais)\n"
        text += "• Entrée : \(analysis.plan.entree)\n"
        text += "• Stop : \(analysis.plan.stop)\n"
        text += "• Objectifs : \(analysis.plan.objectifs)\n\n"
        text += "🧱 Structure\n\(analysis.structure)\n\n"
        text += "📍 Zones clés\n\(analysis.zones)\n\n"
        if let rr = analysis.plan.rr { text += "📐 R/R : \(rr)\n\n" }
        text += "— Généré par TradeMindset"
        return text
    }

        // MARK: - Timeframe Picker Sheet
    
    private var timeframePickerSheet: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                // Message d'info
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 36))
                        .foregroundColor(.cyan)
                    
                    Text(t("chooseTimeframe"))
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(t("chooseTimeframeSubtitle"))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, AppSpacing.lg)
                
                // Grille de sélection
                LazyVGrid(columns: [
                    GridItem(.flexible()), GridItem(.flexible()),
                    GridItem(.flexible()), GridItem(.flexible())
                ], spacing: AppSpacing.md) {
                    ForEach(AnalysisTimeframe.allCases) { tf in
                        let hasImage = timeframeImages.contains { $0.timeframe == tf }
                        
                        Button(action: {
                            selectedTimeframe = tf
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: tf.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(
                                        hasImage ? .green :
                                        selectedTimeframe == tf ? .cyan : AppColors.textSecondary
                                    )
                                
                                Text(tf.displayName)
                                    .font(.system(size: 13, weight: selectedTimeframe == tf ? .bold : .regular))
                                    .foregroundColor(
                                        hasImage ? .green :
                                        selectedTimeframe == tf ? .cyan : AppColors.textPrimary
                                    )
                                
                                if hasImage {
                                    Text("✓")
                                        .font(.system(size: 10))
                                        .foregroundColor(.green)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(
                                selectedTimeframe == tf ? Color.cyan.opacity(0.1) :
                                hasImage ? Color.green.opacity(0.05) :
                                AppColors.cardBackground
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.medium)
                                    .stroke(
                                        selectedTimeframe == tf ? Color.cyan.opacity(0.5) :
                                        hasImage ? Color.green.opacity(0.3) :
                                        AppColors.border.opacity(0.3),
                                        lineWidth: selectedTimeframe == tf ? 2 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                
                // Boutons source image
                HStack(spacing: AppSpacing.md) {
                    Button(action: {
                        showingTimeframePicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingCamera = true
                        }
                    }) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "camera.fill")
                            Text(t("camera"))
                        }
                        .font(AppTypography.labelMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.md)
                        .background(
                            LinearGradient(
                                colors: [AppColors.warning, AppColors.warning.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    }
                    
                    Button(action: {
                        showingTimeframePicker = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingImagePicker = true
                        }
                    }) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "photo.on.rectangle")
                            Text(t("library"))
                        }
                        .font(AppTypography.labelMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        showingTimeframePicker = false
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Actions
    
    private func loadSharedImage() {
        if SharedImageService.shared.hasPendingSharedImage() {
            if let sharedImage = SharedImageService.shared.retrieveSharedImageAsUIImage() {
                print("✅ [PhotoAnalysisView] Loaded shared image")
                addImageForTimeframe(image: sharedImage, timeframe: .daily)
            }
        }
    }
    
    private func addImageForTimeframe(image: UIImage, timeframe: AnalysisTimeframe) {
        // Remplacer si déjà existant pour cette UT
        timeframeImages.removeAll { $0.timeframe == timeframe }
        
        withAnimation(.spring(response: 0.3)) {
            timeframeImages.append(TimeframeImage(timeframe: timeframe, image: image))
        }
        
        analysisResult = nil
        errorMessage = nil
        
        HapticFeedback.light()
    }
    
    private func analyzeImages() async {
        guard !timeframeImages.isEmpty else { return }
        
        isAnalyzing = true
        showFullScreenScan = true
        errorMessage = nil
        analysisResult = nil
        defer { isAnalyzing = false }
        
        HapticFeedback.medium()
        
        let language = LanguageManager.shared.currentLanguage
        
        guard let analyzer = OpenAIChartAnalyzer() else {
            await MainActor.run {
                errorMessage = t("analyzerInitError")
                HapticFeedback.error()
            }
            return
        }
        
        do {
            let analysis: ChartAnalysis
            if timeframeImages.count == 1 {
                analysis = try await analyzer.analyzeChart(timeframeImages[0].image, language: language)
            } else {
                analysis = try await analyzer.analyzeMultiTimeframe(images: timeframeImages, language: language)
            }
            
            await MainActor.run {
                analysisResult = analysis
                HapticFeedback.success()
            }
        } catch {
            await MainActor.run {
                errorMessage = "\(t("analysisErrorGeneric")) \(error.localizedDescription)"
                HapticFeedback.error()
            }
        }
    }
    
    // MARK: - Scan Step
    
    private func scanStep(icon: String, text: String, active: Bool, done: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(done ? .green : active ? .cyan : AppColors.textTertiary)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(active ? AppColors.textSecondary : AppColors.textTertiary)
        }
        .opacity(active ? 1 : 0.4)
    }
    
    // MARK: - Full Screen Scan View
    
    private func scanFullScreenView(image: UIImage) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { showFullScreenScan = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 8, height: 8)
                            .scaleEffect(scanLineOffset > 0 ? 1.4 : 0.6)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: scanLineOffset)
                        Text(isMultiMode ? t("multiScanInProgress") : t("singleScanInProgress"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.clear)
                }
                .padding()
                
                GeometryReader { geo in
                    let imgHeight = geo.size.height * 0.75
                    let imgY = geo.size.height * 0.4
                    
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: geo.size.width - 40, maxHeight: imgHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .position(x: geo.size.width / 2, y: imgY)
                        
                        // Grille d'analyse
                        Path { path in
                            let w = geo.size.width - 40
                            let h = imgHeight
                            let ox = CGFloat(20)
                            let oy = imgY - h / 2
                            for i in 1..<4 {
                                let y = oy + h * CGFloat(i) / 4
                                path.move(to: CGPoint(x: ox, y: y))
                                path.addLine(to: CGPoint(x: ox + w, y: y))
                            }
                            for i in 1..<4 {
                                let x = ox + w * CGFloat(i) / 4
                                path.move(to: CGPoint(x: x, y: oy))
                                path.addLine(to: CGPoint(x: x, y: oy + h))
                            }
                        }
                        .stroke(Color.cyan.opacity(0.12), lineWidth: 0.5)
                        
                        // Ligne de scan
                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .cyan.opacity(0.6), .cyan, .cyan.opacity(0.6), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width - 40, height: 3)
                            .shadow(color: .cyan.opacity(0.8), radius: 12, y: 0)
                            .position(x: geo.size.width / 2,
                                      y: (imgY - imgHeight / 2) + imgHeight * scanLineOffset)
                        
                        // Overlay scanné
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.cyan.opacity(0.04))
                                .frame(height: imgHeight * scanLineOffset)
                            Spacer(minLength: 0)
                        }
                        .frame(width: geo.size.width - 40, height: imgHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .position(x: geo.size.width / 2, y: imgY)
                        
                        // Coins focus
                        ForEach(0..<4, id: \.self) { corner in
                            let isRight = corner % 2 == 1
                            let isBottom = corner >= 2
                            let cx = isRight ? geo.size.width / 2 + (geo.size.width - 40) / 2 : geo.size.width / 2 - (geo.size.width - 40) / 2
                            let cy = isBottom ? imgY + imgHeight / 2 : imgY - imgHeight / 2
                            let dx: CGFloat = isRight ? -1 : 1
                            let dy: CGFloat = isBottom ? -1 : 1
                            
                            Path { path in
                                path.move(to: CGPoint(x: cx, y: cy + dy * 20))
                                path.addLine(to: CGPoint(x: cx, y: cy))
                                path.addLine(to: CGPoint(x: cx + dx * 20, y: cy))
                            }
                            .stroke(Color.cyan.opacity(0.8), lineWidth: 2)
                        }
                        
                        // Bordure
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                            .frame(width: geo.size.width - 40, height: imgHeight)
                            .position(x: geo.size.width / 2, y: imgY)
                        
                        // Info multi-UT en bas
                        VStack(spacing: 12) {
                            if isMultiMode {
                                HStack(spacing: 6) {
                                    ForEach(timeframeImages.sorted(by: { $0.timeframe.sortOrder < $1.timeframe.sortOrder })) { tfImg in
                                        Text(tfImg.timeframe.displayName)
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.cyan.opacity(0.5))
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                Text(t("crossReferencingTimeframes"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                            } else {
                                Text(t("analyzingPatterns"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.5))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.88)
                    }
                }
            }
        }
        .onAppear {
            scanLineOffset = 0
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: true)) {
                scanLineOffset = 1.0
            }
        }
        .onChange(of: isAnalyzing) { _, newValue in
            if !newValue { showFullScreenScan = false }
        }
    }
}

// MARK: - Analysis Card Component

private struct AnalysisCard: View {
    let icon: String
    let title: String
    let content: String
    var accentColor: Color? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Text(icon)
                    .font(.title3)
                Text(title)
                    .font(AppTypography.titleSmall)
                    .foregroundColor(accentColor ?? AppColors.textPrimary)
            }
            
            Text(content)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke((accentColor ?? AppColors.border).opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}

// MARK: - Trade Plan Card (Enrichi si multi-UT)

private struct TradePlanCard: View {
    let plan: TradePlan
    var isMultiTimeframe: Bool = false
    
    private var language: Localizable.Language {
        LanguageManager.shared.currentLanguage
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.xs) {
                Text("🎯")
                    .font(.title3)
                Text(Localizable.text("tradePlan", language: language))
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                if isMultiTimeframe {
                    Text("PRO")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                }
            }
            
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                PlanItem(label: Localizable.text("bias", language: language), value: plan.biais, color: AppColors.primary)
                PlanItem(label: Localizable.text("entry", language: language), value: plan.entree, color: AppColors.success)
                PlanItem(label: Localizable.text("stopLoss", language: language), value: plan.stop, color: AppColors.error)
                PlanItem(label: Localizable.text("targets", language: language), value: plan.objectifs, color: AppColors.warning)
                PlanItem(label: Localizable.text("confirmation", language: language), value: plan.confirmation, color: AppColors.info)
                PlanItem(label: Localizable.text("invalidation", language: language), value: plan.invalidation, color: AppColors.error)
                
                // Champs enrichis multi-UT
                if let rr = plan.rr, !rr.isEmpty {
                    Divider().opacity(0.3)
                    PlanItem(label: Localizable.text("riskReward", language: language), value: rr, color: .cyan)
                }
                
                if let zones = plan.zonesRetournement, !zones.isEmpty {
                    PlanItem(label: Localizable.text("reversalZones", language: language), value: zones, color: .cyan)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(
            LinearGradient(
                colors: [
                    AppColors.cardBackground,
                    AppColors.cardBackground.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(isMultiTimeframe ? Color.cyan.opacity(0.5) : AppColors.primary.opacity(0.5), lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
        .shadow(color: (isMultiTimeframe ? Color.cyan : AppColors.primary).opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

private struct PlanItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(label)
                .font(AppTypography.captionMedium)
                .foregroundColor(color)
                .frame(width: 90, alignment: .leading)
            
            Text(value)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Error Card

private struct ErrorCard: View {
    let message: String
    
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.error)
            Text(message)
                .font(AppTypography.bodySmall)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.error.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
    }
}

// MARK: - Helper Views

private struct MultiPhotoImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
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
        let parent: MultiPhotoImagePicker
        
        init(_ parent: MultiPhotoImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.selectedImage = image as? UIImage
                }
            }
        }
    }
}

private struct MultiPhotoCameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
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
        let parent: MultiPhotoCameraView
        
        init(_ parent: MultiPhotoCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
