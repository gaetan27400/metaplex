//
//  AnalysePDFService.swift
//  Journal de trading 2025
//
//  Rapport PDF professionnel 1 page — UIGraphicsPDFRenderer natif iOS
//

import UIKit

// MARK: - Design System

private enum DS {
    // ── Dimensions A4 ──────────────────────────────
    static let W: CGFloat  = 595
    static let H: CGFloat  = 842
    static let mX: CGFloat = 28          // marge latérale réduite
    static let mY: CGFloat = 16          // marge verticale réduite
    static var cW: CGFloat { W - mX * 2 }

    // ── Couleurs ────────────────────────────────────
    static let bg      = UIColor(hex: "#0B0D14")
    static let surface = UIColor(hex: "#131722")
    static let card    = UIColor(hex: "#1A1E2E")
    static let cardHi  = UIColor(hex: "#1F2438")
    static let border  = UIColor(white: 1, alpha: 0.08)
    static let sep     = UIColor(white: 1, alpha: 0.06)

    // Accents
    static let cyan    = UIColor(hex: "#00E5FF")
    static let cyanDim = UIColor(hex: "#00B8CC")
    static let gold    = UIColor(hex: "#FFB800")
    static let purple  = UIColor(hex: "#9B6DFF")
    static let green   = UIColor(hex: "#26D97F")
    static let red     = UIColor(hex: "#FF3B55")
    static let orange  = UIColor(hex: "#FF8C00")
    static let blue    = UIColor(hex: "#1E90FF")

    // Texte
    static let t1 = UIColor(white: 1.00, alpha: 1)
    static let t2 = UIColor(white: 0.78, alpha: 1)
    static let t3 = UIColor(white: 0.52, alpha: 1)
    static let t4 = UIColor(white: 0.32, alpha: 1)

    // ── Typographie compacte (1 page) ───────────────
    static let fTitle    = UIFont.systemFont(ofSize: 15, weight: .black)
    static let fH1       = UIFont.systemFont(ofSize: 11, weight: .bold)
    static let fH2       = UIFont.systemFont(ofSize: 9.5, weight: .semibold)
    static let fH3       = UIFont.systemFont(ofSize: 8.5, weight: .semibold)
    static let fBody     = UIFont.systemFont(ofSize: 7.5, weight: .regular)
    static let fBodyM    = UIFont.systemFont(ofSize: 7.5, weight: .medium)
    static let fSmall    = UIFont.systemFont(ofSize: 6.5, weight: .regular)
    static let fSmallB   = UIFont.systemFont(ofSize: 6.5, weight: .bold)
    static let fMono     = UIFont.monospacedSystemFont(ofSize: 7.5, weight: .regular)
    static let fMonoB    = UIFont.monospacedSystemFont(ofSize: 7.5, weight: .bold)
    static let fMonoSm   = UIFont.monospacedSystemFont(ofSize: 6.5, weight: .regular)
    static let fLabel    = UIFont.systemFont(ofSize: 6, weight: .semibold)
}

// UIColor from hex
private extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        if h.count == 6 { h += "FF" }
        let v = UInt64(h, radix: 16) ?? 0
        self.init(red: CGFloat((v >> 24) & 0xFF) / 255,
                  green: CGFloat((v >> 16) & 0xFF) / 255,
                  blue: CGFloat((v >> 8) & 0xFF) / 255,
                  alpha: CGFloat(v & 0xFF) / 255)
    }
}

// MARK: - AnalysePDFService

final class AnalysePDFService {

    static func generate(
        symbol: String,
        enrichedAnalysis: String,
        gptAnalysis: String = "",
        confluence: String,
        fundingRate: Double,
        recommendations: [String],
        mtfSnapshot: MTFSnapshot?,
        wtSnapshot: WTSnapshot?,
        vmcOscSnapshot: VMCOscillatorSnapshot? = nil,
        heatmapData: LiquidityHeatmapData? = nil,
        isCrypto: Bool = false
    ) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: DS.W, height: DS.H)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        return renderer.pdfData { ctx in
            // ── PAGE 1 ────────────────────────────────────
            ctx.beginPage()
            let g = ctx.cgContext
            let overflow = drawMainPage(g,
                           symbol: symbol,
                           enrichedAnalysis: enrichedAnalysis,
                           gptAnalysis: gptAnalysis,
                           confluence: confluence,
                           fundingRate: fundingRate,
                           recommendations: recommendations,
                           mtf: mtfSnapshot,
                           wt: wtSnapshot,
                           vmc: vmcOscSnapshot,
                           heatmap: heatmapData,
                           isCrypto: isCrypto)

            // ── PAGE 2 (si graphiques VMC/WT n'ont pas pu être rendus) ──
            if overflow.needsPage2 {
                ctx.beginPage()
                let g2 = ctx.cgContext
                drawOverflowPage(g2,
                                 vmc: vmcOscSnapshot,
                                 wt: wtSnapshot,
                                 vmcRendered: overflow.vmcRendered,
                                 wtRendered: overflow.wtRendered)
            }
        }
    }

    /// Résultat de la page 1 indiquant si des graphiques n'ont pas pu être dessinés
    private struct PageOverflow {
        var vmcRendered: Bool
        var wtRendered: Bool
        var needsPage2: Bool { !vmcRendered || !wtRendered }

        init(vmcRendered: Bool, wtRendered: Bool, hasVMC: Bool, hasWT: Bool) {
            self.vmcRendered = vmcRendered || !hasVMC
            self.wtRendered = wtRendered || !hasWT
        }
    }

    // MARK: - Main Page Layout

    @discardableResult
    private static func drawMainPage(
        _ g: CGContext,
        symbol: String,
        enrichedAnalysis: String,
        gptAnalysis: String = "",
        confluence: String,
        fundingRate: Double,
        recommendations: [String],
        mtf: MTFSnapshot?,
        wt: WTSnapshot?,
        vmc: VMCOscillatorSnapshot? = nil,
        heatmap: LiquidityHeatmapData? = nil,
        isCrypto: Bool = false
    ) -> PageOverflow {
        // ── FOND ─────────────────────────────────────
        DS.bg.setFill()
        g.fill(CGRect(x: 0, y: 0, width: DS.W, height: DS.H))

        // ── HEADER COMPACT ───────────────────────────
        let headerH: CGFloat = 52
        drawHeader(g, symbol: symbol, mtf: mtf, height: headerH)

        var y: CGFloat = headerH + 10

        // ── LIGNE SIGNAL GLOBAL ──────────────────────
        if let mtf = mtf {
            y = drawSignalBand(g, mtf: mtf, y: y)
        }
        y += 6

        // ── LAYOUT : Colonne gauche large + colonne droite ───────
        let colGap: CGFloat = 8
        let hasHeatmap = isCrypto && heatmap != nil && !(heatmap!.snapshots.isEmpty)

        // Si crypto avec heatmap : 3 bandes horizontales
        // Sinon : 2 colonnes standard
        let leftW: CGFloat  = DS.cW * 0.40
        let rightW: CGFloat = DS.cW - leftW - colGap
        let leftX  = DS.mX
        let rightX = DS.mX + leftW + colGap

        let columnTopY = y

        // ── COLONNE GAUCHE ───────────────────────────
        var ly = columnTopY

        // KPI cards 2x2
        ly = drawKPIGrid(g, confluence: confluence, fundingRate: fundingRate,
                         mtf: mtf, wt: wt, y: ly, w: leftW)
        ly += 6

        // Recommandations IA (avant les graphiques)
        let recoMax = 2
        ly = drawRecoSection(g, items: recommendations, y: ly, w: leftW, x: leftX, maxItems: recoMax)
        ly += 6

        // VMC Oscillator chart (sous recommandations)
        let heatmapTopY = DS.H - 130 - 22  // réserve espace heatmap
        let maxChartY = hasHeatmap ? heatmapTopY - 10 : DS.H - DS.mY - 20

        // Indicateurs de rendu pour page 2 éventuelle
        var vmcRendered = false
        var wtRendered = false

        if let vmc = vmc, vmc.readings.count > 2, ly < maxChartY - 40 {
            ly = drawVMCSection(g, vmc: vmc, y: ly, w: leftW, x: leftX)
            ly += 5
            vmcRendered = true
        }

        // Wave Trend chart (sous VMC)
        if let wt = wt, wt.readings.count > 2, ly < maxChartY - 40 {
            ly = drawWTSection(g, wt: wt, y: ly, w: leftW, x: leftX)
            ly += 5
            wtRendered = true
        }

        // ── COLONNE DROITE ───────────────────────────
        var ry = columnTopY

        // Limite basse colonne droite (au-dessus heatmap ou footer)
        let rightMaxY: CGFloat = hasHeatmap ? (DS.H - 130 - 22 - 8) : (DS.H - DS.mY - 20)

        if !gptAnalysis.isEmpty {
            // Contenu GPT parsé (Score IA + Trade Plan + Risk + Technical + Timing + Info + Fundamental)
            ry = drawGPTContent(g, gptText: gptAnalysis, y: ry, x: rightX, w: rightW, maxY: rightMaxY)
        } else {
            // Fallback : texte enrichi local
            ry = drawAnalysisBlock(g, text: enrichedAnalysis, y: ry, x: rightX, w: rightW)
            ry += 4
            if let mtf = mtf {
                ry = drawMTFTableCompact(g, mtf: mtf, y: ry, x: rightX, w: rightW)
                ry += 4
            }
        }

        // ── HEATMAP DE LIQUIDATION (crypto uniquement) ───────────
        if hasHeatmap, let heatmap = heatmap {
            // Bande pleine largeur en bas de page
            let heatmapH: CGFloat = 130
            let heatmapY = DS.H - heatmapH - 22  // au-dessus du footer
            drawLiquidationHeatmap(g, data: heatmap, y: heatmapY,
                                    x: DS.mX, w: DS.cW, h: heatmapH)
        }

        // ── FOOTER ──────────────────────────────────
        drawPageFooter(g)

        let hasVMC = vmc != nil && (vmc?.readings.count ?? 0) > 2
        let hasWT = wt != nil && (wt?.readings.count ?? 0) > 2
        return PageOverflow(vmcRendered: vmcRendered, wtRendered: wtRendered,
                            hasVMC: hasVMC, hasWT: hasWT)
    }

    // MARK: - Overflow Page (VMC / WT charts that didn't fit)

    private static func drawOverflowPage(
        _ g: CGContext,
        vmc: VMCOscillatorSnapshot?,
        wt: WTSnapshot?,
        vmcRendered: Bool,
        wtRendered: Bool
    ) {
        // Fond
        DS.bg.setFill()
        g.fill(CGRect(x: 0, y: 0, width: DS.W, height: DS.H))

        var y: CGFloat = DS.mY + 10
        let chartW = DS.cW * 0.85  // Plus large sur page 2

        // Titre page 2
        label("INDICATEURS TECHNIQUES", font: DS.fH1, color: DS.cyan,
              at: CGPoint(x: DS.mX, y: y), g: g)
        DS.cyan.withAlphaComponent(0.35).setFill()
        g.fill(CGRect(x: DS.mX, y: y + 14, width: DS.cW, height: 0.6))
        y += 24

        if !vmcRendered, let vmc = vmc, vmc.readings.count > 2 {
            y = drawVMCSection(g, vmc: vmc, y: y, w: chartW, x: DS.mX)
            y += 20
        }

        if !wtRendered, let wt = wt, wt.readings.count > 2 {
            y = drawWTSection(g, wt: wt, y: y, w: chartW, x: DS.mX)
            y += 20
        }

        drawPageFooter(g)
    }

    // MARK: - GPT Content (colonne droite)

    @discardableResult
    private static func drawGPTContent(
        _ g: CGContext,
        gptText: String,
        y: CGFloat, x: CGFloat, w: CGFloat, maxY: CGFloat
    ) -> CGFloat {
        let data = GPTParser.parse(gptText)
        var cy = y

        // ── Score IA ──────────────────────────────
        let scoreColor: UIColor = data.score >= 7 ? DS.green : data.score >= 5 ? DS.gold : DS.red
        let scoreBg = scoreColor.withAlphaComponent(0.12)
        let scoreBoxH: CGFloat = 28
        g.fillRoundedRect(CGRect(x: x, y: cy, width: w, height: scoreBoxH), radius: 4, color: scoreBg)
        scoreColor.withAlphaComponent(0.8).setFill()
        g.fillRoundedRect(CGRect(x: x, y: cy, width: 2.5, height: scoreBoxH), radius: 2, color: scoreColor)

        let scoreTitle = "SCORE IA"
        label(scoreTitle, font: DS.fLabel, color: DS.t3, at: CGPoint(x: x + 8, y: cy + 4), g: g)
        let scoreStr = String(format: "%.1f / 10", data.score)
        label(scoreStr, font: UIFont.monospacedSystemFont(ofSize: 13, weight: .bold), color: scoreColor,
              at: CGPoint(x: x + 8, y: cy + 13), g: g)
        // Sous-scores si présents
        if !data.subScores.isEmpty {
            var scx = x + 60
            for ss in data.subScores.prefix(3) {
                let col: UIColor = ss.value >= 3 ? DS.green : ss.value >= 1.5 ? DS.gold : DS.red
                label("\(ss.label) \(Int(ss.value))", font: DS.fLabel, color: col,
                      at: CGPoint(x: scx, y: cy + 8), g: g)
                scx += 48
            }
        }
        // Biais
        if !data.bias.isEmpty {
            rLabel(data.bias, font: DS.fSmallB, color: scoreColor, rightX: x + w - 4, y: cy + 4, g: g)
        }
        // Probabilités
        let probStr = "▲ \(data.bullProb)%  ▼ \(data.bearProb)%"
        rLabel(probStr, font: DS.fLabel, color: DS.t3, rightX: x + w - 4, y: cy + 15, g: g)
        cy += scoreBoxH + 6

        // ── Trade Plan MTF ────────────────────────
        let tfs = data.availableTimeframes
        if !tfs.isEmpty, cy < maxY - 30 {
            sectionTitle(g, text: "TRADE PLAN", accent: DS.cyan, y: cy, x: x, w: w)
            cy += 13

            // En-tête colonnes
            let tfW: CGFloat = 38
            let side: CGFloat = (w - tfW) / 2 - 2
            DS.cardHi.setFill(); g.fillRoundedRect(CGRect(x: x, y: cy, width: w, height: 12), radius: 2, color: DS.cardHi)
            // Bull/Bear probas header
            let bullW = (w - tfW) / 2
            DS.green.withAlphaComponent(0.25).setFill()
            g.fill(CGRect(x: x + tfW, y: cy, width: bullW, height: 12))
            DS.red.withAlphaComponent(0.25).setFill()
            g.fill(CGRect(x: x + tfW + bullW, y: cy, width: bullW, height: 12))
            label("UT", font: DS.fLabel, color: DS.gold, at: CGPoint(x: x + 3, y: cy + 2), g: g)
            label("▲ LONG", font: DS.fLabel, color: DS.green, at: CGPoint(x: x + tfW + 3, y: cy + 2), g: g)
            rLabel("SHORT ▼", font: DS.fLabel, color: DS.red, rightX: x + w - 3, y: cy + 2, g: g)
            cy += 13

            for tf in tfs.prefix(4) {
                guard cy < maxY - 34 else { break }
                guard let plan = data.timeframePlans[tf] else { continue }
                let bull = plan.bull; let bear = plan.bear

                // Row bg — taller rows to avoid overlap
                let rowH: CGFloat = 30
                g.fillRoundedRect(CGRect(x: x, y: cy, width: w, height: rowH), radius: 2, color: DS.card)
                // UT label
                DS.gold.withAlphaComponent(0.15).setFill()
                g.fill(CGRect(x: x, y: cy, width: tfW, height: rowH))
                label(tf.label, font: DS.fSmallB, color: DS.gold, at: CGPoint(x: x + 4, y: cy + 10), g: g)

                // Bull side — 3 rows: In + SL | TP1 + TP2 | R:R
                let bullX = x + tfW + 2
                let lineH: CGFloat = 8.5
                var bly = cy + 2
                if !bull.entree.isEmpty {
                    label("In \(bull.entree)", font: DS.fMonoSm, color: DS.green, at: CGPoint(x: bullX, y: bly), g: g)
                    bly += lineH
                }
                if !bull.stop.isEmpty {
                    label("SL \(bull.stop)", font: DS.fMonoSm, color: DS.red, at: CGPoint(x: bullX, y: bly), g: g)
                    bly += lineH
                }
                // TP on a second column within bull side
                bly = cy + 2
                let tpOffset: CGFloat = min(side * 0.52, 58)
                if !bull.tp1.isEmpty {
                    label("TP1 \(bull.tp1)", font: DS.fMonoSm, color: DS.t2, at: CGPoint(x: bullX + tpOffset, y: bly), g: g)
                    bly += lineH
                }
                if !bull.tp2.isEmpty {
                    label("TP2 \(bull.tp2)", font: DS.fMonoSm, color: DS.t2, at: CGPoint(x: bullX + tpOffset, y: bly), g: g)
                }
                if !bull.rr1.isEmpty {
                    label("R:\(bull.rr1)", font: DS.fLabel, color: DS.cyan, at: CGPoint(x: bullX, y: cy + rowH - 8), g: g)
                }

                // Séparateur vertical
                DS.sep.setFill(); g.fill(CGRect(x: x + tfW + side, y: cy + 2, width: 0.5, height: rowH - 4))

                // Bear side
                let bearX = x + tfW + side + 4
                bly = cy + 2
                if !bear.entree.isEmpty {
                    label("In \(bear.entree)", font: DS.fMonoSm, color: DS.red, at: CGPoint(x: bearX, y: bly), g: g)
                    bly += lineH
                }
                if !bear.stop.isEmpty {
                    label("SL \(bear.stop)", font: DS.fMonoSm, color: DS.red, at: CGPoint(x: bearX, y: bly), g: g)
                }
                bly = cy + 2
                if !bear.tp1.isEmpty {
                    label("TP1 \(bear.tp1)", font: DS.fMonoSm, color: DS.t2, at: CGPoint(x: bearX + tpOffset, y: bly), g: g)
                    bly += lineH
                }
                if !bear.tp2.isEmpty {
                    label("TP2 \(bear.tp2)", font: DS.fMonoSm, color: DS.t2, at: CGPoint(x: bearX + tpOffset, y: bly), g: g)
                }
                if !bear.rr1.isEmpty {
                    label("R:\(bear.rr1)", font: DS.fLabel, color: DS.cyan, at: CGPoint(x: bearX, y: cy + rowH - 8), g: g)
                }

                DS.sep.setFill(); g.fill(CGRect(x: x, y: cy + rowH, width: w, height: 0.3))
                cy += rowH + 1
            }
            cy += 4
        }

        // ── Risk Management ───────────────────────
        if !data.riskLines.isEmpty, cy < maxY - 20 {
            sectionTitle(g, text: "RISK MANAGEMENT", accent: DS.red, y: cy, x: x, w: w)
            cy += 13
            cy = drawCompactLines(g, lines: data.riskLines, x: x, y: cy, w: w, maxY: maxY, accent: DS.red)
            cy += 4
        }

        // ── Timing & Context ─────────────────────
        if !data.timingLines.isEmpty, cy < maxY - 20 {
            sectionTitle(g, text: "TIMING & CONTEXT", accent: DS.gold, y: cy, x: x, w: w)
            cy += 13
            cy = drawCompactLines(g, lines: data.timingLines, x: x, y: cy, w: w, maxY: maxY, accent: DS.gold)
            cy += 4
        }

        // ── Technical Analysis ────────────────────
        if !data.technicalLines.isEmpty, cy < maxY - 20 {
            sectionTitle(g, text: "TECHNICAL ANALYSIS", accent: DS.cyan, y: cy, x: x, w: w)
            cy += 13
            cy = drawCompactLines(g, lines: data.technicalLines, x: x, y: cy, w: w, maxY: maxY, accent: DS.cyan)
            cy += 4
        }

        // ── Important Information ─────────────────
        if !data.infoLines.isEmpty, cy < maxY - 20 {
            sectionTitle(g, text: "IMPORTANT INFORMATION", accent: DS.orange, y: cy, x: x, w: w)
            cy += 13
            cy = drawCompactLines(g, lines: data.infoLines, x: x, y: cy, w: w, maxY: maxY, accent: DS.orange)
            cy += 4
        }

        // ── Fundamental Analysis ──────────────────
        if !data.fundamentalLines.isEmpty, cy < maxY - 20 {
            sectionTitle(g, text: "FUNDAMENTAL ANALYSIS", accent: DS.purple, y: cy, x: x, w: w)
            cy += 13
            cy = drawCompactLines(g, lines: data.fundamentalLines, x: x, y: cy, w: w, maxY: maxY, accent: DS.purple)
            cy += 4
        }

        return cy
    }

    // Affiche des lignes de texte compactes avec bullet coloré
    @discardableResult
    private static func drawCompactLines(
        _ g: CGContext, lines: [String],
        x: CGFloat, y: CGFloat, w: CGFloat, maxY: CGFloat, accent: UIColor
    ) -> CGFloat {
        var cy = y
        for line in lines.prefix(6) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Measure true text height with word wrap
            let ps = NSMutableParagraphStyle()
            ps.lineBreakMode = .byWordWrapping
            ps.lineSpacing = 1.0
            let attr = NSAttributedString(string: trimmed, attributes: [
                .font: DS.fBody, .foregroundColor: DS.t2, .paragraphStyle: ps
            ])
            let bnd = attr.boundingRect(with: CGSize(width: w - 14, height: 60),
                                        options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            let lineH = max(ceil(bnd.height) + 3, 12)
            guard cy + lineH < maxY else { break }

            // Bullet
            accent.withAlphaComponent(0.7).setFill()
            g.fillEllipse(in: CGRect(x: x + 3, y: cy + 4, width: 3, height: 3))
            // Text — draw with full measured height for proper wrapping
            attr.draw(in: CGRect(x: x + 10, y: cy, width: w - 14, height: lineH))
            cy += lineH
        }
        return cy
    }

    // MARK: - Header compact

    private static func drawHeader(_ g: CGContext, symbol: String, mtf: MTFSnapshot?, height: CGFloat) {
        // Dégradé fond header
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [UIColor(hex: "#0D1B4B").cgColor, UIColor(hex: "#160D35").cgColor] as CFArray
        let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1])!
        g.saveGState()
        g.clip(to: CGRect(x: 0, y: 0, width: DS.W, height: height))
        g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: DS.W, y: height), options: [])
        g.restoreGState()

        // Ligne accent bas
        DS.cyan.withAlphaComponent(0.9).setFill()
        g.fill(CGRect(x: 0, y: height - 1.5, width: DS.W, height: 1.5))

        // Watermark géo décoratif
        drawGeoWatermark(g, cx: DS.W - 45, cy: height / 2, r: 28)

        // Texte header
        let now = DateFormatter()
        now.dateFormat = "dd MMM yyyy  ·  HH:mm"
        label("TRADEMINDSET", font: UIFont.systemFont(ofSize: 7, weight: .black),
              color: DS.cyan, at: CGPoint(x: DS.mX, y: 10), g: g)
        label("Rapport d'Analyse Technique", font: DS.fTitle, color: DS.t1,
              at: CGPoint(x: DS.mX, y: 22), g: g)

        // Badge actif + date
        let badgeText = "● \(symbol)"
        drawPill(g, text: badgeText, x: DS.mX, y: 38, w: 72, h: 10,
                 bg: DS.cyan.withAlphaComponent(0.18), textColor: DS.cyan, font: DS.fSmallB)
        rLabel(now.string(from: Date()), font: DS.fSmall, color: DS.t3,
               rightX: DS.W - DS.mX, y: 40, g: g)
    }

    private static func drawGeoWatermark(_ g: CGContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        g.saveGState()
        DS.cyan.withAlphaComponent(0.05).setStroke()
        g.setLineWidth(0.6)
        for i in 0..<3 {
            let ri = r - CGFloat(i) * 8
            g.strokeEllipse(in: CGRect(x: cx - ri, y: cy - ri, width: ri * 2, height: ri * 2))
        }
        g.restoreGState()
    }

    // MARK: - Signal Band

    private static func drawSignalBand(_ g: CGContext, mtf: MTFSnapshot, y: CGFloat) -> CGFloat {
        let h: CGFloat = 26
        let sig = mtf.globalSignal
        let sigColor = signalColor(sig)

        g.fillRoundedRect(CGRect(x: DS.mX, y: y, width: DS.cW, height: h),
                           radius: 5, color: sigColor.withAlphaComponent(0.10))
        g.fillRoundedRect(CGRect(x: DS.mX, y: y, width: 3, height: h),
                           radius: 2, color: sigColor)

        label("Signal Global :", font: DS.fSmall, color: DS.t3,
              at: CGPoint(x: DS.mX + 10, y: y + 4), g: g)
        label(sig.displayName.uppercased(), font: DS.fH2, color: sigColor,
              at: CGPoint(x: DS.mX + 78, y: y + 3), g: g)

        let score = mtf.globalCombinedScore
        rLabel("Score \(String(format: "%.1f", score))  ·  Confluence \(Int(mtf.confluencePercent))%",
               font: DS.fSmall, color: DS.t2, rightX: DS.W - DS.mX - 8, y: y + 7, g: g)

        return y + h + 4
    }

    // MARK: - KPI Grid 2x2 (colonne gauche)

    private static func drawKPIGrid(
        _ g: CGContext, confluence: String, fundingRate: Double,
        mtf: MTFSnapshot?, wt: WTSnapshot?, y: CGFloat, w: CGFloat
    ) -> CGFloat {
        let kW = (w - 5) / 2
        let kH: CGFloat = 38
        let items: [(String, String, UIColor)] = [
            ("Confluence",      confluence,                                    DS.green),
            ("Funding Rate",    String(format: "%+.3f%%", fundingRate * 100),
             fundingRate >= 0 ? DS.green : DS.red),
            ("Wave Trend",      wt.map { wtLabel($0) } ?? "—",
             wt.map { biasColor($0.currentMarketBias) } ?? DS.t3),
            ("Signal MTF",      mtf?.globalSignal.displayName ?? "—",
             signalColor(mtf?.globalSignal)),
        ]
        var row = 0; var col = 0
        for item in items {
            let x = DS.mX + CGFloat(col) * (kW + 5)
            let ky = y + CGFloat(row) * (kH + 4)
            kpiCard(g, x: x, y: ky, w: kW, h: kH,
                    label: item.0, value: item.1, color: item.2)
            col += 1
            if col == 2 { col = 0; row += 1 }
        }
        let rows = (items.count + 1) / 2
        return y + CGFloat(rows) * (kH + 4)
    }

    private static func kpiCard(_ g: CGContext, x: CGFloat, y: CGFloat,
                                 w: CGFloat, h: CGFloat,
                                 label lbl: String, value val: String, color: UIColor) {
        g.fillRoundedRect(CGRect(x: x, y: y, width: w, height: h), radius: 5, color: DS.card)
        g.strokeRoundedRect(CGRect(x: x + 0.5, y: y + 0.5, width: w - 1, height: h - 1),
                            radius: 5, color: DS.border, lineWidth: 0.5)
        color.withAlphaComponent(0.7).setFill()
        UIBezierPath(roundedRect: CGRect(x: x, y: y, width: 2.5, height: h),
                     byRoundingCorners: [.topLeft, .bottomLeft],
                     cornerRadii: CGSize(width: 5, height: 5)).fill()
        label(lbl, font: DS.fLabel, color: DS.t3, at: CGPoint(x: x + 8, y: y + 5), g: g)
        label(val, font: DS.fH3, color: color, at: CGPoint(x: x + 8, y: y + 18), g: g)
    }

    // MARK: - Recommandations (colonne gauche)

    private static func drawRecoSection(_ g: CGContext, items: [String],
                                         y: CGFloat, w: CGFloat, x: CGFloat,
                                         maxItems: Int = 4) -> CGFloat {
        guard !items.isEmpty else { return y }
        sectionTitle(g, text: "Recommandations IA", accent: DS.gold, y: y, x: x, w: w)
        var cy = y + 14

        for (i, rec) in items.prefix(maxItems).enumerated() {
            guard cy < DS.H - 80 else { break }
            // Pastille numéro
            let nr: CGFloat = 5.5
            DS.gold.withAlphaComponent(0.25).setFill()
            g.fillEllipse(in: CGRect(x: x, y: cy + 1, width: nr * 2, height: nr * 2))
            label("\(i + 1)", font: DS.fSmall, color: DS.gold,
                  at: CGPoint(x: x + (nr * 2 - 4.5) / 2, y: cy + 1.5), g: g)

            let ps = NSMutableParagraphStyle()
            ps.lineSpacing = 1.2
            let attr = NSAttributedString(string: rec, attributes: [
                .font: DS.fBody, .foregroundColor: DS.t2, .paragraphStyle: ps
            ])
            let bnd = attr.boundingRect(
                with: CGSize(width: w - 16, height: 80),
                options: .usesLineFragmentOrigin, context: nil)
            attr.draw(in: CGRect(x: x + 14, y: cy, width: w - 16, height: bnd.height + 1))
            cy += max(bnd.height, 11) + 3
        }
        return cy + 3
    }

    // MARK: - Wave Trend compact (colonne gauche)

    private static func drawWTSection(_ g: CGContext, wt: WTSnapshot,
                                       y: CGFloat, w: CGFloat, x: CGFloat) -> CGFloat {
        sectionTitle(g, text: "Wave Trend", accent: DS.cyan, y: y, x: x, w: w)
        var cy = y + 12

        // Badge signal + valeur actuelle
        let sigText = wt.currentSignal?.displayName ?? (wt.isOverbought ? "Surachat" : wt.isOversold ? "Survente" : "Neutre")
        let sigColor = wtSignalColor(wt.currentSignal) == DS.t3
            ? (wt.isOverbought ? DS.red : wt.isOversold ? DS.green : DS.t3)
            : wtSignalColor(wt.currentSignal)
        g.fillRoundedRect(CGRect(x: x, y: cy, width: w - 4, height: 11), radius: 3, color: sigColor.withAlphaComponent(0.15))
        sigColor.setFill(); g.fill(CGRect(x: x, y: cy, width: 1.5, height: 11))
        label(sigText, font: DS.fSmallB, color: sigColor, at: CGPoint(x: x + 5, y: cy + 2), g: g)
        rLabel(String(format: "WT1: %.1f", wt.currentWT1), font: DS.fMonoSm, color: DS.t2,
               rightX: x + w - 4, y: cy + 2, g: g)
        cy += 13

        // Graphique
        let readings = Array(wt.readings.suffix(60))
        guard readings.count > 2 else { return cy }

        let chartH: CGFloat = 38
        let chartX = x; let chartY = cy

        // Fond
        g.fillRoundedRect(CGRect(x: chartX, y: chartY, width: w, height: chartH), radius: 3, color: DS.surface)

        let allVals = readings.flatMap { [$0.wt1, $0.wt2] }
        let minV = min(allVals.min() ?? -60, wt.oversoldLevel * 1.1)
        let maxV = max(allVals.max() ?? 60, wt.overboughtLevel * 1.1)
        let rangeV = max(maxV - minV, 1.0)
        let n = readings.count
        let stepX = w / CGFloat(n - 1)

        func toY(_ v: Double) -> CGFloat {
            chartY + chartH - CGFloat((v - minV) / rangeV) * chartH
        }

        // Zones OB/OS colorées
        let obY = toY(wt.overboughtLevel); let osY = toY(wt.oversoldLevel)
        DS.red.withAlphaComponent(0.10).setFill()
        g.fill(CGRect(x: chartX, y: chartY, width: w, height: max(obY - chartY, 0)))
        DS.green.withAlphaComponent(0.10).setFill()
        g.fill(CGRect(x: chartX, y: osY, width: w, height: max(chartY + chartH - osY, 0)))

        // Lignes OB/OS/zero en pointillés
        for (lvl, col, alpha): (Double, UIColor, CGFloat) in [
            (wt.overboughtLevel, DS.red, 0.5),
            (wt.oversoldLevel, DS.green, 0.5),
            (0.0, DS.t4, 0.3)
        ] {
            let ly = toY(lvl)
            col.withAlphaComponent(alpha).setFill()
            var dX = chartX; while dX < chartX + w { g.fill(CGRect(x: dX, y: ly, width: 2, height: 0.4)); dX += 4 }
        }

        // Histogramme WT1−WT2 (barres centrées sur zéro)
        let zeroY = toY(0)
        for (i, r) in readings.enumerated() {
            let px = chartX + CGFloat(i) * stepX
            let hVal = r.wt1 - r.wt2
            let barTopY = hVal >= 0 ? toY(hVal) : zeroY
            let barH = max(abs(toY(hVal) - zeroY), 0.5)
            (hVal > 0 ? DS.green : DS.red).withAlphaComponent(0.30).setFill()
            g.fill(CGRect(x: px - 0.5, y: barTopY, width: max(stepX - 0.3, 0.8), height: barH))
        }

        // Ligne WT2 (rose/rouge — comme dans l'app)
        let pathWT2 = UIBezierPath()
        for (i, r) in readings.enumerated() {
            let pt = CGPoint(x: chartX + CGFloat(i) * stepX, y: toY(r.wt2))
            if i == 0 { pathWT2.move(to: pt) } else { pathWT2.addLine(to: pt) }
        }
        UIColor(red: 0.95, green: 0.25, blue: 0.55, alpha: 0.80).setStroke()
        pathWT2.lineWidth = 0.8; pathWT2.stroke()

        // Ligne WT1 (cyan — principale)
        let pathWT1 = UIBezierPath()
        for (i, r) in readings.enumerated() {
            let pt = CGPoint(x: chartX + CGFloat(i) * stepX, y: toY(r.wt1))
            if i == 0 { pathWT1.move(to: pt) } else { pathWT1.addLine(to: pt) }
        }
        DS.cyan.withAlphaComponent(0.90).setStroke()
        pathWT1.lineWidth = 1.1; pathWT1.stroke()

        // Dots de signal (reversals)
        for (i, r) in readings.enumerated() {
            guard let sig = r.signal else { continue }
            let px = chartX + CGFloat(i) * stepX; let py = toY(r.wt1)
            let isBull = sig == .bullishReversal || sig == .bullishSmartReversal
            let isSmart = sig == .bullishSmartReversal || sig == .bearishSmartReversal
            let dotC: UIColor = isBull ? DS.green : DS.red
            dotC.setFill()
            let r2: CGFloat = isSmart ? 2.5 : 1.8
            g.fillEllipse(in: CGRect(x: px - r2, y: py - r2, width: r2 * 2, height: r2 * 2))
            if isSmart {
                dotC.withAlphaComponent(0.35).setStroke(); g.setLineWidth(0.5)
                g.strokeEllipse(in: CGRect(x: px - r2 - 1, y: py - r2 - 1, width: (r2+1)*2, height: (r2+1)*2))
            }
        }

        // Marqueur valeur actuelle
        DS.cyan.setFill()
        let lastPx = chartX + CGFloat(n-1) * stepX; let lastPy = toY(wt.currentWT1)
        g.fillEllipse(in: CGRect(x: lastPx - 2, y: lastPy - 2, width: 4, height: 4))

        // Bordure subtile
        g.strokeRoundedRect(CGRect(x: chartX, y: chartY, width: w, height: chartH),
                            radius: 3, color: DS.cyan.withAlphaComponent(0.18), lineWidth: 0.5)

        // Légende
        cy += chartH + 3
        DS.cyan.setFill(); g.fill(CGRect(x: x, y: cy, width: 10, height: 1))
        label("WT1", font: DS.fLabel, color: DS.cyan, at: CGPoint(x: x + 12, y: cy - 3), g: g)
        UIColor(red: 0.95, green: 0.25, blue: 0.55, alpha: 0.8).setFill()
        g.fill(CGRect(x: x + 28, y: cy, width: 10, height: 1))
        label("WT2", font: DS.fLabel, color: UIColor(red: 0.95, green: 0.25, blue: 0.55, alpha: 0.8),
              at: CGPoint(x: x + 40, y: cy - 3), g: g)
        rLabel("Biais: \(wt.currentMarketBias.displayName)", font: DS.fLabel,
               color: biasColor(wt.currentMarketBias), rightX: x + w, y: cy - 3, g: g)
        return cy + 7
    }

    // MARK: - Analyse IA condensée (colonne droite)

    private static func drawAnalysisBlock(_ g: CGContext, text: String,
                                           y: CGFloat, x: CGFloat, w: CGFloat) -> CGFloat {
        sectionTitle(g, text: "Analyse IA", accent: DS.purple, y: y, x: x, w: w)
        var cy = y + 14

        // Budget vertical : 40% de la page pour l'analyse IA
        let maxY = DS.mY + (DS.H - DS.mY * 2) * 0.42 + y

        let paragraphs = text.components(separatedBy: "\n\n")
        var blockIdx = 0

        for para in paragraphs {
            let trimmed = para.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.contains("────") else { continue }
            guard cy < maxY - 20 else { break }

            let lines = trimmed.components(separatedBy: "\n")
            let isBlock = lines.count > 1

            if isBlock {
                let blockColor = blockAccent(index: blockIdx)
                let contentLines = lines.filter {
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !$0.contains("────")
                }.prefix(5) // max 5 lignes par bloc

                // Calculer hauteur
                var blockH: CGFloat = 6
                for (li, line) in contentLines.enumerated() {
                    let c = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    let font = li == 0 ? DS.fH3 : DS.fBody
                    let bnd = (c as NSString).boundingRect(
                        with: CGSize(width: w - 16, height: 100),
                        options: .usesLineFragmentOrigin,
                        attributes: [.font: font], context: nil)
                    blockH += min(bnd.height, 24) + 2
                }
                blockH = min(blockH + 4, 60) // plafonner chaque bloc

                if cy + blockH > maxY { break }

                g.fillRoundedRect(CGRect(x: x, y: cy, width: w, height: blockH),
                                   radius: 4, color: DS.card)
                blockColor.withAlphaComponent(0.7).setFill()
                g.fillRoundedRect(CGRect(x: x, y: cy, width: 2.5, height: blockH),
                                   radius: 2, color: blockColor)

                var bcy = cy + 5
                for (li, line) in contentLines.enumerated() {
                    let c = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !c.isEmpty else { continue }
                    let font  = li == 0 ? DS.fH3 : DS.fBody
                    let color = li == 0 ? DS.t1   : DS.t2
                    let attr = NSAttributedString(string: c, attributes: [
                        .font: font, .foregroundColor: color
                    ])
                    let bnd = attr.boundingRect(
                        with: CGSize(width: w - 12, height: 50),
                        options: .usesLineFragmentOrigin, context: nil)
                    attr.draw(in: CGRect(x: x + 8, y: bcy, width: w - 12, height: min(bnd.height + 1, 20)))
                    bcy += min(bnd.height, 18) + 2
                    if bcy > cy + blockH - 2 { break }
                }
                cy += blockH + 4
                blockIdx += 1
            } else {
                let attr = NSAttributedString(string: trimmed, attributes: [
                    .font: DS.fBody, .foregroundColor: DS.t3
                ])
                let bnd = attr.boundingRect(
                    with: CGSize(width: w, height: 30),
                    options: .usesLineFragmentOrigin, context: nil)
                if cy + bnd.height > maxY { break }
                attr.draw(in: CGRect(x: x, y: cy, width: w, height: bnd.height))
                cy += bnd.height + 3
            }
        }
        return cy + 4
    }

    private static func blockAccent(index: Int) -> UIColor {
        let colors = [DS.cyan, DS.purple, DS.gold, DS.green, DS.orange, DS.blue]
        return colors[index % colors.count]
    }

    // MARK: - MTF Table compacte (colonne droite, bas)

    @discardableResult
    private static func drawMTFTableCompact(_ g: CGContext, mtf: MTFSnapshot,
                                             y: CGFloat, x: CGFloat, w: CGFloat) -> CGFloat {
        guard y < DS.H - 80 else { return y }
        sectionTitle(g, text: "Dashboard Multi-Timeframe", accent: DS.gold, y: y, x: x, w: w)
        var cy = y + 14

        // Colonnes
        let tfW:    CGFloat = 36
        let sigW:   CGFloat = 60
        let rsiW:   CGFloat = 28
        let vmcW:   CGFloat = 32
        let scW:    CGFloat = 26
        let divW:   CGFloat = w - tfW - sigW - rsiW - vmcW - scW

        // En-tête
        DS.cardHi.setFill()
        UIBezierPath(roundedRect: CGRect(x: x, y: cy, width: w, height: 14),
                     byRoundingCorners: [.topLeft, .topRight],
                     cornerRadii: CGSize(width: 4, height: 4)).fill()
        DS.gold.setFill()
        g.fill(CGRect(x: x, y: cy, width: w, height: 1.2))

        let headers = [("UT", tfW), ("Signal", sigW), ("RSI", rsiW), ("VMC", vmcW), ("Score", scW), ("Div.", divW)]
        var cx = x
        for (hText, hW) in headers {
            label(hText, font: DS.fLabel, color: DS.gold,
                  at: CGPoint(x: cx + 3, y: cy + 4), g: g)
            cx += hW
        }
        cy += 15

        // Lignes — timeframes principaux uniquement
        let tfs: [VMCTimeframe] = [.d1, .h4, .h1, .m30, .m15]
        let rowH: CGFloat = 14

        for (row, tf) in tfs.enumerated() {
            guard let r = mtf.readings[tf] else { continue }
            guard cy + rowH < DS.H - 26 else { break }

            let rowBg = row % 2 == 0 ? DS.card : DS.surface
            g.fillRoundedRect(CGRect(x: x, y: cy, width: w, height: rowH),
                               radius: 0, color: rowBg)

            cx = x
            // Timeframe
            label(tf.displayName, font: DS.fSmallB, color: DS.t1,
                  at: CGPoint(x: cx + 3, y: cy + 3), g: g)
            cx += tfW

            // Signal badge
            let sc = signalColor(r.combinedSignal)
            g.fillRoundedRect(CGRect(x: cx + 2, y: cy + 2, width: sigW - 4, height: 10),
                               radius: 2, color: sc.withAlphaComponent(0.20))
            let sigText = r.combinedSignal.displayName
            let sigTW = (sigText as NSString).size(withAttributes: [.font: DS.fLabel]).width
            label(sigText, font: DS.fLabel, color: sc,
                  at: CGPoint(x: cx + 2 + (sigW - 4 - sigTW) / 2, y: cy + 3), g: g)
            cx += sigW

            // RSI
            let rsiCol = r.rsiValue > 70 ? DS.red : r.rsiValue < 30 ? DS.green : DS.t2
            label(String(format: "%.0f", r.rsiValue), font: DS.fMonoSm, color: rsiCol,
                  at: CGPoint(x: cx + 3, y: cy + 3), g: g)
            cx += rsiW

            // VMC
            let vmcCol = r.vmcValue > 0 ? DS.green : DS.red
            label(String(format: "%.1f", r.vmcValue), font: DS.fMonoSm, color: vmcCol,
                  at: CGPoint(x: cx + 2, y: cy + 3), g: g)
            cx += vmcW

            // Score
            let scScore = r.combinedScore
            let scCol2 = scScore > 0 ? DS.green : scScore < 0 ? DS.red : DS.t3
            let scText = String(format: "%.0f", scScore)
            label(scText, font: DS.fMonoB, color: scCol2,
                  at: CGPoint(x: cx + 3, y: cy + 3), g: g)
            cx += scW

            // Divergence
            if r.hasDivergence, let dt = r.divergenceType {
                let dText: String
                switch dt {
                case .rsiBullishVMCBearish: dText = "↑ Trap"
                case .rsiBearishVMCBullish: dText = "↓ Abs."
                }
                label(dText, font: DS.fLabel, color: DS.orange,
                      at: CGPoint(x: cx + 2, y: cy + 3), g: g)
            }

            DS.sep.setFill()
            g.fill(CGRect(x: x, y: cy + rowH, width: w, height: 0.5))
            cy += rowH
        }

        // Légende compacte
        cy += 4
        label("RSI>70: surachat  ·  RSI<30: survente  ·  VMC>0: haussier  ·  VMC<0: baissier",
              font: UIFont.systemFont(ofSize: 5.5, weight: .regular), color: DS.t4,
              at: CGPoint(x: x, y: cy), g: g)
        return cy + 10
    }

    // MARK: - VMC Oscillator Section (colonne gauche)

    @discardableResult
    private static func drawVMCSection(_ g: CGContext, vmc: VMCOscillatorSnapshot,
                                        y: CGFloat, w: CGFloat, x: CGFloat) -> CGFloat {
        sectionTitle(g, text: "VMC Oscillator", accent: DS.purple, y: y, x: x, w: w)
        var cy = y + 12

        // Badge signal
        let sigText: String; let sigColor: UIColor
        if let sig = vmc.currentSignal {
            switch sig {
            case .buy:       sigText = "BUY ▲";      sigColor = DS.green
            case .sell:      sigText = "SELL ▼";     sigColor = DS.red
            case .exitLong:  sigText = "EXIT LONG";  sigColor = DS.orange
            case .exitShort: sigText = "EXIT SHORT"; sigColor = DS.purple
            }
        } else {
            sigText = vmc.isOverbought ? "Surachat" : vmc.isOversold ? "Survente" : "Neutre"
            sigColor = vmc.isOverbought ? DS.red : vmc.isOversold ? DS.green : DS.t3
        }
        g.fillRoundedRect(CGRect(x: x, y: cy, width: w - 4, height: 11), radius: 3, color: sigColor.withAlphaComponent(0.15))
        sigColor.setFill(); g.fill(CGRect(x: x, y: cy, width: 1.5, height: 11))
        label(sigText, font: DS.fSmallB, color: sigColor, at: CGPoint(x: x + 5, y: cy + 2), g: g)
        rLabel(String(format: "Sig: %.2f", vmc.currentSig), font: DS.fMonoSm, color: DS.t2,
               rightX: x + w - 4, y: cy + 2, g: g)
        cy += 13

        // Graphique
        let readings = Array(vmc.readings.suffix(60))
        guard readings.count > 2 else { return cy }

        let chartH: CGFloat = 36
        let chartX = x; let chartY = cy

        // Fond
        g.fillRoundedRect(CGRect(x: chartX, y: chartY, width: w, height: chartH), radius: 3, color: DS.surface)

        let sigVals     = readings.map { $0.sig }
        let sigSigVals  = readings.map { $0.sigSignal }
        let momVals     = readings.map { $0.momentum }
        let allVals     = sigVals + sigSigVals
        let rawMin = allVals.min() ?? -2; let rawMax = allVals.max() ?? 2
        let pad = max(abs(rawMax), abs(rawMin)) * 0.12
        let minV = min(rawMin - pad, vmc.lowerThreshold * 1.1)
        let maxV = max(rawMax + pad, vmc.upperThreshold * 1.1)
        let rangeV = max(maxV - minV, 0.01)
        let n = readings.count
        let stepX = w / CGFloat(n - 1)

        func toY(_ v: Double) -> CGFloat {
            chartY + chartH - CGFloat((v - minV) / rangeV) * chartH
        }

        // Zones OB/OS
        let obY = toY(vmc.upperThreshold); let osY = toY(vmc.lowerThreshold)
        DS.red.withAlphaComponent(0.07).setFill()
        g.fill(CGRect(x: chartX, y: chartY, width: w, height: max(obY - chartY, 0)))
        DS.green.withAlphaComponent(0.07).setFill()
        g.fill(CGRect(x: chartX, y: osY, width: w, height: max(chartY + chartH - osY, 0)))

        // Lignes seuils + zéro
        for (lvl, col, alpha): (Double, UIColor, CGFloat) in [
            (vmc.upperThreshold, DS.red, 0.5),
            (vmc.lowerThreshold, DS.green, 0.5),
            (0.0, DS.t4, 0.3)
        ] {
            let ly = toY(lvl); col.withAlphaComponent(alpha).setFill()
            var dX = chartX; while dX < chartX + w { g.fill(CGRect(x: dX, y: ly, width: 2, height: 0.4)); dX += 4 }
        }

        // Barres momentum centrées sur zéro (vert/rouge)
        let zeroY = toY(0)
        let momAbsMax = max(momVals.map { abs($0) }.max() ?? 1, 0.01)
        let barMaxH = chartH * 0.42
        for (i, r) in readings.enumerated() {
            let px = chartX + CGFloat(i) * stepX
            let barH = CGFloat(abs(r.momentum) / momAbsMax) * barMaxH
            (r.momentum >= 0 ? DS.green : DS.red).withAlphaComponent(0.50).setFill()
            g.fill(CGRect(x: px, y: r.momentum >= 0 ? zeroY - barH : zeroY,
                          width: max(stepX - 0.3, 0.8), height: max(barH, 0.5)))
        }

        // Ligne sigSignal (orange — slow MA)
        let pathSS = UIBezierPath()
        for (i, r) in readings.enumerated() {
            let pt = CGPoint(x: chartX + CGFloat(i) * stepX, y: toY(r.sigSignal))
            if i == 0 { pathSS.move(to: pt) } else { pathSS.addLine(to: pt) }
        }
        UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.85).setStroke()
        pathSS.lineWidth = 0.9; pathSS.stroke()

        // Ligne sig (cyan — fast line)
        let pathS = UIBezierPath()
        for (i, r) in readings.enumerated() {
            let pt = CGPoint(x: chartX + CGFloat(i) * stepX, y: toY(r.sig))
            if i == 0 { pathS.move(to: pt) } else { pathS.addLine(to: pt) }
        }
        DS.cyan.withAlphaComponent(0.90).setStroke()
        pathS.lineWidth = 1.1; pathS.stroke()

        // Dots signaux buy/sell
        for (i, r) in readings.enumerated() {
            guard let sig = r.signal else { continue }
            let px = chartX + CGFloat(i) * stepX; let py = toY(r.sig)
            let dotC: UIColor = sig == .buy ? DS.green : sig == .sell ? DS.red : DS.orange
            dotC.setFill()
            g.fillEllipse(in: CGRect(x: px - 2, y: py - 2, width: 4, height: 4))
            if sig == .buy || sig == .sell {
                dotC.withAlphaComponent(0.30).setStroke(); g.setLineWidth(0.5)
                g.strokeEllipse(in: CGRect(x: px - 3.5, y: py - 3.5, width: 7, height: 7))
            }
        }

        // Marqueur valeur actuelle
        DS.cyan.setFill()
        let lastPx = chartX + CGFloat(n-1) * stepX; let lastPy = toY(vmc.currentSig)
        g.fillEllipse(in: CGRect(x: lastPx - 2, y: lastPy - 2, width: 4, height: 4))

        // Bordure
        g.strokeRoundedRect(CGRect(x: chartX, y: chartY, width: w, height: chartH),
                            radius: 3, color: DS.purple.withAlphaComponent(0.20), lineWidth: 0.5)

        // Légende
        cy += chartH + 3
        DS.cyan.setFill(); g.fill(CGRect(x: x, y: cy, width: 10, height: 1))
        label("VMC", font: DS.fLabel, color: DS.cyan, at: CGPoint(x: x + 12, y: cy - 3), g: g)
        UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.85).setFill()
        g.fill(CGRect(x: x + 28, y: cy, width: 10, height: 1))
        label("Signal", font: DS.fLabel, color: UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 0.85),
              at: CGPoint(x: x + 40, y: cy - 3), g: g)
        let ribbonText = vmc.ribbonBull ? "Ribbon ↑" : vmc.ribbonBear ? "Ribbon ↓" : "Ribbon —"
        rLabel(ribbonText, font: DS.fLabel,
               color: vmc.ribbonBull ? DS.green : vmc.ribbonBear ? DS.red : DS.t3,
               rightX: x + w, y: cy - 3, g: g)
        return cy + 7
    }

    // MARK: - Liquidation Heatmap (crypto seulement)

    private static func drawLiquidationHeatmap(_ g: CGContext, data: LiquidityHeatmapData,
                                                y: CGFloat, x: CGFloat, w: CGFloat, h: CGFloat) {
        sectionTitle(g, text: "Liquidation Heatmap  ·  \(data.period.displayName)",
                     accent: DS.orange, y: y, x: x, w: w)
        let mapY = y + 13
        let mapH = h - 13

        guard data.priceBucketCount > 0, !data.snapshots.isEmpty else {
            label("Données insuffisantes", font: DS.fSmall, color: DS.t4,
                  at: CGPoint(x: x + 6, y: mapY + 8), g: g)
            return
        }

        let axisW: CGFloat = 32
        let mapX = x + axisW
        let mapW = w - axisW

        // Fond très sombre (style Coinglass)
        UIColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1).setFill()
        UIBezierPath(roundedRect: CGRect(x: x, y: mapY, width: w, height: mapH), cornerRadius: 4).fill()

        let snaps = data.snapshots.suffix(80)
        let buckets = data.priceBucketCount
        let cellW = mapW / CGFloat(snaps.count)
        let cellH = mapH / CGFloat(buckets)

        // Dessin heatmap — palette violet→vert→jaune (style Coinglass)
        for (col, snap) in snaps.enumerated() {
            for row in 0..<min(buckets, snap.liquidationLevels.count) {
                let intensity = snap.liquidationLevels[row]
                guard intensity > 0.03 else { continue }
                let cx = mapX + CGFloat(col) * cellW
                let cy = mapY + mapH - CGFloat(row + 1) * cellH
                heatmapColor(intensity: intensity).setFill()
                g.fill(CGRect(x: cx, y: cy, width: max(cellW, 0.8), height: max(cellH, 0.8)))
            }
        }

        // Axe prix (5 labels)
        for i in 0...4 {
            let fraction = Double(i) / 4.0
            let price = data.priceMax - fraction * (data.priceMax - data.priceMin)
            let py = mapY + CGFloat(fraction) * mapH - 3
            let priceStr = price >= 1000
                ? String(format: "%.0f", price)
                : String(format: "%.2f", price)
            rLabel(priceStr, font: DS.fLabel, color: UIColor(white: 0.55, alpha: 1), rightX: mapX - 2, y: py, g: g)
        }

        // Ligne de prix actuel (tiretée cyan)
        if let lastCandle = data.candles.last {
            let fraction = CGFloat((data.priceMax - lastCandle.close) / (data.priceMax - data.priceMin))
            let py = mapY + fraction * mapH
            DS.cyan.withAlphaComponent(0.85).setFill()
            var dX = mapX; while dX < mapX + mapW { g.fill(CGRect(x: dX, y: py, width: 3, height: 0.7)); dX += 5 }
            let priceStr = lastCandle.close >= 1000
                ? String(format: "%.0f", lastCandle.close)
                : String(format: "%.4f", lastCandle.close)
            rLabel(priceStr, font: DS.fSmallB, color: DS.cyan, rightX: mapX + mapW - 2, y: py - 6, g: g)
        }

        // Légende gradient + Bull/Bear
        let legendY = mapY + mapH - 7
        for i in 0..<50 {
            heatmapColor(intensity: Double(i) / 50.0).setFill()
            g.fill(CGRect(x: mapX + CGFloat(i), y: legendY, width: 1, height: 4))
        }
        label("Low", font: DS.fLabel, color: UIColor(white: 0.4, alpha: 1),
              at: CGPoint(x: mapX, y: legendY - 5), g: g)
        label("High", font: DS.fLabel, color: UIColor(red: 0.85, green: 1.0, blue: 0, alpha: 0.9),
              at: CGPoint(x: mapX + 52, y: legendY - 5), g: g)

        // Bull / Bear (style app)
        let bullX = mapX + mapW - 44
        DS.green.withAlphaComponent(0.3).setFill()
        g.fillEllipse(in: CGRect(x: bullX, y: legendY + 0.5, width: 4, height: 4))
        label("Bull", font: DS.fLabel, color: DS.green.withAlphaComponent(0.85),
              at: CGPoint(x: bullX + 6, y: legendY - 1), g: g)
        DS.red.withAlphaComponent(0.3).setFill()
        g.fillEllipse(in: CGRect(x: bullX + 22, y: legendY + 0.5, width: 4, height: 4))
        label("Bear", font: DS.fLabel, color: DS.red.withAlphaComponent(0.85),
              at: CGPoint(x: bullX + 28, y: legendY - 1), g: g)
    }

    /// Palette Coinglass : transparent → violet → bleu → cyan → vert → jaune vif
    private static func heatmapColor(intensity: Double) -> UIColor {
        let t = max(0, min(1, intensity))
        switch t {
        case 0..<0.12:
            let f = t / 0.12
            return UIColor(red: CGFloat(0.15 * f), green: 0, blue: CGFloat(0.22 * f), alpha: CGFloat(0.15 + f * 0.35))
        case 0.12..<0.28:
            let f = (t - 0.12) / 0.16
            return UIColor(red: CGFloat(0.15 + 0.25 * f), green: CGFloat(0.02 * f), blue: CGFloat(0.22 + 0.45 * f), alpha: 0.75)
        case 0.28..<0.45:
            let f = (t - 0.28) / 0.17
            return UIColor(red: CGFloat(0.40 - 0.40 * f), green: CGFloat(0.02 + 0.28 * f), blue: CGFloat(0.67 + 0.15 * f), alpha: 0.85)
        case 0.45..<0.62:
            let f = (t - 0.45) / 0.17
            return UIColor(red: CGFloat(0.05 * f), green: CGFloat(0.30 + 0.42 * f), blue: CGFloat(0.82 - 0.52 * f), alpha: 0.90)
        case 0.62..<0.80:
            let f = (t - 0.62) / 0.18
            return UIColor(red: CGFloat(0.05 + 0.25 * f), green: CGFloat(0.72 + 0.20 * f), blue: CGFloat(0.30 - 0.28 * f), alpha: 0.95)
        case 0.80..<0.92:
            let f = (t - 0.80) / 0.12
            return UIColor(red: CGFloat(0.30 + 0.55 * f), green: CGFloat(0.92 + 0.06 * f), blue: 0.02, alpha: 0.98)
        default:
            let f = (t - 0.92) / 0.08
            return UIColor(red: CGFloat(0.85 + 0.15 * f), green: 0.98, blue: CGFloat(0.02 * (1 - f)), alpha: 1.0)
        }
    }

    // MARK: - Footer

    private static func drawPageFooter(_ g: CGContext) {
        let fy = DS.H - 16
        DS.sep.setFill()
        g.fill(CGRect(x: DS.mX, y: fy, width: DS.cW, height: 0.5))
        label("TradeMindset  ·  Rapport d'Analyse Technique  ·  Informatif uniquement",
              font: UIFont.systemFont(ofSize: 5.5, weight: .regular),
              color: DS.t4, at: CGPoint(x: DS.mX, y: fy + 4), g: g)
    }

    // MARK: - Common Helpers

    private static func sectionTitle(_ g: CGContext, text: String, accent: UIColor,
                                      y: CGFloat, x: CGFloat = DS.mX, w: CGFloat = DS.cW) {
        label(text.uppercased(), font: UIFont.systemFont(ofSize: 6.5, weight: .black),
              color: accent, at: CGPoint(x: x, y: y), g: g)
        accent.withAlphaComponent(0.35).setFill()
        g.fill(CGRect(x: x, y: y + 9, width: w, height: 0.6))
    }

    private static func kvRow(_ g: CGContext, key: String, value: String,
                               color: UIColor, y: CGFloat,
                               x: CGFloat = DS.mX, w: CGFloat = DS.cW) {
        label(key, font: DS.fSmall, color: DS.t3, at: CGPoint(x: x + 3, y: y), g: g)
        rLabel(value, font: DS.fBodyM, color: color, rightX: x + w, y: y, g: g)
    }

    private static func drawPill(_ g: CGContext, text: String, x: CGFloat, y: CGFloat,
                                  w: CGFloat, h: CGFloat, bg: UIColor,
                                  textColor: UIColor, font: UIFont) {
        g.fillRoundedRect(CGRect(x: x, y: y, width: w, height: h), radius: h / 2, color: bg)
        label(text, font: font, color: textColor, at: CGPoint(x: x + 5, y: y + (h - 6.5) / 2), g: g)
    }

    // MARK: - Label primitives

    private static func label(_ text: String, font: UIFont, color: UIColor,
                               at pt: CGPoint, g: CGContext) {
        (text as NSString).draw(at: pt, withAttributes: [.font: font, .foregroundColor: color])
    }

    private static func rLabel(_ text: String, font: UIFont, color: UIColor,
                                rightX: CGFloat, y: CGFloat, g: CGContext) {
        let w = (text as NSString).size(withAttributes: [.font: font]).width
        (text as NSString).draw(at: CGPoint(x: rightX - w, y: y),
                                withAttributes: [.font: font, .foregroundColor: color])
    }

    // MARK: - Color helpers

    private static func signalColor(_ s: SignalStatus?) -> UIColor {
        guard let s else { return DS.t3 }
        switch s {
        case .buy:     return DS.green
        case .bullish: return UIColor(hex: "#5ED97F")
        case .neutral: return DS.t3
        case .bearish: return DS.orange
        case .sell:    return DS.red
        }
    }

    private static func wtSignalColor(_ s: WTSignal?) -> UIColor {
        guard let s else { return DS.t3 }
        switch s {
        case .bullishReversal, .bullishSmartReversal: return DS.green
        case .bearishReversal, .bearishSmartReversal: return DS.red
        case .neutral: return DS.t3
        }
    }

    private static func biasColor(_ b: MarketBias) -> UIColor {
        switch b {
        case .bullish: return DS.cyan
        case .bearish: return DS.red
        case .neutral: return DS.t3
        }
    }

    private static func wtLabel(_ wt: WTSnapshot) -> String {
        wt.currentSignal?.displayName ?? wt.currentMarketBias.displayName
    }
}

// MARK: - CGContext helpers

private extension CGContext {
    func fillRoundedRect(_ rect: CGRect, radius: CGFloat, color: UIColor) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
    }
    func strokeRoundedRect(_ rect: CGRect, radius: CGFloat, color: UIColor, lineWidth: CGFloat) {
        color.setStroke()
        let p = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        p.lineWidth = lineWidth; p.stroke()
    }
}
