// GPTAnalysisRenderer.swift
// Journal de trading 2025
//
// Rendu premium analyse GPT — design system cohérent
// Réutilise ScoreRadial et TradeScenarioCard (Components/)
// Composants propres : AnalysisHeader · DCollapsibleSection
//                      ScoreDetailSheet · TradeExplanationSheet

import SwiftUI

// ─────────────────────────────────────────────────
// MARK: - Design Tokens
// ─────────────────────────────────────────────────

private enum DT {
    static let cardBG    = Color(hex: "#131722")
    static let pageBG    = Color(hex: "#0B0D14")
    static let border    = Color.white.opacity(0.07)
    static let divider   = Color.white.opacity(0.08)
    static let label     = Color.white.opacity(0.45)
    static let value     = Color.white
    static let bull      = Color(hex: "#26D97F")
    static let bear      = Color(hex: "#FF3B55")
    static let warning   = Color(hex: "#FFB800")
    static let info      = Color(hex: "#0A85FF")
    static let r: CGFloat    = 16
    static let p: CGFloat    = 16
    static let gap: CGFloat  = 12
    static let lsz: CGFloat  = 12
    static let vsz: CGFloat  = 13
    static let ssz: CGFloat  = 14

    static func scoreColor(_ s: Double) -> Color {
        switch s {
        case 0..<4:  return Color(hex: "#FF3B55")
        case 4..<7:  return Color(hex: "#FFB800")
        case 7..<9:  return Color(hex: "#26D97F")
        default:     return Color(hex: "#00FF88")
        }
    }
    static func scoreLabel(_ s: Double) -> String {
        switch s {
        case 0..<4:  return "Faible"
        case 4..<7:  return "Neutre"
        case 7..<9:  return "Solide"
        default:     return "Haute probabilité"
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - Entry Point
// ─────────────────────────────────────────────────

struct GPTAnalysisRenderer: View {
   
    let text:   String
    let symbol: String

    @State private var showScoreDetail = false
    @State private var showBullInfo    = false
    @State private var showBearInfo    = false
    @State private var showProbModal   = false
    @State private var selectedTF: GPTTimeframe = .h1
    @ObservedObject private var languageManager = LanguageManager.shared

    let currentPrice: Double

    init(text: String, symbol: String = "", currentPrice: Double = 0) {
        self.text         = text
        self.symbol       = symbol
        self.currentPrice = currentPrice
    }

    private var data: GPTAnalysis { GPTParser.parse(text) }

    var body: some View {
        let isEN = languageManager.currentLanguage == .english
        return VStack(alignment: .leading, spacing: DT.gap) {

            // ① Header compact
            GPTAnalysisHeader(
                symbol:       symbol.isEmpty ? data.symbol : symbol,
                score:        data.score,
                bullProb:     data.bullProb,
                currentPrice: currentPrice,
                onScoreTap:   { showScoreDetail = true },
                onProbTap:    { showProbModal   = true }
            )

            // ② Plan de trade — multi-UT avec onglets
            if !data.timeframePlans.isEmpty {
                GPTSectionLabel(icon: "target", label: isEN ? "Trade Plan" : "Plan de Trade", color: DT.bull)

                // Onglets UT — centrés
                HStack(spacing: 8) {
                    ForEach(data.availableTimeframes, id: \.self) { tf in
                        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTF = tf } }) {
                            Text(tf.label)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(selectedTF == tf ? .black : DT.label)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedTF == tf ? DT.bull : Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Cartes bull/bear pour l'UT sélectionnée
                if let plan = data.timeframePlans[selectedTF] {
                    HStack(alignment: .top, spacing: DT.gap) {
                        GPTTradeCard(kind: .bull, trade: plan.bull, onInfo: { showBullInfo = true })
                        GPTTradeCard(kind: .bear, trade: plan.bear, onInfo: { showBearInfo = true })
                    }
                }
            } else if data.hasTrade {
                // Fallback : scénario unique (ancien format)
                GPTSectionLabel(icon: "target", label: isEN ? "Trade Plan" : "Plan de Trade", color: DT.bull)
                HStack(alignment: .top, spacing: DT.gap) {
                    GPTTradeCard(kind: .bull, trade: data.bull, onInfo: { showBullInfo = true })
                    GPTTradeCard(kind: .bear, trade: data.bear, onInfo: { showBearInfo = true })
                }
            }

            // ③ Analyse technique — directement sous le plan de trade
            if !data.technicalLines.isEmpty {
                DCollapsibleSection(
                    icon: "chart.xyaxis.line", label: isEN ? "Technical Analysis" : "Analyse Technique",
                    color: DT.info, preview: data.technicalPreview
                ) { GPTKVCard(lines: data.technicalLines, accent: DT.info) }
            }

            // ④ Gestion du risque
            if !data.riskLines.isEmpty {
                GPTSectionLabel(icon: "shield.checkered", label: isEN ? "Risk Management" : "Gestion du Risque", color: DT.bear)
                GPTKVCard(lines: data.riskLines, accent: DT.bear)
            }

            // ⑤ Timing & contexte
            if !data.timingLines.isEmpty {
                GPTSectionLabel(icon: "clock.badge.checkmark", label: isEN ? "Timing & Context" : "Timing & Contexte", color: DT.warning)
                GPTKVCard(lines: data.timingLines, accent: DT.warning)
            }

            // ⑥ Informations importantes — avec news Bloomberg et icônes d'impact
            if !data.infoLines.isEmpty {
                DCollapsibleSection(
                    icon: "bolt.fill", label: isEN ? "Important Information" : "Informations Importantes",
                    color: DT.warning, preview: data.infoPreview
                ) { GPTNewsCard(lines: data.infoLines) }
            }

            // ⑦ Analyse fondamentale (collapsible, si action)
            if !data.fundamentalLines.isEmpty {
                DCollapsibleSection(
                    icon: "building.2.crop.circle", label: isEN ? "Fundamental Analysis" : "Analyse Fondamentale",
                    color: Color(hex: "#00E5FF"), preview: data.fundamentalPreview
                ) { GPTKVCard(lines: data.fundamentalLines, accent: Color(hex: "#00E5FF")) }
            }
        }
        // ── Sheets ──────────────────────────────────────────────
        .sheet(isPresented: $showScoreDetail) {
            GPTScoreDetailSheet(data: data)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBullInfo) {
            let plan = data.timeframePlans[selectedTF]
            TradeInfoSheet(kind: .bull, trade: plan?.bull ?? data.bull)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBearInfo) {
            let plan = data.timeframePlans[selectedTF]
            TradeInfoSheet(kind: .bear, trade: plan?.bear ?? data.bear)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProbModal) {
            ProbModal(bullProb: data.bullProb, bearProb: data.bearProb)
                .presentationDetents([.height(210)])
                .presentationDragIndicator(.visible)
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - GPTAnalysisHeader
// ─────────────────────────────────────────────────

private struct GPTAnalysisHeader: View {
    let symbol:       String
    let score:        Double
    let bullProb:     Int
    let currentPrice: Double
    let onScoreTap:   () -> Void
    let onProbTap:    () -> Void

    private var priceStr: String {
        guard currentPrice > 0 else { return "" }
        if currentPrice >= 10_000 {
            return String(format: "%.0f $", currentPrice)
        } else if currentPrice >= 100 {
            return String(format: "%.2f $", currentPrice)
        } else if currentPrice >= 1 {
            return String(format: "%.4f $", currentPrice)
        } else {
            return String(format: "%.6f $", currentPrice)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {

            // Gauche : nom + prix + niveau
            VStack(alignment: .leading, spacing: 3) {
                Text(symbol.uppercased())
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(DT.value)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !priceStr.isEmpty {
                    Text(priceStr)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Text(DT.scoreLabel(score))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DT.scoreColor(score))
            }

            Spacer()

            // Probabilité haussière compacte
            if bullProb > 0 {
                Button(action: onProbTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(DT.bull)
                        Text("\(bullProb)%")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(DT.bull)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(DT.bull.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(DT.bull.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            // Score radial (composant existant)
            ScoreRadial(
                score: Int(score.rounded()),
                size: 72,
                lineWidth: 6,
                showLabel: false,
                onTap: onScoreTap
            )
            .frame(width: 72, height: 72)
        }
        .padding(.horizontal, DT.p)
        .padding(.vertical, 14)
        .background(DT.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: DT.r))
        .overlay(RoundedRectangle(cornerRadius: DT.r).stroke(DT.border, lineWidth: 1))
    }
}

// ─────────────────────────────────────────────────
// MARK: - GPTTradeCard  (wraps GPTTradeData → TradeScenario)
// ─────────────────────────────────────────────────

private enum GPTTradeKind { case bull, bear }

private struct GPTTradeCard: View {
    let kind:    GPTTradeKind
    let trade:   GPTTradeData
    let onInfo:  () -> Void

    @ObservedObject private var languageManager = LanguageManager.shared
    private var accent: Color  { kind == .bull ? DT.bull : DT.bear }
    private var isEN: Bool { languageManager.currentLanguage == .english }

    var body: some View {
        let scenarioTitle = kind == .bull
            ? (isEN ? "Bullish Scenario" : "Scénario Haussier")
            : (isEN ? "Bearish Scenario" : "Scénario Baissier")
        return VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 7, height: 7).padding(.top, 3)
                    Text(scenarioTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(accent)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15))
                        .foregroundColor(DT.label)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 6)

            // Type d'entrée (placeholder si absent → hauteur cohérente)
            Group {
                if trade.entryType.isEmpty {
                    Text(" ").font(.system(size: 10))
                } else {
                    Text(trade.entryType)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DT.label)
                }
            }
            .padding(.bottom, 8)

            // Bloc 1 : Entrée / Stop
            tradeRow(isEN ? "Entry" : "Entrée", value: trade.entree, color: accent)
            tradeRow("Stop",   value: trade.stop,   color: DT.bear)

            thin.padding(.vertical, 8)

            // Bloc 2 : TP
            HStack(spacing: 4) {
                Image(systemName: "target").font(.system(size: 9)).foregroundColor(DT.label)
                Text(isEN ? "Targets" : "Objectifs").font(.system(size: 10, weight: .semibold)).foregroundColor(DT.label)
            }.padding(.bottom, 5)

            tpRow("TP1", value: trade.tp1, rr: trade.rr1)
            tpRow("TP2", value: trade.tp2, rr: trade.rr2)
            // TP3 toujours présent → alignement garanti
            tpRow("TP3", value: trade.tp3.isEmpty ? "—" : trade.tp3, rr: nil)
                .opacity(trade.tp3.isEmpty ? 0.30 : 1.0)

            thin.padding(.vertical, 8)

            // Bloc 3 : Synthèse %
            HStack {
                miniStat(isEN ? "Risk" : "Risque",    val: trade.riskPct.isEmpty   ? "—" : trade.riskPct,   color: DT.bear)
                Spacer()
                miniStat(isEN ? "Potential" : "Potentiel", val: trade.rewardPct.isEmpty ? "—" : trade.rewardPct, color: DT.bull)
            }
        }
        .padding(DT.p)
        .frame(maxWidth: .infinity, minHeight: 252, alignment: .topLeading)
        .background(DT.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: DT.r))
        .overlay(RoundedRectangle(cornerRadius: DT.r).stroke(accent.opacity(0.22), lineWidth: 1))
    }

    private var thin: some View { Rectangle().fill(DT.divider).frame(height: 1) }

    private func tradeRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.system(size: DT.lsz, weight: .medium)).foregroundColor(DT.label)
            Spacer()
            Text(value.isEmpty ? "—" : value).font(.system(size: DT.vsz, weight: .semibold)).foregroundColor(color)
        }.padding(.bottom, 4)
    }

    private func tpRow(_ label: String, value: String, rr: String?) -> some View {
        HStack {
            Text(label).font(.system(size: DT.lsz, weight: .medium)).foregroundColor(DT.label).frame(width: 28, alignment: .leading)
            if let rr, !rr.isEmpty {
                Text(rr).font(.system(size: 9, weight: .medium)).foregroundColor(DT.label)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.white.opacity(0.06)).clipShape(Capsule())
            }
            Spacer()
            Text(value).font(.system(size: DT.vsz, weight: .semibold)).foregroundColor(DT.value)
        }.padding(.bottom, 3)
    }

    private func miniStat(_ label: String, val: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundColor(DT.label)
            Text(val).font(.system(size: 13, weight: .black)).foregroundColor(color)
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - DCollapsibleSection (générique)
// ─────────────────────────────────────────────────

struct DCollapsibleSection<Content: View>: View {
    let icon:    String
    let label:   String
    let color:   Color
    let preview: String
    @ViewBuilder let content: () -> Content
    @State private var open = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.22)) { open.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(color).frame(width: 16)
                    Text(label).font(.system(size: DT.ssz, weight: .semibold)).foregroundColor(DT.value)
                    Spacer()
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .medium)).foregroundColor(DT.label)
                }
                .padding(.horizontal, DT.p).padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !open && !preview.isEmpty {
                Text(preview).font(.system(size: 11)).foregroundColor(DT.label).lineLimit(2)
                    .padding(.horizontal, DT.p).padding(.bottom, 12)
            }

            if open {
                Rectangle().fill(DT.divider).frame(height: 1).padding(.horizontal, DT.p)
                content().padding(DT.p).padding(.top, 4)
            }
        }
        .background(DT.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: DT.r))
        .overlay(RoundedRectangle(cornerRadius: DT.r).stroke(DT.border, lineWidth: 1))
    }
}

// ─────────────────────────────────────────────────
// MARK: - GPTSectionLabel
// ─────────────────────────────────────────────────

private struct GPTSectionLabel: View {
    let icon:  String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(color)
            Text(label).font(.system(size: DT.ssz, weight: .semibold)).foregroundColor(DT.value)
        }
        .padding(.horizontal, 2)
    }
}

// ─────────────────────────────────────────────────
// MARK: - GPTKVCard (carte clé-valeur générique)
// ─────────────────────────────────────────────────

private struct GPTKVCard: View {
    let lines:  [String]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(lines, id: \.self) { line in
                lineView(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DT.p)
        .background(DT.cardBG)
        .clipShape(RoundedRectangle(cornerRadius: DT.r))
        .overlay(RoundedRectangle(cornerRadius: DT.r).stroke(DT.border, lineWidth: 1))
    }

    @ViewBuilder
    private func lineView(_ line: String) -> some View {
        if line.hasPrefix("-") || line.hasPrefix("•") {
            HStack(alignment: .top, spacing: 6) {
                Text("·").font(.system(size: 12, weight: .bold)).foregroundColor(accent.opacity(0.7)).frame(width: 10)
                Text(line.dropFirst().trimmingCharacters(in: .whitespaces))
                    .font(.system(size: DT.vsz)).foregroundColor(Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if line.contains(":") {
            let parts = line.components(separatedBy: ":")
            let k = parts[0].trimmingCharacters(in: .whitespaces)
            let v = parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            HStack(alignment: .top, spacing: 8) {
                Text(k + ":")
                    .font(.system(size: DT.lsz, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.50))
                    .frame(minWidth: 88, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(v.isEmpty ? Localizable.text("dataUnavailable", language: LanguageManager.shared.currentLanguage) : v)
                    .font(.system(size: DT.lsz))
                    .foregroundColor(Color.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if !line.isEmpty {
            Text(line).font(.system(size: DT.vsz)).foregroundColor(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - GPTScoreDetailSheet
// ─────────────────────────────────────────────────

struct GPTScoreDetailSheet: View {
    let data: GPTAnalysis
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Score radial centré
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            ScoreRadial(score: Int(data.score.rounded()), size: 96, lineWidth: 7, showLabel: true, onTap: nil)
                        }
                        Spacer()
                    }

                    if !data.bias.isEmpty {
                        HStack(spacing: 8) {
                            Text("Biais dominant").font(.system(size: 12)).foregroundColor(DT.label)
                            Text(data.bias).font(.system(size: 12, weight: .bold))
                                .foregroundColor(data.bias.lowercased().contains("haussier") ? DT.bull : DT.bear)
                        }
                    }

                    // Sous-scores
                    if !data.subScores.isEmpty {
                        Divider().opacity(0.12)
                        Text("Sous-scores").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        ForEach(data.subScores, id: \.label) { sub in
                            GPTSubScoreRow(sub: sub)
                        }
                    }

                    // Explication
                    if !data.scoreExplanation.isEmpty {
                        Divider().opacity(0.12)
                        Text("Explication").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        Text(data.scoreExplanation)
                            .font(.system(size: 13)).foregroundColor(.white.opacity(0.75)).lineSpacing(5)
                    }
                }
                .padding(22)
            }
            .background(DT.pageBG.ignoresSafeArea())
            .navigationTitle("Détails du Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }.foregroundColor(.cyan)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct GPTSubScoreRow: View {
    let sub: GPTSubScore

    var body: some View {
        HStack(spacing: 10) {
            Text(sub.label).font(.system(size: 12, weight: .medium)).foregroundColor(DT.label).frame(width: 115, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.07)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(DT.scoreColor(sub.value)).frame(width: geo.size.width * min(sub.value / 10, 1.0), height: 5)
                }
            }
            .frame(height: 5)
            Text(sub.value == floor(sub.value) ? "\(Int(sub.value))" : String(format: "%.1f", sub.value))
                .font(.system(size: 12, weight: .bold)).foregroundColor(DT.scoreColor(sub.value)).frame(width: 30, alignment: .trailing)
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - TradeInfoSheet  (icône i)
// ─────────────────────────────────────────────────

private struct TradeInfoSheet: View {
    let kind:  GPTTradeKind
    let trade: GPTTradeData
    @Environment(\.dismiss) var dismiss

    private var accent: Color  { kind == .bull ? DT.bull : DT.bear }
    
    /// Construit les raisons à partir des données du trade si reasons est vide
    private var effectiveReasons: [String] {
        if !trade.reasons.isEmpty { return trade.reasons }
        var r: [String] = []
        if !trade.entryType.isEmpty {
            r.append("Setup : \(trade.entryType)")
        }
        if !trade.entree.isEmpty && !trade.stop.isEmpty {
            r.append("Entrée à \(trade.entree), invalidation sous \(trade.stop)")
        }
        if !trade.tp1.isEmpty {
            let direction = kind == .bull ? "haussier" : "baissier"
            r.append("TP1 à \(trade.tp1) — objectif \(direction) court terme")
        }
        if !trade.tp2.isEmpty {
            r.append("TP2 à \(trade.tp2) — objectif structurel")
        }
        if !trade.tp3.isEmpty {
            r.append("TP3 à \(trade.tp3) — extension / zone de liquidité")
        }
        if r.isEmpty { r.append("Scénario basé sur l'analyse de structure") }
        return r
    }
    
    /// Construit les conditions de validation
    private var effectiveConditions: [String] {
        if !trade.conditions.isEmpty { return trade.conditions }
        var c: [String] = []
        if !trade.entryType.isEmpty {
            if trade.entryType.lowercased().contains("pullback") {
                c.append("Attendre le pullback vers la zone d'entrée avant d'entrer")
            } else if trade.entryType.lowercased().contains("breakout") || trade.entryType.lowercased().contains("cassure") {
                c.append("Attendre une clôture au-dessus/en-dessous du niveau avec volume")
            } else if trade.entryType.lowercased().contains("sweep") {
                c.append("Confirmer le sweep de liquidité puis le retournement")
            } else if trade.entryType.lowercased().contains("rejet") || trade.entryType.lowercased().contains("retest") {
                c.append("Attendre le rejet confirmé par une bougie de retournement")
            }
        }
        if !trade.rr1.isEmpty {
            c.append("R:R minimum de \(trade.rr1) requis pour valider l'entrée")
        }
        c.append("Vérifier la confluence avec WaveTrend et VMC avant d'entrer")
        return c
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    infoGroup("Pourquoi ce scénario ?",     icon: "questionmark.circle",
                              items: effectiveReasons)
                    infoGroup("Conditions de validation",   icon: "checkmark.circle",
                              items: effectiveConditions)
                    if !trade.invalidation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Invalidation", systemImage: "xmark.circle")
                                .font(.system(size: 13, weight: .semibold)).foregroundColor(DT.bear)
                            Text(trade.invalidation)
                                .font(.system(size: 12)).foregroundColor(.white.opacity(0.78))
                                .padding(12).background(DT.bear.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    if !trade.risks.isEmpty {
                        infoGroup("Risques", icon: "exclamationmark.triangle", items: trade.risks, itemColor: DT.warning)
                    }
                }
                .padding(22)
            }
            .background(DT.pageBG.ignoresSafeArea())
            .navigationTitle("Pourquoi ce scénario ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }.foregroundColor(accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func infoGroup(_ title: String, icon: String, items: [String], itemColor: Color = Color.white.opacity(0.78)) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .semibold)).foregroundColor(accent)
            ForEach(items.prefix(3), id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(accent.opacity(0.5)).frame(width: 5, height: 5).padding(.top, 5)
                    Text(item).font(.system(size: 12)).foregroundColor(itemColor).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────
// MARK: - ProbModal
// ─────────────────────────────────────────────────

private struct ProbModal: View {
    let bullProb: Int
    let bearProb: Int
    private var isEN: Bool { LanguageManager.shared.currentLanguage == .english }

    var body: some View {
        VStack(spacing: 16) {
            Text(Localizable.text("scenarioProbabilityTitle", language: LanguageManager.shared.currentLanguage))
                .font(.system(size: 15, weight: .bold)).foregroundColor(.white).padding(.top, 20)
            VStack(spacing: 12) {
                GPTProbBar(label: Localizable.text("bullishLabel", language: LanguageManager.shared.currentLanguage), pct: Double(bullProb), color: DT.bull)
                GPTProbBar(label: Localizable.text("bearishLabel", language: LanguageManager.shared.currentLanguage), pct: Double(bearProb), color: DT.bear)
            }.padding(.horizontal, 24)
            Spacer()
        }
        .background(DT.pageBG.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

private struct GPTProbBar: View {
    let label: String
    let pct:   Double
    let color: Color
    @State private var w: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.system(size: 13, weight: .semibold)).foregroundColor(color)
                Spacer()
                Text("\(Int(pct))%").font(.system(size: 16, weight: .black)).foregroundColor(color)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.07)).frame(height: 10)
                    RoundedRectangle(cornerRadius: 5).fill(color).frame(width: g.size.width * w / 100.0, height: 10)
                        .animation(.easeOut(duration: 0.55), value: w)
                }
            }
            .frame(height: 10)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { w = pct } }
    }
}


// ─────────────────────────────────────────────────
// MARK: - GPTNewsCard (informations importantes avec impact)
// ─────────────────────────────────────────────────

private struct GPTNewsCard: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(lines, id: \.self) { line in
                newsRow(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func newsRow(_ line: String) -> some View {
        let impact = detectImpact(line)
        let cleaned = cleanLine(line)

        if !cleaned.isEmpty {
            HStack(alignment: .top, spacing: 10) {
                // Icône ⚡ colorée selon l'impact
                ZStack {
                    Circle()
                        .fill(impact.bgColor)
                        .frame(width: 26, height: 26)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(impact.fgColor)
                }
                .padding(.top, 1)
                

                newsTextBlock(cleaned)
            }
            .padding(12)
            .background(impact.bgColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(impact.bgColor.opacity(0.15), lineWidth: 1))
        }
    }

    private enum NewsImpact {
        case bullish, neutral, bearish, unknown
        var bgColor: Color {
            switch self {
            case .bullish: return Color(hex: "#26D97F")
            case .neutral: return Color.white
            case .bearish: return Color(hex: "#FF3B55")
            case .unknown: return Color(hex: "#0A85FF")
            }
        }
        var fgColor: Color {
            switch self {
            case .bullish: return .black
            case .neutral: return Color.black.opacity(0.7)
            case .bearish: return .white
            case .unknown: return .white
            }
        }
    }

    @ViewBuilder
    private func newsTextBlock(_ cleaned: String) -> some View {
        let sep = " — "
        if cleaned.contains(sep) {
            let idx = cleaned.range(of: sep)!
            let titre = String(cleaned[cleaned.startIndex..<idx.lowerBound])
            let consequence = String(cleaned[idx.upperBound...])
            VStack(alignment: .leading, spacing: 3) {
                Text(titre)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
                Text(consequence)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            Text(cleaned)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detectImpact(_ line: String) -> NewsImpact {
        let up = line.uppercased()
        if up.contains("HAUSSIER") || up.contains("BULLISH") || up.contains("HAUSSE") { return .bullish }
        if up.contains("BAISSIER") || up.contains("BEARISH") || up.contains("BAISSE") { return .bearish }
        if up.contains("NEUTRE") || up.contains("NEUTRAL")  { return .neutral }
        return .unknown
    }

    private func cleanLine(_ line: String) -> String {
        var s = line
        // Supprimer les balises d'impact
        for tag in ["[⚡HAUSSIER]", "[⚡BAISSIER]", "[⚡NEUTRE]", "⚡HAUSSIER", "⚡BAISSIER", "⚡NEUTRE",
                    "- [HAUSSIER]", "- [BAISSIER]", "- [NEUTRE]",
                    "[HAUSSIER]", "[BAISSIER]", "[NEUTRE]"] {
            s = s.replacingOccurrences(of: tag, with: "")
        }
        // Supprimer bullets
        s = s.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("-") || s.hasPrefix("•") { s = String(s.dropFirst()).trimmingCharacters(in: .whitespaces) }
        return s
    }
}



// ─────────────────────────────────────────────────
// MARK: - Models (noms préfixés GPT pour éviter conflits)
// ─────────────────────────────────────────────────

// Unité de temps disponibles
enum GPTTimeframe: String, CaseIterable, Hashable {
    case m15   = "M15"
    case h1    = "H1"
    case h4    = "H4"
    case daily = "Daily"

    var label: String { rawValue }
    var order: Int {
        switch self { case .m15: return 0; case .h1: return 1; case .h4: return 2; case .daily: return 3 }
    }
}

// Plan pour une UT (bull + bear)
struct GPTTimeframePlan {
    var bull: GPTTradeData = GPTTradeData()
    var bear: GPTTradeData = GPTTradeData()
}

struct GPTAnalysis {
    var symbol:           String        = ""
    var score:            Double        = 5.0
    var bias:             String        = ""
    var bullProb:         Int           = 50
    var bearProb:         Int           = 50
    // Legacy (fallback)
    var bull:             GPTTradeData  = GPTTradeData()
    var bear:             GPTTradeData  = GPTTradeData()
    // Multi-UT
    var timeframePlans:   [GPTTimeframe: GPTTimeframePlan] = [:]
    var riskLines:        [String]      = []
    var timingLines:      [String]      = []
    var technicalLines:   [String]      = []
    var infoLines:        [String]      = []
    var fundamentalLines: [String]      = []
    var subScores:        [GPTSubScore] = []
    var scoreExplanation: String        = ""

    var hasTrade:          Bool   { !bull.entree.isEmpty || !bear.entree.isEmpty || !bull.tp1.isEmpty || !bear.tp1.isEmpty }
    var availableTimeframes: [GPTTimeframe] {
        GPTTimeframe.allCases.filter { timeframePlans[$0] != nil }.sorted { $0.order < $1.order }
    }
    var technicalPreview:  String { technicalLines.prefix(2).joined(separator: " · ") }
    var infoPreview:       String { infoLines.prefix(2).joined(separator: " · ") }
    var fundamentalPreview:String { fundamentalLines.prefix(2).joined(separator: " · ") }
}

struct GPTTradeData {
    var entryType:    String   = ""
    var entree:       String   = ""
    var stop:         String   = ""
    var tp1:          String   = ""
    var tp2:          String   = ""
    var tp3:          String   = ""
    var rr1:          String   = ""
    var rr2:          String   = ""
    var riskPct:      String   = ""
    var rewardPct:    String   = ""
    var invalidation: String   = ""
    var reasons:      [String] = []
    var conditions:   [String] = []
    var risks:        [String] = []
}

struct GPTSubScore {
    let label: String
    let value: Double
}

// ─────────────────────────────────────────────────
// MARK: - Parser
// ─────────────────────────────────────────────────

enum GPTParser {

    static func parse(_ raw: String) -> GPTAnalysis {
        var r    = GPTAnalysis()
        let lines = raw.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var sec    = 0
        var curTF: GPTTimeframe? = nil
        var bull   = false
        var bear   = false

        for line in lines {
            if line.isEmpty || line.allSatisfy({ "─-=".contains($0) }) { continue }

            let sectionMap: [(String, Int)] = [
                ("1️⃣",1),("2️⃣",2),("3️⃣",3),("4️⃣",4),("5️⃣",5),
                ("6️⃣",6),("7️⃣",7),("8️⃣",8),("9️⃣",9)
            ]
            if let match = sectionMap.first(where: { line.contains($0.0) }) {
                sec = match.1; bull = false; bear = false; curTF = nil; continue
            }

            switch sec {
            case 1: p1(&r, line)
            case 2: p2(&r, line)
            case 3: p3(&r, &curTF, &bull, &bear, line)
            case 4: r.riskLines.append(line)
            case 5: r.timingLines.append(line)
            case 6: r.technicalLines.append(line)
            case 7: r.infoLines.append(line)
            case 8: r.fundamentalLines.append(line)
            case 9: r.scoreExplanation += (r.scoreExplanation.isEmpty ? "" : " ") + line
            default: break
            }
        }
        return r
    }

    // Section 1 — Score IA
    private static func p1(_ r: inout GPTAnalysis, _ line: String) {
        let l = line.lowercased()
        if (l.contains("score") || l.contains("score ia")) && line.contains("/") {
            r.score = num(line, fallback: 5)
        } else if l.contains("biais") {
            r.bias = val(line)
        } else {
            let map: [(String, String)] = [
                ("structure","Structure"),("volume","Volume"),("momentum","Momentum"),
                ("news","News"),("sentiment","Sentiment"),("fondamentaux","Fondamentaux")
            ]
            for (k, label) in map where l.contains(k) {
                let v = num(line, fallback: -1)
                if v >= 0 { r.subScores.append(GPTSubScore(label: label, value: v)) }
            }
        }
    }

    // Section 2 — Probabilités
    private static func p2(_ r: inout GPTAnalysis, _ line: String) {
        let l = line.lowercased()
        if l.contains("haussière") || l.contains("haussier") { r.bullProb = numI(line, fallback: 50) }
        else if l.contains("baissière") || l.contains("baissier") { r.bearProb = numI(line, fallback: 50) }
    }

    // Section 3 — Plan de trade multi-UT avec capture reasons/conditions
    private static func fill(_ t: inout GPTTradeData, _ line: String) {
        let l = line.lowercased()
        let v = cleanPrice(val(line))
        if l.contains("type d'entrée") || l.contains("type entrée") || l.contains("type de setup") || l.contains("entry type") { t.entryType = cleanPrice(val(line), keepText: true) }
        else if l.hasPrefix("entrée") || l.hasPrefix("entree") || l.hasPrefix("entry")      { t.entree = v }
        else if l.hasPrefix("stop")   { t.stop  = v }
        else if l.contains("rr tp1") || l.contains("rr tp1") { t.rr1   = val(line) }
        else if l.contains("rr tp2") || l.contains("rr tp2") { t.rr2   = val(line) }
        else if l.contains("tp1")    { t.tp1   = v }
        else if l.contains("tp2")    { t.tp2   = v }
        else if l.contains("tp3")    { t.tp3   = v }
        else if (l.contains("risque") || l.contains("risk")) && (l.contains("%") || l.contains("pct")) { t.riskPct = val(line) }
        else if l.contains("potentiel") || l.contains("reward") { t.rewardPct = val(line) }
        else if l.contains("invalidation") || l.contains("invalidat") { t.invalidation = val(line) }
    }
    
    /// Capture la description de structure comme "reasons" pour le sheet info
    private static func p3(
        _ r: inout GPTAnalysis,
        _ curTF: inout GPTTimeframe?,
        _ inBull: inout Bool,
        _ inBear: inout Bool,
        _ line: String
    ) {
        let up = line.uppercased()

        // Détecter le timeframe
        if line.contains("⏱️") || (up.contains("TIMEFRAME") && !up.contains("SCÉNARIO")) {
            if      up.contains("M15")   { curTF = .m15 }
            else if up.contains("H1")    { curTF = .h1  }
            else if up.contains("H4")    { curTF = .h4  }
            else if up.contains("DAILY") || up.contains("JOURNALIER") { curTF = .daily }
            inBull = false; inBear = false
            return
        }

        let isBull = line.contains("🟢") || (up.contains("SCÉNARIO") && up.contains("HAUSSIER")) || (up.contains("BULLISH") && up.contains("SCENARIO"))
        let isBear = line.contains("🔴") || (up.contains("SCÉNARIO") && up.contains("BAISSIER")) || (up.contains("BEARISH") && up.contains("SCENARIO"))

        if isBull { inBull = true;  inBear = false; return }
        if isBear { inBull = false; inBear = true;  return }
        
        // Capturer la ligne "Structure XX :" comme reason pour les deux scénarios
        let l = line.lowercased()
        if l.contains("structure") && (l.contains("hh") || l.contains("hl") || l.contains("lh") || l.contains("ll") || l.contains("bos") || l.contains("mss") || l.contains("ob") || l.contains("fvg") || l.contains(":")) {
            if let tf = curTF {
                if r.timeframePlans[tf] == nil { r.timeframePlans[tf] = GPTTimeframePlan() }
                let structLine = val(line).isEmpty ? line : val(line)
                r.timeframePlans[tf]!.bull.reasons.append(structLine)
                r.timeframePlans[tf]!.bear.reasons.append(structLine)
            }
            return
        }

        if let tf = curTF {
            if r.timeframePlans[tf] == nil { r.timeframePlans[tf] = GPTTimeframePlan() }
            if inBull {
                fill(&r.timeframePlans[tf]!.bull, line)
                // Capturer les lignes descriptives comme reasons
                if !line.isEmpty && !l.hasPrefix("entrée") && !l.hasPrefix("entree") && !l.hasPrefix("entry") && !l.hasPrefix("stop") && !l.contains("tp1") && !l.contains("tp2") && !l.contains("tp3") && !l.contains("rr tp") && !l.contains("type d'entrée") && !l.contains("type entrée") && !l.contains("entry type") && !l.contains("type de setup") && !l.contains("invalidation") && !l.contains("risque") && !l.contains("risk") && !l.contains("potentiel") && !l.contains("reward") {
                    // C'est une ligne descriptive/explicative
                    if l.contains("confirmation") || l.contains("condition") || l.contains("valider") || l.contains("validé") || l.contains("validate") {
                        r.timeframePlans[tf]!.bull.conditions.append(line)
                    } else if l.contains("justification") || l.contains("raison") || l.contains("pourquoi") || l.contains("car ") || l.contains("parce") || l.contains("grâce") || l.contains("contexte") || l.contains("context") || l.contains("signal") || l.contains("cross") || l.contains("sweep") || l.contains("pullback") || l.contains("breakout") || l.contains("rejet") || l.contains("rejection") || l.contains("retest") {
                        r.timeframePlans[tf]!.bull.reasons.append(line)
                    }
                }
            } else if inBear {
                fill(&r.timeframePlans[tf]!.bear, line)
                if !line.isEmpty && !l.hasPrefix("entrée") && !l.hasPrefix("entree") && !l.hasPrefix("entry") && !l.hasPrefix("stop") && !l.contains("tp1") && !l.contains("tp2") && !l.contains("tp3") && !l.contains("rr tp") && !l.contains("type d'entrée") && !l.contains("type entrée") && !l.contains("entry type") && !l.contains("type de setup") && !l.contains("invalidation") && !l.contains("risque") && !l.contains("risk") && !l.contains("potentiel") && !l.contains("reward") {
                    if l.contains("confirmation") || l.contains("condition") || l.contains("valider") || l.contains("validé") || l.contains("validate") {
                        r.timeframePlans[tf]!.bear.conditions.append(line)
                    } else if l.contains("justification") || l.contains("raison") || l.contains("pourquoi") || l.contains("car ") || l.contains("parce") || l.contains("grâce") || l.contains("contexte") || l.contains("context") || l.contains("signal") || l.contains("cross") || l.contains("sweep") || l.contains("pullback") || l.contains("breakout") || l.contains("rejet") || l.contains("rejection") || l.contains("retest") {
                        r.timeframePlans[tf]!.bear.reasons.append(line)
                    }
                }
            }
        } else {
            if inBull { fill(&r.bull, line) }
            else if inBear { fill(&r.bear, line) }
        }
    }
        
        // Nettoyer les espaces superflus dans les nombres (ex: "68 000" → "68 000" garder)
    

    // Helpers
    // Nettoyer les valeurs de prix (supprimer USDT, USD, $, espaces)
    static func cleanPrice(_ s: String, keepText: Bool = false) -> String {
        if keepText { return s.trimmingCharacters(in: .whitespaces) }
        var result = s
        for suffix in [" USDT", " USD", " $", "USDT", "USD", "$", "€"] {
            result = result.replacingOccurrences(of: suffix, with: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    static func val(_ line: String) -> String {
        guard let r = line.range(of: ":") else { return line }
        return String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
    }
    static func num(_ text: String, fallback: Double) -> Double {
        if let r = text.range(of: #"\d+\.?\d*\s*/\s*10"#, options: .regularExpression) {
            return Double(String(text[r]).components(separatedBy: "/").first?.trimmingCharacters(in: .whitespaces) ?? "") ?? fallback
        }
        if let r = text.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
            return Double(String(text[r])) ?? fallback
        }
        return fallback
    }
    static func numI(_ text: String, fallback: Int) -> Int {
        if let r = text.range(of: #"\d+"#, options: .regularExpression) {
            return Int(String(text[r])) ?? fallback
        }
        return fallback
    }

    }
