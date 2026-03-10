//
//  MTFDashboardView.swift
//  Journal de trading 2025
//
//  Dashboard MTF amélioré - Lisibilité et interactions optimisées
//

import SwiftUI

// Wrapper pour rendre VMCTimeframe Identifiable
private struct TimeframeWrapper: Identifiable {
    let id = UUID()
    let timeframe: VMCTimeframe
    
    init(_ timeframe: VMCTimeframe) {
        self.timeframe = timeframe
    }
}

struct MTFDashboardView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    private func t(_ key: String) -> String {
        Localizable.text(key, language: languageManager.currentLanguage)
    }

    let snapshot: MTFSnapshot
    let symbol: String
    @State private var shareTrigger = false
    @State private var showFullScreen = false
    @State private var showHelp = false
    @State private var selectedHelpItem: HelpItem? = nil
    @State private var selectedTimeframe: VMCTimeframe? = nil
    @State private var hoveredTimeframe: VMCTimeframe? = nil
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    // Détection du mode paysage
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    init(snapshot: MTFSnapshot, symbol: String = "BTCUSDT") {
        self.snapshot = snapshot
        self.symbol = symbol
    }
    
    enum HelpItem: String, Identifiable {
        case quickGuide = "Guide rapide"
        case rsi = "RSI"
        case vmc = "VMC"
        case combinedScore = "Score Combiné"
        case confluence = "Confluence"
        case divergence = "Divergence"
        case signal = "Signal"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .quickGuide: return "Guide rapide d'utilisation"
            case .rsi: return "RSI - Indicateur de timing"
            case .vmc: return "VMC - Indicateur de force"
            case .combinedScore: return "Score Combiné"
            case .confluence: return "Confluence"
            case .divergence: return "Divergence"
            case .signal: return "Signal de Trading"
            }
        }
        
        var explanation: String {
            switch self {
            case .quickGuide:
                return """
                # Comment utiliser ce dashboard
                
                ## 1️⃣ Regardez le Signal Global
                - **ACHETER** (vert) → Opportunité d'achat
                - **VENDRE** (rouge) → Opportunité de vente
                - **NEUTRE** (gris) → Attendre
                
                ## 2️⃣ Vérifiez la Confluence
                - **>70%** (vert) → Signal très fiable
                - **50-70%** (orange) → Signal modéré
                - **<50%** (gris) → Signal peu fiable
                
                ## 3️⃣ Attention aux alertes
                - **⚠️ P** (rouge) → PIÈGE - Ne pas acheter
                - **⚠️ A** (orange) → Opportunité potentielle
                
                ## 4️⃣ Cliquez sur un timeframe
                → Voir l'analyse détaillée et la recommandation
                """
            case .rsi:
                return """
                # RSI - Quand acheter/vendre ?
                
                Le RSI vous dit si c'est le **bon moment** pour entrer.
                
                ## Zones clés
                - **0-30** (bleu) → SURVENTE = Bon moment d'ACHAT
                - **30-70** (violet) → NEUTRE = Attendre
                - **70-100** (rouge) → SURACHAT = Bon moment de VENTE
                
                ## En pratique
                ✅ RSI à 25 → Le prix est bas, c'est attractif
                ⚠️ RSI à 80 → Le prix est haut, prudence
                
                **Important** : Le RSI donne le timing, mais ne garantit pas la direction future. Regardez toujours le VMC en parallèle.
                """
            case .vmc:
                return """
                # VMC - Dans quelle direction ?
                
                Le VMC vous dit la **force et direction** du mouvement.
                
                ## Zones clés
                - **< -25** (vert) → FORCE BAISSIÈRE = Signal d'achat
                - **-25 à +35** (gris) → NEUTRE = Pas de tendance claire
                - **> +35** (rouge) → FORCE HAUSSIÈRE = Signal de vente
                
                ## En pratique
                ✅ VMC à -40 → Le marché descend fort, opportunité d'achat
                ⚠️ VMC à +50 → Le marché monte fort, risque de correction
                
                **Important** : Le VMC mesure la FORCE, pas le timing. Un VMC négatif fort peut durer longtemps.
                """
            case .combinedScore:
                return """
                # Score Combiné - Le verdict
                
                ## Calcul
                Score = (RSI × 40%) + (VMC × 60%)
                
                → Le VMC (force) compte plus que le RSI (timing)
                
                ## Interprétation
                - **< -40** → ACHETER (vert)
                - **-40 à -10** → Baissier (jaune)
                - **-10 à +10** → NEUTRE (gris)
                - **+10 à +40** → Haussier (orange)
                - **> +40** → VENDRE (rouge)
                
                ## En pratique
                ✅ Score à -45 → Signal d'achat fort
                ⚠️ Score à +50 → Signal de vente fort
                ℹ️ Score à -5 → Pas de signal clair
                """
            case .confluence:
                return """
                # Confluence - Fiabilité du signal
                
                La confluence mesure si **tous les timeframes sont d'accord**.
                
                ## Calcul
                % de timeframes où RSI et VMC pointent dans la même direction
                
                ## Interprétation
                - **>70%** → HAUTE FIABILITÉ ✅
                - **50-70%** → FIABILITÉ MOYENNE ⚠️
                - **<50%** → FAIBLE FIABILITÉ ❌
                
                ## En pratique
                ✅ 80% confluence + Signal ACHETER → Très bon signal
                ⚠️ 45% confluence + Signal ACHETER → Signal incertain
                
                **Règle d'or** : Ne tradez pas si confluence < 50%
                """
            case .divergence:
                return """
                # Divergence - Alerte importante
                
                RSI et VMC ne sont **pas d'accord** → DANGER ou OPPORTUNITÉ
                
                ## Type P (Piège) 🔴
                - RSI dit : "Acheter" (survente)
                - VMC dit : "Force baissière"
                
                **Action** : NE PAS ACHETER
                → C'est un faux signal, le prix peut continuer à baisser
                
                ## Type A (Absorption) 🟠
                - RSI dit : "Vendre" (surachat)
                - VMC dit : "Force haussière"
                
                **Action** : OPPORTUNITÉ POTENTIELLE
                → Les vendeurs sont épuisés, possible retournement
                
                ## En pratique
                ⚠️ Divergence = Signal de prudence
                → Attendez confirmation avant d'agir
                """
            case .signal:
                return """
                # Signal de Trading - Quoi faire ?
                
                ## ACHETER (vert) ✅
                → Ouvrir une position LONG
                → Vérifier que confluence > 70%
                
                ## BAISSIER (jaune) ⚠️
                → Position SHORT envisageable
                → Attendre confirmation
                
                ## NEUTRE (gris) ⏸
                → NE RIEN FAIRE
                → Attendre un signal plus clair
                
                ## HAUSSIER (orange) ⚠️
                → Éviter les positions SHORT
                → Attendre confirmation pour LONG
                
                ## VENDRE (rouge) ❌
                → Ouvrir une position SHORT
                → Vérifier que confluence > 70%
                
                **Important** : Toujours vérifier la confluence avant d'agir
                """
            }
        }
    }
    
    var body: some View {
        compactView
            .fullscreenShareableLandscape(
                trigger: $shareTrigger,
                showFullScreen: $showFullScreen,
                caption: "MTF Dashboard RSI+VMC — \(symbol) | TradeMindset"
            )
            .fullScreenCover(isPresented: $showFullScreen) {
                fullScreenView
            }
    }

    // MARK: - Share

    private func captureAndShareMTF() {
        HapticFeedback.medium()
        shareTrigger = true
    }

    // MARK: - Compact View
    
    private var compactView: some View {
        VStack(spacing: 16) {
            // Header simplifié
            HStack {
                globalHeaderView
                Spacer()

                HStack(spacing: 8) {
                    // Bouton partage
                    Button(action: { captureAndShareMTF() }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
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
                            .foregroundColor(.orange)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
            }
            
            // Légende explicite AU-DESSUS de l'indicateur
            improvedLegendView
            
            // Colonnes horizontales (plus larges et espacées)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Colonne Ticker
                    tickerColumn
                    
                    // Colonne Global
                    globalColumn
                    
                    // Colonnes par timeframe (plus larges)
                    ForEach(VMCTimeframe.allCases.reversed(), id: \.self) { tf in
                        if let reading = snapshot.readings[tf] {
                            timeframeColumn(reading: reading)
                                .scaleEffect(hoveredTimeframe == tf ? 1.05 : 1.0)
                                .animation(.spring(response: 0.3), value: hoveredTimeframe)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
        .sheet(item: Binding<TimeframeWrapper?>(
            get: { selectedTimeframe.map { TimeframeWrapper($0) } },
            set: { selectedTimeframe = $0?.timeframe }
        )) { (wrapper: TimeframeWrapper) in
            timeframeDetailView(timeframe: wrapper.timeframe)
        }
    }
    
    // MARK: - Global Header (adaptatif paysage/portrait)
    
    private var globalHeaderView: some View {
        HStack(spacing: AppSpacing.xs) { // Réduit de sm à xs
            // FIX: Titre compact sur UNE SEULE LIGNE
            HStack(spacing: 4) {
                Text(symbol)
                    .font(.system(size: isLandscape ? 12 : 13, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1) // FIX
                
                Text("·") // TODO: Traduire avec clé appropriée
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textTertiary)
                
                Text(t("mtf"))
                    .font(.system(size: isLandscape ? 10 : 11, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1) // FIX
            }
            .fixedSize(horizontal: true, vertical: false) // FIX: Empêche le wrapping
            
            Spacer()
            
            // FIX: Signal + Confluence COMPACTS sur une ligne
            HStack(spacing: 6) { // Réduit de 10 à 6
                signalBadgeCompact
                confluenceProminentBadgeCompact // Version compacte
            }
            .fixedSize(horizontal: true, vertical: false) // FIX
        }
    }
    
    // FIX: Version COMPACTE du badge confluence pour le header
    private var confluenceProminentBadgeCompact: some View {
        HStack(spacing: 4) {
            // Icône
            Image(systemName: confluenceIcon)
                .font(.system(size: 11))
                .foregroundColor(confluenceColor)
            
            // Pourcentage
            Text("\(Int(snapshot.confluencePercent))%")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(confluenceColor)
                .monospacedDigit()
                .lineLimit(1) // FIX
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(confluenceColor.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(confluenceColor, lineWidth: 1.5)
                )
        )
        .fixedSize(horizontal: true, vertical: false) // FIX
    }
    
    // MARK: - Helpers pour header compact
    
    // Badge confluence PROÉMINENT (NOUVEAU)
    private var confluenceProminentBadge: some View {
        VStack(spacing: 4) {
            Text(t("confluence"))
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .tracking(0.5)
            
            HStack(spacing: 6) {
                // Icône de fiabilité
                Image(systemName: confluenceIcon)
                    .font(.system(size: 14))
                    .foregroundColor(confluenceColor)
                
                // Pourcentage
                Text("\(Int(snapshot.confluencePercent))%")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(confluenceColor.opacity(0.2))
                    .overlay(
                        Capsule()
                            .stroke(confluenceColor, lineWidth: 2)
                    )
                    .shadow(color: confluenceColor.opacity(0.5), radius: 6)
            )
            
            // Interprétation
            Text(confluenceInterpretation)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(confluenceColor)
        }
    }
    
    private var confluenceIcon: String {
        switch snapshot.confluencePercent {
        case 70...100:
            return "checkmark.shield.fill"
        case 50..<70:
            return "exclamationmark.shield.fill"
        default:
            return "xmark.shield.fill"
        }
    }
    
    private var confluenceColor: Color {
        switch snapshot.confluencePercent {
        case 70...100:
            return Color.green
        case 50..<70:
            return Color.orange
        default:
            return Color.gray
        }
    }
    
    private var confluenceInterpretation: String {
        switch snapshot.confluencePercent {
        case 70...100:
            return "Fort"
        case 50..<70:
            return "Modéré"
        default:
            return "Faible"
        }
    }
    
    private var signalBadge: some View {
        HStack(spacing: 4) {
            Text(t("signalGlobal"))
                .font(.system(size: isLandscape ? 9 : 10))
                .foregroundColor(AppColors.textTertiary)
            Text(snapshot.globalSignal.displayName.uppercased())
                .font(.system(size: isLandscape ? 10 : 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(snapshot.globalSignal.color.opacity(0.3)))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    private var signalBadgeCompact: some View {
        VStack(spacing: 2) {
            Text(t("signal"))
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
            Text(snapshot.globalSignal.displayName.uppercased())
                .font(.system(size: isLandscape ? 10 : 9, weight: .bold))
                .foregroundColor(snapshot.globalSignal.color)
                .padding(.horizontal, isLandscape ? 6 : 4)
                .padding(.vertical, 2)
                .background(Capsule().fill(snapshot.globalSignal.color.opacity(0.2)))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    private var scoreBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(t("scoreCombin"))
                .font(.system(size: isLandscape ? 8 : 9))
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1)
            Text(String(format: "%.1f", snapshot.globalCombinedScore))
                .font(.system(size: isLandscape ? 11 : 12, weight: .bold))
                .foregroundColor(snapshot.globalCombinedScore >= 0 ? AppColors.success : AppColors.error)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    private var scoreBadgeCompact: some View {
        VStack(spacing: 2) {
            Text(t("score"))
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
            Text(String(format: "%.1f", snapshot.globalCombinedScore))
                .font(.system(size: isLandscape ? 10 : 9, weight: .bold))
                .foregroundColor(combinedScoreColor(snapshot.globalCombinedScore))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    private var confluenceBadge: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(t("confluence"))
                .font(.system(size: isLandscape ? 8 : 9))
                .foregroundColor(AppColors.textTertiary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(String(format: "%.0f%%", snapshot.confluencePercent))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(confluenceColor(snapshot.confluencePercent))
                    .lineLimit(1)
                reliabilityIcon(snapshot.confluencePercent)
            }
        }
    }
    
    private var confluenceBadgeCompact: some View {
        VStack(spacing: 2) {
            Text(t("conf"))
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
            HStack(spacing: 2) {
                Text("\(Int(snapshot.confluencePercent))%")
                    .font(.system(size: isLandscape ? 10 : 9, weight: .bold))
                    .foregroundColor(confluenceColor(snapshot.confluencePercent))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                if snapshot.confluencePercent < 50 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    @ViewBuilder
    private func reliabilityIcon(_ confluence: Double) -> some View {
        if confluence > 70 {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
        } else if confluence > 50 {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 16))
        } else {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))
        }
    }
    
    private func confluenceColor(_ value: Double) -> Color {
        if value > 70 {
            return .green
        } else if value > 50 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Ticker Column
    
    private var tickerColumn: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 6) {
                let parts = symbol.replacingOccurrences(of: "USDT", with: "").components(separatedBy: "USDT")
                let ticker = parts.first ?? symbol
                Text(ticker)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                Text(t("mexc"))
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.7))
            }
            .frame(height: 60)
            .padding(.vertical, 8)
            Spacer()
        }
        .frame(width: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    // MARK: - Global Column (plus lisible)
    
    private var globalColumn: some View {
        VStack(spacing: 8) {
            // Signal global (badge plus grand)
            Text(snapshot.globalSignal.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(snapshot.globalSignal.color.opacity(0.3))
                        .overlay(
                            Capsule()
                                .stroke(snapshot.globalSignal.color, lineWidth: 2)
                        )
                )
                .frame(height: 28)
                .padding(.top, 4)
            
            // Barres R | V (plus larges et contrastées)
            HStack(spacing: 6) {
                VStack(spacing: 3) {
                    Text(t("dashboard"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    rsiBar(
                        value: snapshot.globalRSI,
                        normalized: MTFCombiner.normalizeRSI(snapshot.globalRSI),
                        width: 26
                    )
                }
                
                VStack(spacing: 3) {
                    Text(t("add"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    vmcBar(
                        value: snapshot.globalVMC,
                        width: 34
                    )
                }
            }
            .frame(height: 110)
            
            // Score avec meilleur contraste
            VStack(spacing: 4) {
                if snapshot.isTurningUp {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text(t("assistant"))
                        .font(.caption)
                }
                Text(String(format: "%.1f", snapshot.globalCombinedScore))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(combinedScoreColor(snapshot.globalCombinedScore).opacity(0.3))
                    )
                if !snapshot.isTurningUp {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text(t("assistant"))
                        .font(.caption)
                }
            }
            .frame(height: 50)
            
            Text(t("global"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: 24)
                .padding(.bottom, 4)
        }
        .frame(width: 70)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
        )
    }
    
    // MARK: - Timeframe Column (adaptatif paysage/portrait)
    
    @ViewBuilder
    private func timeframeColumn(reading: MTFReading) -> some View {
        VStack(spacing: 6) {
            // FIX: Signal + Alerte en VERTICAL pour éviter superposition
            VStack(spacing: 3) {
                // Signal
                Text(reading.combinedSignal.displayName)
                    .font(.system(size: isLandscape ? 9 : 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, isLandscape ? 6 : 8)
                    .padding(.vertical, isLandscape ? 3 : 4)
                    .background(
                        Capsule()
                            .fill(reading.combinedSignal.color.opacity(0.3))
                            .overlay(Capsule().stroke(reading.combinedSignal.color, lineWidth: 1.5))
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: true, vertical: false)
                
                // Alerte divergence (si présente)
                if reading.hasDivergence {
                    let isPiège = reading.divergenceType == .rsiBullishVMCBearish
                    HStack(spacing: 2) {
                        Image(systemName: isPiège ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .font(.system(size: 9))
                        Text(isPiège ? "P" : "A")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(isPiège ? Color.red : Color.orange)
                            .overlay(Capsule().stroke(isPiège ? Color.red.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1))
                    )
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(minHeight: isLandscape ? 28 : 36) // Hauteur adaptée pour 1 ou 2 badges
            
            // Barres RSI | VMC (labels explicites)
            HStack(spacing: 4) {
                VStack(spacing: 2) {
                    Text(t("rsi"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    rsiBar(
                        value: reading.rsiValue,
                        normalized: reading.rsiNormalized,
                        width: isLandscape ? 22 : 26
                    )
                }
                
                VStack(spacing: 2) {
                    Text(t("vmc"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    vmcBar(
                        value: reading.vmcValue,
                        width: isLandscape ? 28 : 34
                    )
                }
            }
            .frame(height: isLandscape ? 80 : 110)
            
            // Valeurs (labels explicites)
            HStack(spacing: 3) {
                VStack(spacing: 1) {
                    Text(t("rsi"))
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                    Text(String(format: "%.0f", reading.rsiValue))
                        .font(.system(size: isLandscape ? 10 : 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(width: isLandscape ? 22 : 30)
                
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: 16)
                
                VStack(spacing: 1) {
                    Text(t("vmc"))
                        .font(.system(size: 7))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                    Text(String(format: "%.1f", reading.vmcValue))
                        .font(.system(size: isLandscape ? 10 : 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .frame(width: isLandscape ? 28 : 34)
            }
            .frame(height: isLandscape ? 24 : 32)
            
            // Score (COMPACT)
            Text(String(format: "%.0f", reading.combinedScore))
                .font(.system(size: isLandscape ? 10 : 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, isLandscape ? 6 : 8)
                .padding(.vertical, isLandscape ? 2 : 3)
                .background(
                    Capsule()
                        .fill(combinedScoreColor(reading.combinedScore).opacity(0.3))
                )
                .frame(height: isLandscape ? 16 : 20)
            
            // Label timeframe
            Text(reading.timeframe.displayName)
                .font(.system(size: isLandscape ? 10 : 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(height: isLandscape ? 18 : 24)
        }
        .frame(width: isLandscape ? 60 : 70)
        .padding(isLandscape ? 6 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColorForReading(reading))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTimeframe = reading.timeframe
        }
    }
    
    // MARK: - Signal Badge (plus visible)
    
    @ViewBuilder
    private func signalBadge(reading: MTFReading) -> some View {
        HStack(spacing: 6) {
            // Signal combiné
            Text(reading.combinedSignal.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(reading.combinedSignal.color.opacity(0.3))
                        .overlay(
                            Capsule()
                                .stroke(reading.combinedSignal.color, lineWidth: 2)
                        )
                )
            
            // Badge divergence
            if reading.hasDivergence {
                divergenceBadge(reading: reading)
            }
        }
        .frame(height: 28)
    }
    
    // MARK: - Divergence Badge (plus clair)
    
    @ViewBuilder
    private func divergenceBadge(reading: MTFReading) -> some View {
        let isPiège = reading.divergenceType == .rsiBullishVMCBearish
        HStack(spacing: 3) {
            Image(systemName: isPiège ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .font(.system(size: 10, weight: .bold))
            Text(isPiège ? "P" : "A")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(isPiège ? Color.red : Color.orange)
        )
        .overlay(
            Capsule()
                .stroke(Color.white, lineWidth: 1.5)
        )
    }
    
    // MARK: - Background Color
    
    private func backgroundColorForReading(_ reading: MTFReading) -> Color {
        if reading.hasDivergence {
            return reading.divergenceType == .rsiBullishVMCBearish
                ? Color.red.opacity(0.2)
                : Color.orange.opacity(0.2)
        }
        return Color.black.opacity(0.5)
    }
    
    // MARK: - RSI Bar (améliorer contraste)
    
    @ViewBuilder
    private func rsiBar(value: Double, normalized: Double, width: CGFloat) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // Ligne zéro (plus visible)
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 2)
                
                // Barre RSI
                Rectangle()
                    .fill(rsiGradient(value))
                    .frame(
                        width: width - 4,
                        height: min(abs(normalized) * 0.7, geometry.size.height * 0.85)
                    )
                    .offset(y: geometry.size.height * 0.425 - min(abs(normalized) * 0.35, geometry.size.height * 0.425))
            }
        }
        .frame(width: width, height: 80)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        )
    }
    
    // MARK: - VMC Bar (améliorer contraste)
    
    @ViewBuilder
    private func vmcBar(value: Double, width: CGFloat) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // Ligne zéro (plus visible)
                Rectangle()
                    .fill(Color.white.opacity(0.5))
                    .frame(height: 2)
                
                // Barre VMC
                if value > 0 {
                    Rectangle()
                        .fill(VMCDashboardMTFView.vmcGradient(value))
                        .frame(
                            width: width - 4,
                            height: min(abs(value) * 0.8, geometry.size.height * 0.9)
                        )
                        .offset(y: -min(abs(value) * 0.4, geometry.size.height * 0.45))
                } else {
                    Rectangle()
                        .fill(VMCDashboardMTFView.vmcGradient(value))
                        .frame(
                            width: width - 4,
                            height: min(abs(value) * 0.8, geometry.size.height * 0.9)
                        )
                        .offset(y: min(abs(value) * 0.4, geometry.size.height * 0.45))
                }
            }
        }
        .frame(width: width, height: 110)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
        )
    }
    
    // MARK: - Gradients & Colors
    
    static func rsiGradient(_ value: Double) -> LinearGradient {
        let normalized = max(0, min(100, value))
        
        if normalized >= 70 {
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if normalized >= 50 {
            return LinearGradient(
                colors: [Color(red: 0.54, green: 0.17, blue: 0.89), Color.red.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else if normalized >= 30 {
            return LinearGradient(
                colors: [Color.blue, Color(red: 0.54, green: 0.17, blue: 0.89)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color.blue.opacity(0.7), Color.blue],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private func rsiGradient(_ value: Double) -> LinearGradient {
        Self.rsiGradient(value)
    }
    
    private func rsiGradientColor(_ value: Double) -> Color {
        let normalized = max(0, min(100, value))
        if normalized >= 70 {
            return .red
        } else if normalized >= 50 {
            return Color(red: 0.54, green: 0.17, blue: 0.89)
        } else {
            return .blue
        }
    }
    
    private func combinedScoreColor(_ score: Double) -> Color {
        if score < -40 {
            return .green
        } else if score < -10 {
            return .yellow
        } else if score <= 10 {
            return .gray
        } else if score < 40 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Improved Legend View (explicite et lisible)
    
    private var improvedLegendView: some View {
        VStack(spacing: 8) {
            // Titre de la légende
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                Text(t("lgende"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            
            // Indicateurs
            HStack(spacing: 16) {
                legendIndicator(label: "RSI", description: "Relative Strength Index", color: .cyan)
                legendIndicator(label: "VMC", description: "Volume Momentum Convergence", color: .purple)
            }
            
            Divider()
                .background(AppColors.border.opacity(0.3))
            
            // Signaux
            HStack(spacing: 12) {
                legendSignalCompact(icon: "arrow.down.circle.fill", color: .green, text: "ACHETER")
                legendSignalCompact(icon: "minus.circle.fill", color: .gray, text: "NEUTRE")
                legendSignalCompact(icon: "arrow.up.circle.fill", color: .red, text: "VENDRE")
            }
            
            // Alertes de divergence
            HStack(spacing: 12) {
                legendAlertCompact(icon: "exclamationmark.triangle.fill", color: .red, text: "P = Piège haussier")
                legendAlertCompact(icon: "info.circle.fill", color: .orange, text: "A = Opportunité d'absorption")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(AppColors.cardBackground.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func legendIndicator(label: String, description: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.2))
                )
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
    
    private func legendSignalCompact(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
    }
    
    private func legendAlertCompact(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
    
    // MARK: - Simplified Legend View (adaptatif paysage/portrait) [DEPRECATED]
    
    private var simplifiedLegendView: some View {
        VStack(spacing: isLandscape ? 8 : 12) {
            // Titre
            HStack {
                Text(t("lgende"))
                    .font(.system(size: isLandscape ? 10 : 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if !isLandscape {
                    Button(action: {
                        selectedHelpItem = .quickGuide
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 11))
                            Text(t("guide"))
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            
            if isLandscape {
                // MODE PAYSAGE : Tout sur UNE ligne
                HStack(spacing: 12) {
                    // Signaux
                    HStack(spacing: 6) {
                        legendItemCompact(icon: "arrow.down.circle.fill", color: .green, text: "BUY")
                        legendItemCompact(icon: "minus.circle.fill", color: .gray, text: "HOLD")
                        legendItemCompact(icon: "arrow.up.circle.fill", color: .red, text: "SELL")
                    }
                    
                    Divider().frame(height: 16)
                    
                    // Alertes
                    HStack(spacing: 6) {
                        legendItemCompact(icon: "exclamationmark.triangle.fill", color: .red, text: "P=Piège")
                        legendItemCompact(icon: "info.circle.fill", color: .orange, text: "A=Opport.")
                    }
                }
                .font(.system(size: 8))
            } else {
                // MODE PORTRAIT : Layout original
                VStack(alignment: .leading, spacing: 8) {
                    Text(t("signaux"))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 10) {
                        legendSignal(color: .green, text: "ACHETER", icon: "arrow.down.circle.fill")
                        legendSignal(color: .gray, text: "NEUTRE", icon: "minus.circle.fill")
                        legendSignal(color: .red, text: "VENDRE", icon: "arrow.up.circle.fill")
                    }
                    
                    Text(t("alertes"))
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 4)
                    
                    HStack(spacing: 10) {
                        legendAlert(color: .red, text: "P = Piège", icon: "exclamationmark.triangle.fill")
                        legendAlert(color: .orange, text: "A = Opportunité", icon: "info.circle.fill")
                    }
                }
            }
        }
        .padding(isLandscape ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
        )
    }
    
    // Helper pour légende compacte (paysage)
    @ViewBuilder
    private func legendItemCompact(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    @ViewBuilder
    private func legendSignal(color: Color, text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(text)
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func legendAlert(color: Color, text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(text)
                .font(.caption2)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Help Detail View
    
    @ViewBuilder
    private func helpDetailView(item: HelpItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(try! AttributedString(markdown: item.explanation))
                        .font(.body)
                        .foregroundColor(.white)
                        .lineSpacing(6)
                        .padding()
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        selectedHelpItem = nil
                    }
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Full Screen View
    
    private var fullScreenView: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea(.all)
                    
                    VStack(spacing: 12) {
                        fullScreenHeader
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                tickerColumn
                                globalColumn
                                
                                ForEach(VMCTimeframe.allCases.reversed(), id: \.self) { tf in
                                    if let reading = snapshot.readings[tf] {
                                        timeframeColumn(reading: reading)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: geometry.size.height * 0.75)
                        
                        simplifiedLegendView
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(t("dashboard"))
                        .font(.headline)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        AppDelegate.orientationLock = .all
                        showFullScreen = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                    }
                }
            }
            .onAppear {
                AppDelegate.orientationLock = .landscapeLeft
                DispatchQueue.main.async {
                    if #available(iOS 16.0, *) {
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
                    } else {
                        UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                    }
                }
            }
            .onDisappear {
                AppDelegate.orientationLock = .all
            }
        }
    }
    
    private var fullScreenHeader: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("signalGlobal"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Text(snapshot.globalSignal.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(snapshot.globalSignal.color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(t("scoreCombin"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack(spacing: 6) {
                    if snapshot.isTurningUp {
                        Text("▲") // TODO: Traduire avec clé appropriée
                            .font(.subheadline)
                            .foregroundColor(.green)
                    } else if snapshot.isTurningDown {
                        Text("▼") // TODO: Traduire avec clé appropriée
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                    Text(String(format: "%.1f", snapshot.globalCombinedScore))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(combinedScoreColor(snapshot.globalCombinedScore))
                }
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(t("confluence"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                HStack(spacing: 6) {
                    Text(String(format: "%.0f%%", snapshot.confluencePercent))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(confluenceColor(snapshot.confluencePercent))
                    reliabilityIcon(snapshot.confluencePercent)
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
    }
    
    // MARK: - Timeframe Detail View (amélioré avec recommandations claires)
    
    @ViewBuilder
    private func timeframeDetailView(timeframe: VMCTimeframe) -> some View {
        if let reading = snapshot.readings[timeframe] {
            timeframeDetailContent(timeframe: timeframe, reading: reading)
        } else {
            timeframeDetailEmpty()
        }
    }
    
    @ViewBuilder
    private func timeframeDetailEmpty() -> some View {
        NavigationStack {
            Text(t("no"))
                .foregroundColor(.white)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(t("close")) {
                            selectedTimeframe = nil
                        }
                        .foregroundColor(.orange)
                    }
                }
        }
        .background(Color.black.ignoresSafeArea())
    }
    
    @ViewBuilder
    private func timeframeDetailContent(timeframe: VMCTimeframe, reading: MTFReading) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    timeframeDetailHeader(timeframe: timeframe, reading: reading)
                    
                    // RECOMMANDATION EN PREMIER (ce qui compte vraiment)
                    actionRecommendationCard(reading: reading)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Explication détaillée
                    detailedExplanationCard(reading: reading)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    // Données techniques (pour les curieux)
                    technicalDataSection(reading: reading)
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(timeframe.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(t("close")) {
                        selectedTimeframe = nil
                    }
                    .foregroundColor(.orange)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Timeframe Detail Components
    
    @ViewBuilder
    private func timeframeDetailHeader(timeframe: VMCTimeframe, reading: MTFReading) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(reading.combinedSignal.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(reading.combinedSignal.color)
                
                Text("Score: \(String(format: "%.1f", reading.combinedScore))")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            if reading.hasDivergence {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(reading.divergenceType == .rsiBullishVMCBearish ? .red : .orange)
                    Text(reading.divergenceType == .rsiBullishVMCBearish ? "PIÈGE" : "OPPORTUNITÉ")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Action Recommendation Card (LE PLUS IMPORTANT)
    
    @ViewBuilder
    private func actionRecommendationCard(reading: MTFReading) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text(t("ai"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Recommandation principale
            Text(getActionRecommendation(reading: reading))
                .font(.body)
                .foregroundColor(.white)
                .lineSpacing(6)
            
            // Action buttons visuels
            actionButtons(reading: reading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(getRecommendationBackgroundColor(reading: reading))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(getRecommendationBorderColor(reading: reading), lineWidth: 2)
                )
        )
    }
    
    @ViewBuilder
    private func actionButtons(reading: MTFReading) -> some View {
        HStack(spacing: 12) {
            if shouldBuy(reading: reading) {
                ActionButton(
                    icon: "arrow.down.circle.fill",
                    text: "Acheter",
                    color: .green,
                    isRecommended: true
                )
            }
            
            if shouldWait(reading: reading) {
                ActionButton(
                    icon: "pause.circle.fill",
                    text: "Attendre",
                    color: .gray,
                    isRecommended: true
                )
            }
            
            if shouldSell(reading: reading) {
                ActionButton(
                    icon: "arrow.up.circle.fill",
                    text: "Vendre",
                    color: .red,
                    isRecommended: true
                )
            }
            
            if shouldAvoid(reading: reading) {
                ActionButton(
                    icon: "xmark.circle.fill",
                    text: "Éviter",
                    color: .red,
                    isRecommended: false
                )
            }
        }
    }
    
    private struct ActionButton: View {
        let icon: String
        let text: String
        let color: Color
        let isRecommended: Bool
        
        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(text)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(isRecommended ? 0.3 : 0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color, lineWidth: isRecommended ? 2 : 1)
                    )
            )
        }
    }
    
    private func shouldBuy(reading: MTFReading) -> Bool {
        return reading.combinedSignal == .buy && !reading.hasDivergence && snapshot.confluencePercent > 50
    }
    
    private func shouldWait(reading: MTFReading) -> Bool {
        return reading.combinedSignal == .neutral || snapshot.confluencePercent <= 50 || 
               (reading.hasDivergence && reading.divergenceType == .rsiBullishVMCBearish)
    }
    
    private func shouldSell(reading: MTFReading) -> Bool {
        return reading.combinedSignal == .sell && !reading.hasDivergence && snapshot.confluencePercent > 50
    }
    
    private func shouldAvoid(reading: MTFReading) -> Bool {
        return reading.hasDivergence && reading.divergenceType == .rsiBullishVMCBearish
    }
    
    private func getActionRecommendation(reading: MTFReading) -> String {
        // Divergence piège = danger
        if reading.hasDivergence && reading.divergenceType == .rsiBullishVMCBearish {
            return "⚠️ DANGER - NE PAS ACHETER\n\nCe timeframe montre un piège haussier : le RSI (\(Int(reading.rsiValue))) suggère un achat, mais le VMC (\(String(format: "%.1f", reading.vmcValue))) indique une force baissière. Le prix risque de continuer à baisser malgré le RSI bas.\n\n→ Attendre que le VMC se retourne avant d'acheter."
        }
        
        // Divergence absorption = opportunité potentielle
        if reading.hasDivergence && reading.divergenceType == .rsiBearishVMCBullish {
            return "💡 OPPORTUNITÉ POTENTIELLE\n\nCe timeframe montre une absorption : le VMC (\(String(format: "%.1f", reading.vmcValue))) indique une force haussière alors que le RSI (\(Int(reading.rsiValue))) est encore bas. C'est souvent un signe de retournement.\n\n→ Opportunité d'achat si confirmé par d'autres timeframes (confluence >70%)."
        }
        
        // Signal d'achat fort
        if reading.combinedSignal == .buy && snapshot.confluencePercent > 70 {
            return "✅ SIGNAL D'ACHAT FORT\n\nRSI (\(Int(reading.rsiValue))) et VMC (\(String(format: "%.1f", reading.vmcValue))) sont alignés pour un signal d'achat. La confluence est haute (\(String(format: "%.0f%%", snapshot.confluencePercent))).\n\n→ Excellente opportunité d'achat avec stop-loss approprié."
        }
        
        // Signal d'achat modéré
        if reading.combinedSignal == .buy {
            return "⚠️ SIGNAL D'ACHAT MODÉRÉ\n\nSignal d'achat présent, mais confluence moyenne (\(String(format: "%.0f%%", snapshot.confluencePercent))). Le signal n'est pas très fiable.\n\n→ Attendre une meilleure confluence ou confirmation sur d'autres timeframes."
        }
        
        // Signal de vente fort
        if reading.combinedSignal == .sell && snapshot.confluencePercent > 70 {
            return "❌ SIGNAL DE VENTE FORT\n\nRSI (\(Int(reading.rsiValue))) et VMC (\(String(format: "%.1f", reading.vmcValue))) sont alignés pour un signal de vente. La confluence est haute (\(String(format: "%.0f%%", snapshot.confluencePercent))).\n\n→ Éviter les achats, envisager une position courte."
        }
        
        // Signal de vente modéré
        if reading.combinedSignal == .sell {
            return "⚠️ SIGNAL DE VENTE MODÉRÉ\n\nSignal de vente présent, mais confluence moyenne (\(String(format: "%.0f%%", snapshot.confluencePercent))).\n\n→ Prudence à l'achat, mais pas de signal de vente très fort."
        }
        
        // Neutre
        return "⏸ SIGNAL NEUTRE\n\nRSI (\(Int(reading.rsiValue))) et VMC (\(String(format: "%.1f", reading.vmcValue))) ne donnent pas de direction claire. Score combiné : \(String(format: "%.1f", reading.combinedScore)).\n\n→ Attendre un signal plus net avant de prendre position."
    }
    
    private func getRecommendationBackgroundColor(reading: MTFReading) -> Color {
        if reading.hasDivergence && reading.divergenceType == .rsiBullishVMCBearish {
            return Color.red.opacity(0.15)
        }
        if reading.hasDivergence && reading.divergenceType == .rsiBearishVMCBullish {
            return Color.orange.opacity(0.15)
        }
        if reading.combinedSignal == .buy && snapshot.confluencePercent > 70 {
            return Color.green.opacity(0.15)
        }
        if reading.combinedSignal == .sell && snapshot.confluencePercent > 70 {
            return Color.red.opacity(0.15)
        }
        return Color.white.opacity(0.05)
    }
    
    private func getRecommendationBorderColor(reading: MTFReading) -> Color {
        if reading.hasDivergence && reading.divergenceType == .rsiBullishVMCBearish {
            return .red
        }
        if reading.hasDivergence && reading.divergenceType == .rsiBearishVMCBullish {
            return .orange
        }
        if reading.combinedSignal == .buy && snapshot.confluencePercent > 70 {
            return .green
        }
        if reading.combinedSignal == .sell && snapshot.confluencePercent > 70 {
            return .red
        }
        return Color.white.opacity(0.3)
    }
    
    // MARK: - Detailed Explanation Card
    
    @ViewBuilder
    private func detailedExplanationCard(reading: MTFReading) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(t("ai"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                explanationRow(
                    icon: "📈",
                    title: "Situation",
                    content: getSituationExplanation(reading: reading)
                )
                
                explanationRow(
                    icon: "💪",
                    title: "Force (VMC)",
                    content: getForceExplanation(reading: reading)
                )
                
                explanationRow(
                    icon: "⏰",
                    title: "Timing (RSI)",
                    content: getTimingExplanation(reading: reading)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    @ViewBuilder
    private func explanationRow(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(icon)
                    .font(.title3)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    private func getSituationExplanation(reading: MTFReading) -> String {
        if reading.hasDivergence {
            if reading.divergenceType == .rsiBullishVMCBearish {
                return "RSI et VMC en conflit. Le RSI (\(Int(reading.rsiValue))) est bas (attractif), mais le VMC (\(String(format: "%.1f", reading.vmcValue))) montre une force baissière. C'est un PIÈGE - le marché peut continuer à baisser."
            } else {
                return "Divergence constructive. Le VMC (\(String(format: "%.1f", reading.vmcValue))) montre de la force haussière, mais le RSI (\(Int(reading.rsiValue))) est encore haut. Possible retournement en cours."
            }
        } else {
            return "RSI et VMC sont alignés (\(reading.combinedSignal.displayName)). Le timing et la force pointent dans la même direction, ce qui renforce la fiabilité du signal."
        }
    }
    
    private func getForceExplanation(reading: MTFReading) -> String {
        let vmcValue = reading.vmcValue
        let absVMC = abs(vmcValue)
        
        if absVMC > 35 {
            let direction = vmcValue > 0 ? "haussière" : "baissière"
            return "VMC très fort (\(String(format: "%.1f", vmcValue))) → Force \(direction) INTENSE. Le mouvement a une forte probabilité de se poursuivre."
        } else if absVMC > 25 {
            let direction = vmcValue > 0 ? "haussière" : "baissière"
            return "VMC modéré (\(String(format: "%.1f", vmcValue))) → Force \(direction) présente mais modérée. Le mouvement est engagé mais peut s'inverser."
        } else {
            return "VMC faible (\(String(format: "%.1f", vmcValue))) → Force directionnelle limitée. Marché en zone neutre sans pression claire."
        }
    }
    
    private func getTimingExplanation(reading: MTFReading) -> String {
        let rsiValue = reading.rsiValue
        
        if rsiValue < 30 {
            return "RSI très bas (\(Int(rsiValue))) → SURVENTE. Timing suggère une opportunité d'achat car le prix est probablement arrivé à un point bas. ⚠️ Vérifier le VMC pour éviter les pièges."
        } else if rsiValue > 70 {
            return "RSI très haut (\(Int(rsiValue))) → SURACHAT. Timing suggère une possible correction. Prudence à l'achat, sauf si VMC très haussier."
        } else if rsiValue < 50 {
            return "RSI neutre-bas (\(Int(rsiValue))) → Timing neutre à légèrement baissier. Pas de signal d'entrée fort."
        } else {
            return "RSI neutre-haut (\(Int(rsiValue))) → Timing neutre à légèrement haussier. Le marché a de la force mais sans signal d'achat clair."
        }
    }
    
    // MARK: - Technical Data Section
    
    @ViewBuilder
    private func technicalDataSection(reading: MTFReading) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(t("DonnesTechniques"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
                Text(t("pourLesCurieux"))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // RSI
            technicalDataCard(
                title: "RSI",
                icon: "R",
                iconColor: rsiGradientColor(reading.rsiValue),
                items: [
                    ("Valeur brute", String(format: "%.1f", reading.rsiValue)),
                    ("Normalisé", String(format: "%.1f", reading.rsiNormalized)),
                    ("Statut", reading.rsiStatus.displayName)
                ]
            )
            
            // VMC
            technicalDataCard(
                title: "VMC",
                icon: "V",
                iconColor: .orange,
                items: [
                    ("Valeur", String(format: "%.1f", reading.vmcValue)),
                    ("Statut", reading.vmcStatus.displayName)
                ]
            )
            
            // Score combiné
            technicalDataCard(
                title: "Score Combiné",
                icon: "Σ",
                iconColor: combinedScoreColor(reading.combinedScore),
                items: [
                    ("Valeur", String(format: "%.1f", reading.combinedScore)),
                    ("Formule", "RSI×40% + VMC×60%"),
                    ("Signal", reading.combinedSignal.displayName)
                ]
            )
            
            // Confluence
            if !reading.hasDivergence {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("indicateurs"))
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(t("rsi"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    @ViewBuilder
    private func technicalDataCard(title: String, icon: String, iconColor: Color, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(icon)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(iconColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(iconColor.opacity(0.2))
                    )
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                ForEach(items, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(item.1)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}
