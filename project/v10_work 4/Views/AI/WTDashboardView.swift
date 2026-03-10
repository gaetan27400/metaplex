//
//  WTDashboardView.swift
//  Journal de trading 2025
//
//  Vue complète de l'oscillateur Wave Trend
//

import SwiftUI
import Charts

struct WTDashboardView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let snapshot: WTSnapshot
    let symbol: String
    let currentTimeframe: WTTimeframe
    let onTimeframeChange: (WTTimeframe) -> Void
    
    @State private var showFullScreen = false
    @State private var selectedReading: WTReading? = nil
    @State private var showNotificationSettings = false
    @State private var signalAnimationTrigger = false // Animation pour nouveau signal
    @State private var chartTransitionTrigger = false // Animation changement UT
    @State private var showMomentumHelp = false // Aide momentum
    @StateObject private var wtNotificationPrefs = WTNotificationPreferences.shared
    @State private var shareTrigger = false
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    init(
        snapshot: WTSnapshot,
        symbol: String = "BTCUSDT",
        currentTimeframe: WTTimeframe = .h1,
        onTimeframeChange: @escaping (WTTimeframe) -> Void = { _ in }
    ) {
        self.snapshot = snapshot
        self.symbol = symbol
        self.currentTimeframe = currentTimeframe
        self.onTimeframeChange = onTimeframeChange
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
            
            // Graphique principal
            chartSection
                .frame(height: isLandscape ? 200 : 280)
                .padding(.horizontal, AppSpacing.lg)
            
            // Informations complémentaires
            infoSection
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(Color(hex: "#18e0ff").opacity(0.3), lineWidth: 1)
        )
        .fullscreenShareable(
            trigger: $shareTrigger,
            showFullScreen: $showFullScreen,
            caption: "Wave Trend — \(symbol) \(currentTimeframe.displayName) | TradeMindset"
        )
        .fullScreenCover(isPresented: $showFullScreen) {
            fullScreenView
        }
        .sheet(isPresented: $showNotificationSettings) {
            notificationSettingsView
        }
        .onChange(of: snapshot.currentSignal) { oldSignal, newSignal in
            // Animation lors du changement de signal
            if oldSignal != newSignal && newSignal != .neutral {
                HapticFeedback.success()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5).repeatCount(2)) {
                    signalAnimationTrigger.toggle()
                }
            }
        }
        .onChange(of: currentTimeframe) { _, _ in
            // Animation lors du changement de timeframe
            HapticFeedback.selection()
            withAnimation(AppAnimations.quick) {
                chartTransitionTrigger.toggle()
            }
        }
        .sheet(isPresented: $showMomentumHelp) {
            MomentumHelpView()
                .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("waveTrendOscillator"))
                        .font(isLandscape ? AppTypography.titleSmall : AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(symbol)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                // Signaux et infos compactes
                if isLandscape {
                    HStack(spacing: 8) {
                        signalBadge
                        marketBiasBadge
                        momentumBadge
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 6) {
                        signalBadge
                        HStack(spacing: 8) {
                            marketBiasBadge
                            momentumBadge
                        }
                    }
                }
                
                // Boutons d'action
                HStack(spacing: 8) {
                    // Bouton notifications
                    Button(action: {
                        HapticFeedback.selection()
                        showNotificationSettings = true
                    }) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14))
                            .foregroundColor(wtNotificationPrefs.enabledTimeframes.contains(currentTimeframe) ? Color(hex: "#18e0ff") : .gray)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }

                    // Bouton partage
                    Button(action: { captureAndShareWT() }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#18e0ff"))
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                    // Bouton plein écran
                    Button(action: {
                        withAnimation(.spring()) {
                            showFullScreen = true
                        }
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14))
                            .foregroundColor(.cyan)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
            }
            
            // Sélecteur de timeframe
            timeframeSelector
        }
    }
    
    private var timeframeSelector: some View {
        Menu {
            // Organiser par catégories pour un meilleur choix
            ForEach([TimeframeCategory.minutes, .hours, .days, .weeks, .months], id: \.self) { category in
                let timeframes = WTTimeframe.allCases.filter { $0.category == category }
                if !timeframes.isEmpty {
                    Section(category.rawValue) {
                        ForEach(timeframes, id: \.self) { timeframe in
                            timeframeMenuOption(timeframe: timeframe)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) { // Réduit de 8 à 6
                Image(systemName: "clock.fill")
                    .font(.system(size: 13)) // Réduit de 14 à 13
                    .foregroundColor(Color(hex: "#18e0ff"))
                
                Text(currentTimeframe.displayName)
                    .font(.system(size: 14, weight: .bold)) // Réduit de 15 à 14
                    .foregroundColor(.white)
                    .lineLimit(1) // FIX: Force 1 ligne
                    .minimumScaleFactor(0.8) // FIX: Réduit si nécessaire
                
                // Indicateur de notification si activé
                if wtNotificationPrefs.isEnabled(for: currentTimeframe) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10)) // Réduit de 11 à 10
                        .foregroundColor(Color(hex: "#18e0ff"))
                }
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10)) // Réduit de 11 à 10
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(minHeight: 38) // Supprimé minWidth pour laisser le contenu décider
            .padding(.horizontal, 12) // Réduit de 16 à 12
            .padding(.vertical, 8) // Réduit de 10 à 8
            .fixedSize(horizontal: true, vertical: false) // FIX: Empêche le wrapping
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#18e0ff").opacity(0.5), lineWidth: 1.5)
                    )
            )
            .shadow(color: Color(hex: "#18e0ff").opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    private func timeframeMenuOption(timeframe: WTTimeframe) -> some View {
        let isSelected = currentTimeframe == timeframe
        let isNotificationEnabled = wtNotificationPrefs.isEnabled(for: timeframe)
        
        return Button(action: {
            HapticFeedback.selection()
            onTimeframeChange(timeframe)
        }) {
            HStack {
                Text(timeframe.displayName)
                    .font(.system(size: 15))
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#18e0ff"))
                }
                
                if isNotificationEnabled {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#18e0ff"))
                }
            }
        }
    }
    
    private var signalBadge: some View {
        Group {
            if let signal = snapshot.currentSignal {
                VStack(spacing: 4) { // Réduit de 6 à 4
                    // Label discret
                    Text(t("signal"))
                        .font(.system(size: 8, weight: .medium)) // Réduit de 9 à 8
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(0.5)
                        .lineLimit(1) // FIX
                    
                    // Badge principal - VERSION COMPACTE EN PORTRAIT
                    HStack(spacing: 6) { // Réduit de 8 à 6
                        // Icône directionnelle
                        Image(systemName: signalIcon(for: signal))
                            .font(.system(size: 14, weight: .bold)) // Réduit de 16 à 14
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 1) { // Réduit de 2 à 1
                            // FIX: Texte court en portrait, complet en landscape
                            Text(isLandscape ? signal.displayName : signalShortName(for: signal))
                                .font(.system(size: isLandscape ? 14 : 13, weight: .heavy)) // Réduit
                                .foregroundColor(.white)
                                .lineLimit(1) // FIX: Force 1 ligne
                                .minimumScaleFactor(0.8) // FIX: Réduit si nécessaire
                            
                            // Score de qualité (seulement en landscape pour économiser l'espace)
                            if isLandscape, let quality = snapshot.signalQuality {
                                Text("\(Int(quality.score))")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, 10) // Réduit de 14 à 10
                    .padding(.vertical, 7) // Réduit de 10 à 7
                    .fixedSize(horizontal: true, vertical: false) // FIX: Empêche le wrapping
                    .background(
                        Capsule()
                            .fill(signal.color.opacity(0.25))
                            .overlay(
                                Capsule()
                                    .stroke(signal.color, lineWidth: 2)
                            )
                            .shadow(color: signal.color.opacity(0.5), radius: 6, x: 0, y: 3)
                    )
                    .scaleEffect(signalAnimationTrigger ? 1.05 : 1.0)
                }
            } else {
                VStack(spacing: 4) {
                    Text(t("signal"))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(0.5)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text(isLandscape ? "Neutral" : "NEU") // FIX: Version courte en portrait
                            .font(.system(size: isLandscape ? 14 : 13, weight: .heavy))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1) // FIX
                            .minimumScaleFactor(0.8) // FIX
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .fixedSize(horizontal: true, vertical: false) // FIX
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(Capsule().stroke(Color.gray.opacity(0.4), lineWidth: 2))
                    )
                }
            }
        }
    }
    
    // FIX: Noms courts pour portrait
    private func signalShortName(for signal: WTSignal) -> String {
        switch signal {
        case .bullishReversal, .bullishSmartReversal:
            return "BULL"
        case .bearishReversal, .bearishSmartReversal:
            return "BEAR"
        case .neutral:
            return "NEU"
        }
    }
    
    private func signalIcon(for signal: WTSignal) -> String {
        switch signal {
        case .bullishReversal, .bullishSmartReversal:
            return "arrow.up.circle.fill"
        case .bearishReversal, .bearishSmartReversal:
            return "arrow.down.circle.fill"
        case .neutral:
            return "arrow.left.arrow.right.circle.fill"
        }
    }
    
    private var marketBiasBadge: some View {
        VStack(spacing: 2) {
            Text(t("ai"))
                .font(.system(size: isLandscape ? 8 : 9))
                .foregroundColor(.white.opacity(0.6))
            HStack(spacing: 3) {
                Circle()
                    .fill(snapshot.currentMarketBias.color)
                    .frame(width: 6, height: 6)
                Text(snapshot.currentMarketBias.displayName)
                    .font(.system(size: isLandscape ? 9 : 10, weight: .semibold))
                    .foregroundColor(snapshot.currentMarketBias.color)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
    
    private var momentumBadge: some View {
        HStack(spacing: 2) { // Réduit de 3 à 2
            Image(systemName: snapshot.momentumDirection == .growing ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 8))
                .foregroundColor(snapshot.momentumDirection.color)
            
            Text(String(format: "%.1f", snapshot.currentMomentum)) // Réduit de .2f à .1f
                .font(.system(size: 9, weight: .medium)) // Réduit de 10 à 9
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1) // FIX: Force 1 ligne
                .monospacedDigit() // FIX: Largeur fixe pour les chiffres
        }
        .padding(.horizontal, 6) // Réduit de 8 à 6
        .padding(.vertical, 3) // Réduit de 4 à 3
        .fixedSize(horizontal: true, vertical: false) // FIX: Empêche le wrapping
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func qualityColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        // DEBUG: Log des timestamps pour diagnostic
        let _ = {
            print("📊 [chartSection] TF:\(currentTimeframe.rawValue) | Readings:\(snapshot.readings.count)")
            if let first = snapshot.readings.first, let last = snapshot.readings.last {
                print("📊 [chartSection] Premier: \(first.timestamp) (\(first.timestamp.timeIntervalSince1970)s)")
                print("📊 [chartSection] Dernier: \(last.timestamp) (\(last.timestamp.timeIntervalSince1970)s)")
            }
        }()
        
        // Précalculer les dates explicites pour l'axe X (aide le compilateur)
        let stride = calculateStride(readingsCount: snapshot.readings.count, isLandscape: isLandscape)
        let indices = stride > 0 ? Array(Swift.stride(from: 0, to: snapshot.readings.count, by: stride)) : []
        let explicitDates = indices.compactMap { idx -> Date? in
            idx < snapshot.readings.count ? snapshot.readings[idx].timestamp : nil
        }
        
        return Chart {
            // Zones de surachat/survente (OB/OS)
            if !snapshot.readings.isEmpty {
                // Zone surachat (rouge très léger)
                RectangleMark(
                    xStart: .value("Start", snapshot.readings.first?.timestamp ?? Date()),
                    xEnd: .value("End", snapshot.readings.last?.timestamp ?? Date()),
                    yStart: .value("Lower", snapshot.overboughtLevel),
                    yEnd: .value("Upper", snapshot.overboughtLevel + 7)
                )
                .foregroundStyle(Color(hex: "#e91e62").opacity(0.12))
                
                // Zone survente (bleu très léger)
                RectangleMark(
                    xStart: .value("Start", snapshot.readings.first?.timestamp ?? Date()),
                    xEnd: .value("End", snapshot.readings.last?.timestamp ?? Date()),
                    yStart: .value("Lower", snapshot.oversoldLevel - 7),
                    yEnd: .value("Upper", snapshot.oversoldLevel)
                )
                .foregroundStyle(Color(hex: "#00dbff").opacity(0.12))
            }
            
            // Histogramme (WT1 - WT2)
            ForEach(snapshot.readings) { reading in
                // FIX: Uniquement si histogram significatif (> 0.5) pour éviter les traits parasites
                if abs(reading.histogram) > 0.5 {
                    BarMark(
                        x: .value("Date", reading.timestamp),
                        yStart: .value("WT2", reading.wt2),
                        yEnd: .value("WT1", reading.wt1)
                    )
                    .foregroundStyle(histogramGradient(reading.histogram))
                    .opacity(0.6) // Légère transparence
                }
            }
            
            // Ligne WT1 (cyan)
            ForEach(snapshot.readings) { reading in
                LineMark(
                    x: .value("Date", reading.timestamp),
                    y: .value("WT1", reading.wt1)
                )
                .foregroundStyle(Color(hex: "#00dbff"))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone) // FIX: Monotone évite les overshoots et artefacts
            }
            
            // Ligne WT2 (rose)
            ForEach(snapshot.readings) { reading in
                LineMark(
                    x: .value("Date", reading.timestamp),
                    y: .value("WT2", reading.wt2)
                )
                .foregroundStyle(Color(hex: "#e91e62"))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.monotone) // FIX: Monotone évite les overshoots et artefacts
            }
            
            // Signaux Smart Reversal
            ForEach(snapshot.readings.filter { $0.signal != nil }) { reading in
                PointMark(
                    x: .value("Date", reading.timestamp),
                    y: .value("Signal", reading.wt2)
                )
                .foregroundStyle(reading.signal?.color ?? .gray)
                .symbolSize(60)
                .symbol {
                    Circle()
                        .fill(reading.signal?.color ?? .gray)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
            }
            
            // Divergences
            ForEach(snapshot.readings.filter { $0.hasDivergence }) { reading in
                PointMark(
                    x: .value("Date", reading.timestamp),
                    y: .value("Divergence", reading.wt1)
                )
                .foregroundStyle(reading.divergenceType?.color ?? .gray)
                .symbolSize(80)
                .symbol {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(reading.divergenceType?.color ?? .gray)
                        .frame(width: 6, height: 6)
                }
            }
            
            // Ligne zéro
            if !snapshot.readings.isEmpty {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartYScale(domain: -80...80)
        .chartXAxis {
            // FIX: Utiliser des valeurs explicites pour éviter que SwiftUI Charts crée des dates interpolées incorrectes
            AxisMarks(values: explicitDates) { value in
                // FIX: Grid TRÈS LÉGER
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.03))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(formatTimeLabel(date))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                // FIX: Grid TRÈS LÉGER (réduit de 0.1 à 0.03)
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.03)) // FIX: Quasi invisible
                if let val = value.as(Double.self) {
                    AxisValueLabel {
                        Text(String(format: "%.0f", val))
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
    }
    
    // MARK: - Info Section
    
    private var infoSection: some View {
        VStack(spacing: AppSpacing.sm) {
            // Valeurs actuelles
            HStack(spacing: AppSpacing.md) {
                valueCard(title: "WT1", value: String(format: "%.2f", snapshot.currentWT1), color: Color(hex: "#00dbff"))
                valueCard(title: "WT2", value: String(format: "%.2f", snapshot.currentWT2), color: Color(hex: "#e91e62"))
                valueCard(title: "Histogram", value: String(format: "%.2f", snapshot.currentHistogram), color: histogramColor(snapshot.currentHistogram))
            }
            
            // Divergence et Momentum
            if snapshot.hasActiveDivergence || snapshot.currentMomentum != 0 {
                HStack(spacing: AppSpacing.md) {
                    if snapshot.hasActiveDivergence, let divType = snapshot.activeDivergenceType {
                        divergenceCard(type: divType)
                    }
                    
                    if snapshot.currentMomentum != 0 {
                        momentumCard
                    }
                }
            }
        }
    }
    
    private func valueCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: isLandscape ? 9 : 10))
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.system(size: isLandscape ? 12 : 14, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private func divergenceCard(type: WTDivergenceType) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(type.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(t("divergence"))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                Text(type.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(type.color)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(type.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(type.color.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    private var momentumCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(t("momentum"))
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.6))
                
                // Icône d'aide
                Button(action: {
                    HapticFeedback.selection()
                    showMomentumHelp = true
                }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                
                // Direction
                Image(systemName: snapshot.momentumDirection == .growing ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10))
                    .foregroundColor(snapshot.momentumDirection.color)
            }
            
            // Jauge visuelle (NOUVEAU)
            momentumGauge
            
            HStack {
                // Valeur brute (petit)
                Text(String(format: "%.2f", snapshot.currentMomentum))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                // Interprétation textuelle (NOUVEAU - plus gros)
                Text(momentumInterpretation)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(momentumColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // Jauge visuelle du momentum
    private var momentumGauge: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 4)
                
                // Barre de progression
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                momentumColor.opacity(0.6),
                                momentumColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: momentumWidth(maxWidth: geometry.size.width), height: 4)
                    .animation(AppAnimations.standard, value: snapshot.currentMomentum)
            }
        }
        .frame(height: 4)
    }
    
    private func momentumWidth(maxWidth: CGFloat) -> CGFloat {
        let normalized = abs(snapshot.currentMomentum)
        let capped = min(normalized, 2.0) / 2.0
        return maxWidth * capped
    }
    
    private var momentumInterpretation: String {
        let abs = abs(snapshot.currentMomentum)
        if abs < 0.3 { return "Faible" }
        else if abs < 0.7 { return "Modéré" }
        else if abs < 1.2 { return "Fort" }
        else { return "Très fort" }
    }
    
    private var momentumColor: Color {
        let abs = abs(snapshot.currentMomentum)
        if abs < 0.3 { return .gray }
        else if abs < 0.7 { return .yellow }
        else if abs < 1.2 { return .orange }
        else { return .red }
    }
    
    // MARK: - Share

    /// Capture la vue WT en image et affiche le share sheet iOS natif
    private func captureAndShareWT() {
        HapticFeedback.medium()
        shareTrigger = true
    }

    // MARK: - Helper Functions

    /// Calcule le stride optimal pour l'affichage des labels de temps
    private func calculateStride(readingsCount: Int, isLandscape: Bool) -> Int {
        let desiredLabelCount = isLandscape ? 6 : 4
        guard readingsCount > 0 else { return 1 }
        let stride = max(1, readingsCount / desiredLabelCount)
        return stride
    }
    
    /// Formatte les labels de temps selon le timeframe
    private func formatTimeLabel(_ date: Date) -> String {
        // DEBUG: Log temporaire pour diagnostic
        let debugTimestamp = date.timeIntervalSince1970
        print("🕐 [formatTimeLabel] Date:\(date) | Timestamp:\(debugTimestamp) | TF:\(currentTimeframe.rawValue)")
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = TimeZone.current
        
        // Logique adaptée selon l'unité de temps
        let dateFormat: String
        switch currentTimeframe {
        // ⏱️ TIMEFRAMES COURTS (Minutes) → Afficher UNIQUEMENT l'heure
        case .m1, .m3, .m5, .m15, .m30, .m45:
            dateFormat = "HH:mm"
            
        // ⏰ TIMEFRAMES MOYENS (Heures courtes) → Afficher UNIQUEMENT l'heure
        case .h1, .h2, .h3, .h4:
            dateFormat = "HH:mm"
            
        // 🕐 TIMEFRAMES LONGS (Heures longues) → Afficher heure + date compacte
        case .h6, .h8, .h12:
            dateFormat = "dd/MM HH:mm"
            
        // 📅 TIMEFRAMES TRÈS LONGS (Jours) → Afficher date lisible
        case .d1, .d3:
            dateFormat = "dd MMM"
            
        // 📆 TIMEFRAMES HEBDOMADAIRES → Afficher date compacte
        case .w1:
            dateFormat = "dd/MM"
            
        // 📊 TIMEFRAMES MENSUELS → Afficher mois/année
        case .month1:
            dateFormat = "MM/yy"
        }
        
        formatter.dateFormat = dateFormat
        let result = formatter.string(from: date)
        
        print("🕐 [formatTimeLabel] Format:'\(dateFormat)' | Result:'\(result)'")
        
        return result
    }
    
    private func histogramGradient(_ value: Double) -> LinearGradient {
        let normalized = max(-100, min(100, value))
        
        if normalized > 0 {
            // Vert (WT1 > WT2)
            return LinearGradient(
                colors: [
                    Color(hex: "#00ddff"),
                    Color(hex: "#007d91")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Rouge (WT1 < WT2)
            return LinearGradient(
                colors: [
                    Color(hex: "#8b002e"),
                    Color(hex: "#e91e62")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private func histogramColor(_ value: Double) -> Color {
        value > 0 ? Color(hex: "#00ddff") : Color(hex: "#e91e62")
    }
    
    // MARK: - Full Screen View
    
    private var fullScreenView: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea(.all)
                
                VStack(spacing: 16) {
                    // Header
                    fullScreenHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    
                    // Sélecteur de timeframe (plein écran)
                    timeframeSelector
                        .padding(.horizontal, 16)
                    
                    // Graphique agrandi
                    chartSection
                        .frame(height: 400)
                        .padding(.horizontal, 16)
                    
                    // Infos détaillées
                    fullScreenInfo
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(t("waveTrendOscillator"))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showFullScreen = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
    }
    
    private var fullScreenHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("signal"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                if let signal = snapshot.currentSignal {
                    Text(signal.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(signal.color)
                } else {
                    Text(t("neutral"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(t("ai"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack(spacing: 6) {
                    Circle()
                        .fill(snapshot.currentMarketBias.color)
                        .frame(width: 12, height: 12)
                    Text(snapshot.currentMarketBias.displayName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(snapshot.currentMarketBias.color)
                }
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(t("momentum"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack(spacing: 6) {
                    Text(snapshot.momentumDirection == .growing ? "▲" : "▼")
                        .font(.title3)
                        .foregroundColor(snapshot.momentumDirection.color)
                    Text(String(format: "%.2f", snapshot.currentMomentum))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    private var fullScreenInfo: some View {
        VStack(spacing: 12) {
            // Valeurs WT
            HStack(spacing: 12) {
                expandedValueCard(title: "WT1", value: snapshot.currentWT1, color: Color(hex: "#00dbff"))
                expandedValueCard(title: "WT2", value: snapshot.currentWT2, color: Color(hex: "#e91e62"))
                expandedValueCard(title: "Histogram", value: snapshot.currentHistogram, color: histogramColor(snapshot.currentHistogram))
            }
            
            // Zones
            HStack(spacing: 12) {
                zoneCard(title: "Zone", value: snapshot.isOverbought ? "Surachat" : snapshot.isOversold ? "Survente" : "Neutre", color: snapshot.isOverbought ? Color(hex: "#e91e62") : snapshot.isOversold ? Color(hex: "#00dbff") : .gray)
                
                if snapshot.hasActiveDivergence, let divType = snapshot.activeDivergenceType {
                    expandedDivergenceCard(type: divType)
                }
            }
        }
    }
    
    private func expandedValueCard(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text(String(format: "%.2f", value))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func zoneCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
        )
    }
    
    private func expandedDivergenceCard(type: WTDivergenceType) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(type.color)
            Text(t("divergence"))
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text(type.displayName)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(type.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(type.color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(type.color.opacity(0.5), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Notification Settings View
    
    private var notificationSettingsView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(t("no"))
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    Text(t("ai"))
                        .font(AppTypography.bodySmall)
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                
                Divider().background(AppColors.border.opacity(0.3))
                
                // Liste des timeframes par catégorie
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        ForEach([TimeframeCategory.minutes, .hours, .days, .weeks, .months], id: \.self) { category in
                            timeframeCategorySection(category: category)
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Terminé") {
                        showNotificationSettings = false
                    }
                    .foregroundColor(Color(hex: "#18e0ff"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func timeframeCategorySection(category: TimeframeCategory) -> some View {
        let timeframes = WTTimeframe.notificationTimeframes.filter { $0.category == category }
        guard !timeframes.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(category.rawValue)
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.bottom, AppSpacing.xs)
                
                VStack(spacing: AppSpacing.sm) {
                    ForEach(timeframes, id: \.self) { timeframe in
                        timeframeNotificationRow(timeframe: timeframe)
                    }
                }
            }
        )
    }
    
    private func timeframeNotificationRow(timeframe: WTTimeframe) -> some View {
        let isEnabled = wtNotificationPrefs.isEnabled(for: timeframe)
        
        return Button(action: {
            HapticFeedback.selection()
            withAnimation(.spring(response: 0.3)) {
                wtNotificationPrefs.toggle(for: timeframe)
            }
        }) {
            HStack(spacing: AppSpacing.md) {
                // Icône timeframe
                Image(systemName: "clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#18e0ff"))
                    .frame(width: 24)
                
                // Nom du timeframe
                Text(timeframe.displayName)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                // Toggle visuel
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isEnabled ? Color(hex: "#18e0ff") : AppColors.textTertiary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(isEnabled ? Color(hex: "#18e0ff").opacity(0.1) : AppColors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.medium)
                            .stroke(isEnabled ? Color(hex: "#18e0ff").opacity(0.3) : AppColors.border.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
