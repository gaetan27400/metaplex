//
//  PhotoAnalysisPDFService.swift
//  Journal de trading 2025
//
//  PDF professionnel 1 page pour l'analyse photo IA
//  UIGraphicsPDFRenderer — A4 portrait, fond sombre, lisible
//

import UIKit

// MARK: - UIColor hex helper (local)

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

final class PhotoAnalysisPDFService {

    // MARK: - Design System

    private enum DS {
        static let W:  CGFloat = 595
        static let H:  CGFloat = 842
        static let mX: CGFloat = 26
        static let mY: CGFloat = 14
        static var cW: CGFloat { W - mX * 2 }

        // Couleurs
        static let bg      = UIColor(hex: "#0B0D14")
        static let surface = UIColor(hex: "#131722")
        static let card    = UIColor(hex: "#1A1E2E")
        static let border  = UIColor(white: 1, alpha: 0.08)
        static let sep     = UIColor(white: 1, alpha: 0.06)

        static let cyan    = UIColor(hex: "#00E5FF")
        static let gold    = UIColor(hex: "#FFB800")
        static let green   = UIColor(hex: "#26D97F")
        static let red     = UIColor(hex: "#FF3B55")
        static let orange  = UIColor(hex: "#FF8C00")
        static let purple  = UIColor(hex: "#9B6DFF")
        static let warning = UIColor(hex: "#FF9500")

        static let t1 = UIColor(white: 1.00, alpha: 1)
        static let t2 = UIColor(white: 0.78, alpha: 1)
        static let t3 = UIColor(white: 0.50, alpha: 1)
        static let t4 = UIColor(white: 0.30, alpha: 1)

        // Typographie compacte 1 page
        static let fHero   = UIFont.systemFont(ofSize: 16, weight: .black)
        static let fH1     = UIFont.systemFont(ofSize: 10, weight: .bold)
        static let fH2     = UIFont.systemFont(ofSize: 8.5, weight: .semibold)
        static let fH3     = UIFont.systemFont(ofSize: 7.5, weight: .semibold)
        static let fBody   = UIFont.systemFont(ofSize: 7, weight: .regular)
        static let fBodyM  = UIFont.systemFont(ofSize: 7, weight: .medium)
        static let fSmall  = UIFont.systemFont(ofSize: 6, weight: .regular)
        static let fSmallB = UIFont.systemFont(ofSize: 6, weight: .bold)
        static let fTag    = UIFont.systemFont(ofSize: 6, weight: .bold)
        static let fLabel  = UIFont.systemFont(ofSize: 5.5, weight: .semibold)
    }

    // MARK: - Layout constants

    // Hauteur du header
    private static let headerH: CGFloat = 46
    // Espace restant après header et footer
    private static var bodyH: CGFloat { DS.H - headerH - 22 - DS.mY * 2 }

    // MARK: - Public Entry Point

    static func generate(
        analysis: ChartAnalysis,
        timeframeImages: [TimeframeImage],
        symbol: String? = nil
    ) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: DS.W, height: DS.H)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        return renderer.pdfData { ctx in
            ctx.beginPage()
            let g = ctx.cgContext
            drawSinglePage(g, analysis: analysis,
                           timeframeImages: timeframeImages, symbol: symbol)
        }
    }

    // MARK: - Single Page

    private static func drawSinglePage(
        _ g: CGContext,
        analysis: ChartAnalysis,
        timeframeImages: [TimeframeImage],
        symbol: String?
    ) {
        // Fond
        DS.bg.setFill()
        g.fill(CGRect(x: 0, y: 0, width: DS.W, height: DS.H))

        // Header
        drawHeader(g, symbol: symbol,
                   isMulti: timeframeImages.count > 1,
                   count: timeframeImages.count)

        let hasImages = !timeframeImages.isEmpty
        let bodyTop = headerH + DS.mY

        if hasImages {
            // Layout : colonne gauche (texte) + colonne droite (images + texte)
            let gap: CGFloat = 7
            let leftW  = DS.cW * 0.52
            let rightW = DS.cW - leftW - gap
            let leftX  = DS.mX
            let rightX = DS.mX + leftW + gap

            // Colonne gauche : Plan + sections texte
            var ly = bodyTop
            ly = drawTradePlanCompact(g, plan: analysis.plan,
                                      isMulti: timeframeImages.count > 1,
                                      y: ly, w: leftW, x: leftX)
            ly += 5

            // Sections texte dans la colonne gauche
            let leftSections: [(String, String, UIColor)] = [
                ("Résumé",       analysis.resume,    DS.cyan),
                ("Structure",    analysis.structure, DS.cyan),
                ("Tendance",     analysis.momentum,  DS.green),
            ]
            for sec in leftSections {
                guard !sec.1.isEmpty, ly < DS.H - 40 else { continue }
                ly = drawSectionCompact(g, title: sec.0, accent: sec.2,
                                        content: sec.1, y: ly, x: leftX, w: leftW)
                ly += 4
            }

            // Colonne droite : images + sections restantes
            var ry = bodyTop

            // Images (max 2)
            let imgsToShow = Array(timeframeImages.prefix(2))
            if imgsToShow.count == 1 {
                let imgH: CGFloat = min(180, rightW * 0.65)
                drawChartImageCompact(g, image: imgsToShow[0].image,
                                      label: imgsToShow[0].timeframe.displayName,
                                      x: rightX, y: ry, w: rightW, h: imgH)
                ry += imgH + 6
            } else if imgsToShow.count == 2 {
                let imgH: CGFloat = min(130, rightW * 0.50)
                for (i, img) in imgsToShow.enumerated() {
                    let iy = ry + CGFloat(i) * (imgH + 5)
                    drawChartImageCompact(g, image: img.image,
                                          label: img.timeframe.displayName,
                                          x: rightX, y: iy, w: rightW, h: imgH)
                }
                ry += CGFloat(imgsToShow.count) * (imgH + 5)
            }

            // Sections droite
            let rightSections: [(String, String, UIColor)] = [
                ("Patterns",     analysis.patterns,    DS.gold),
                ("Indicateurs",  analysis.indicateurs, DS.purple),
                ("MTF",          analysis.mtf,         DS.orange),
                ("Risques",      analysis.risques ?? "", DS.red),
            ]
            for sec in rightSections {
                guard !sec.1.isEmpty, ry < DS.H - 36 else { continue }
                ry = drawSectionCompact(g, title: sec.0, accent: sec.2,
                                        content: sec.1, y: ry, x: rightX, w: rightW)
                ry += 4
            }

        } else {
            // Pas d'images — layout 2 colonnes de texte
            let gap: CGFloat = 7
            let colW = (DS.cW - gap) / 2
            let leftX  = DS.mX
            let rightX = DS.mX + colW + gap

            var ly = bodyTop
            var ry = bodyTop

            // Plan de trade (pleine largeur)
            let planW = DS.cW
            ly = drawTradePlanCompact(g, plan: analysis.plan,
                                      isMulti: false, y: ly, w: planW, x: leftX)
            ry = ly + 4; ly += 4

            // Sections gauche
            let leftSections: [(String, String, UIColor)] = [
                ("Résumé",       analysis.resume,    DS.cyan),
                ("Structure",    analysis.structure, DS.cyan),
                ("Tendance",     analysis.momentum,  DS.green),
                ("Psychologie",  analysis.psychologie, DS.warning),
            ]
            for sec in leftSections {
                guard !sec.1.isEmpty, ly < DS.H - 36 else { continue }
                ly = drawSectionCompact(g, title: sec.0, accent: sec.2,
                                        content: sec.1, y: ly, x: leftX, w: colW)
                ly += 4
            }

            // Sections droite
            let rightSections: [(String, String, UIColor)] = [
                ("Patterns",        analysis.patterns,    DS.gold),
                ("Indicateurs",     analysis.indicateurs, DS.purple),
                ("Multi-Timeframe", analysis.mtf,         DS.orange),
                ("Risques",         analysis.risques ?? "", DS.red),
                ("Scénario Alt.",   analysis.scenarioAlternatif ?? "", DS.orange),
            ]
            for sec in rightSections {
                guard !sec.1.isEmpty, ry < DS.H - 36 else { continue }
                ry = drawSectionCompact(g, title: sec.0, accent: sec.2,
                                        content: sec.1, y: ry, x: rightX, w: colW)
                ry += 4
            }
        }

        // Footer
        drawFooter(g)
    }

    // MARK: - Header compact

    private static func drawHeader(_ g: CGContext, symbol: String?,
                                   isMulti: Bool, count: Int) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let cols = [UIColor(hex: "#3D1A00").cgColor,
                    UIColor(hex: "#1A0D20").cgColor] as CFArray
        let grad = CGGradient(colorsSpace: cs, colors: cols, locations: [0, 1])!
        g.saveGState()
        g.clip(to: CGRect(x: 0, y: 0, width: DS.W, height: headerH))
        g.drawLinearGradient(grad, start: .zero,
                             end: CGPoint(x: DS.W, y: headerH), options: [])
        g.restoreGState()

        DS.warning.withAlphaComponent(0.9).setFill()
        g.fill(CGRect(x: 0, y: headerH - 1.5, width: DS.W, height: 1.5))

        // Décoration
        drawGeoDecor(g, cx: DS.W - 38, cy: headerH / 2, r: 22)

        put("TRADEMINDSET", font: UIFont.systemFont(ofSize: 6.5, weight: .black),
            color: DS.warning, at: CGPoint(x: DS.mX, y: 8), g: g)
        put("Analyse Technique IA", font: DS.fHero, color: DS.t1,
            at: CGPoint(x: DS.mX, y: 18), g: g)

        // Badge symbole
        var bx: CGFloat = DS.mX
        if let sym = symbol, !sym.isEmpty {
            bx = drawBadge(g, text: sym, x: bx, y: 37,
                           bg: DS.warning.withAlphaComponent(0.2), color: DS.warning)
        }
        if isMulti {
            _ = drawBadge(g, text: "Multi-UT (\(count))", x: bx + 5, y: 37,
                          bg: DS.cyan.withAlphaComponent(0.15), color: DS.cyan)
        }

        let fmt = DateFormatter(); fmt.dateFormat = "dd MMM yyyy  ·  HH:mm"
        rput(fmt.string(from: Date()), font: DS.fSmall, color: DS.t3,
             rightX: DS.W - DS.mX, y: 33, g: g)
    }

    // MARK: - Trade Plan compact

    @discardableResult
    private static func drawTradePlanCompact(_ g: CGContext, plan: TradePlan,
                                              isMulti: Bool, y: CGFloat,
                                              w: CGFloat, x: CGFloat) -> CGFloat {
        let rows: [(String, String, UIColor)] = [
            ("Biais",        plan.biais,       DS.cyan),
            ("Entrée",       plan.entree,       DS.green),
            ("Stop Loss",    plan.stop,         DS.red),
            ("Objectifs",    plan.objectifs,    DS.gold),
            ("Confirmation", plan.confirmation, DS.purple),
        ].filter { !$0.1.isEmpty }

        var extras: [(String, String, UIColor)] = []
        if let rr = plan.rr, !rr.isEmpty { extras.append(("R/R", rr, DS.cyan)) }

        // Calculer hauteur
        var totalH: CGFloat = 26
        for row in rows + extras {
            totalH += max(textHeight(row.1, font: DS.fBody, width: w - 110), 10) + 3
        }
        totalH = min(totalH + 6, 180) // plafonner

        g.fillRoundedRect(CGRect(x: x, y: y, width: w, height: totalH),
                           radius: 5, color: DS.card)
        g.strokeRoundedRect(CGRect(x: x + 0.5, y: y + 0.5, width: w - 1, height: totalH - 1),
                            radius: 5, color: DS.cyan.withAlphaComponent(0.35), lineWidth: 0.8)
        g.fillRoundedRect(CGRect(x: x, y: y, width: 3, height: totalH),
                           radius: 2, color: DS.cyan)

        put("🎯 Plan de Trade" + (isMulti ? " · Multi-UT" : ""),
            font: DS.fH2, color: DS.t1,
            at: CGPoint(x: x + 8, y: y + 7), g: g)

        DS.border.setFill()
        g.fill(CGRect(x: x + 6, y: y + 20, width: w - 12, height: 0.5))

        var cy = y + 24
        let labelW: CGFloat = 78
        let valX = x + 8 + labelW + 4

        for row in rows + extras {
            guard cy < y + totalH - 8 else { break }
            put(row.0, font: DS.fSmallB, color: row.2,
                at: CGPoint(x: x + 8, y: cy), g: g)
            let h = putWrapped(row.1, font: DS.fBody, color: DS.t2,
                               x: valX, y: cy, maxW: w - labelW - 18, g: g)
            cy += max(h, 10) + 3
        }

        return y + totalH
    }

    // MARK: - Section block compact

    @discardableResult
    private static func drawSectionCompact(_ g: CGContext, title: String,
                                            accent: UIColor, content: String,
                                            y: CGFloat, x: CGFloat, w: CGFloat) -> CGFloat {
        guard !content.isEmpty, y < DS.H - 36 else { return y }

        let maxW = w - 14
        let cH = min(textHeight(content, font: DS.fBody, width: maxW), 60) // plafonner
        let blockH = max(cH + 22, 30.0)
        if y + blockH > DS.H - 22 { return y }

        g.fillRoundedRect(CGRect(x: x, y: y, width: w, height: blockH),
                           radius: 4, color: DS.card)
        g.fillRoundedRect(CGRect(x: x, y: y, width: 2.5, height: blockH),
                           radius: 2, color: accent)
        g.strokeRoundedRect(CGRect(x: x + 0.5, y: y + 0.5, width: w - 1, height: blockH - 1),
                            radius: 4, color: accent.withAlphaComponent(0.12), lineWidth: 0.5)

        put(title.uppercased(), font: DS.fLabel, color: accent,
            at: CGPoint(x: x + 8, y: y + 5), g: g)

        // Contenu tronqué si besoin
        let truncated = truncate(content, font: DS.fBody, width: maxW, maxH: blockH - 18)
        putWrapped(truncated, font: DS.fBody, color: DS.t2,
                   x: x + 8, y: y + 14, maxW: maxW, g: g)

        return y + blockH
    }

    // MARK: - Chart Image compact

    private static func drawChartImageCompact(_ g: CGContext, image: UIImage,
                                               label: String,
                                               x: CGFloat, y: CGFloat,
                                               w: CGFloat, h: CGFloat) {
        let totalH = h + 14
        g.fillRoundedRect(CGRect(x: x, y: y, width: w, height: totalH),
                           radius: 5, color: DS.card)
        g.strokeRoundedRect(CGRect(x: x + 0.5, y: y + 0.5, width: w - 1, height: totalH - 1),
                            radius: 5, color: DS.border, lineWidth: 0.5)

        let imgRect = CGRect(x: x, y: y, width: w, height: h)
        g.saveGState()
        UIBezierPath(roundedRect: imgRect,
                     byRoundingCorners: [.topLeft, .topRight],
                     cornerRadii: CGSize(width: 5, height: 5)).addClip()
        image.draw(in: imgRect)
        g.restoreGState()

        // Badge timeframe
        let bw = (label as NSString).size(withAttributes: [.font: DS.fSmallB]).width + 10
        g.fillRoundedRect(CGRect(x: x + 4, y: y + 4, width: bw, height: 12),
                           radius: 6, color: DS.bg.withAlphaComponent(0.80))
        put(label, font: DS.fSmallB, color: DS.warning,
            at: CGPoint(x: x + 9, y: y + 5), g: g)

        // Label bas
        put(label, font: DS.fSmall, color: DS.t3,
            at: CGPoint(x: x + 5, y: y + h + 2), g: g)
    }

    // MARK: - Footer

    private static func drawFooter(_ g: CGContext) {
        let fy = DS.H - 16
        DS.sep.setFill()
        g.fill(CGRect(x: DS.mX, y: fy, width: DS.cW, height: 0.5))
        put("TradeMindset  ·  Analyse Technique IA  ·  À titre informatif",
            font: UIFont.systemFont(ofSize: 5.5, weight: .regular), color: DS.t4,
            at: CGPoint(x: DS.mX, y: fy + 3), g: g)
    }

    // MARK: - Decorations

    private static func drawGeoDecor(_ g: CGContext, cx: CGFloat, cy: CGFloat, r: CGFloat) {
        g.saveGState()
        DS.warning.withAlphaComponent(0.06).setStroke()
        g.setLineWidth(0.6)
        for i in 0..<3 {
            let ri = r - CGFloat(i) * 7
            g.strokeEllipse(in: CGRect(x: cx - ri, y: cy - ri, width: ri * 2, height: ri * 2))
        }
        g.strokePath()
        g.restoreGState()
    }

    @discardableResult
    private static func drawBadge(_ g: CGContext, text: String, x: CGFloat, y: CGFloat,
                                   bg: UIColor, color: UIColor) -> CGFloat {
        let tw = (text as NSString).size(withAttributes: [.font: DS.fTag]).width
        let bw = tw + 10; let bh: CGFloat = 12
        g.fillRoundedRect(CGRect(x: x, y: y, width: bw, height: bh), radius: bh / 2, color: bg)
        put(text, font: DS.fTag, color: color, at: CGPoint(x: x + 5, y: y + 2), g: g)
        return x + bw
    }

    // MARK: - Text helpers

    private static func put(_ text: String, font: UIFont, color: UIColor,
                             at pt: CGPoint, g: CGContext) {
        (text as NSString).draw(at: pt, withAttributes: [.font: font, .foregroundColor: color])
    }

    private static func rput(_ text: String, font: UIFont, color: UIColor,
                              rightX: CGFloat, y: CGFloat, g: CGContext) {
        let w = (text as NSString).size(withAttributes: [.font: font]).width
        (text as NSString).draw(at: CGPoint(x: rightX - w, y: y),
                                withAttributes: [.font: font, .foregroundColor: color])
    }

    @discardableResult
    private static func putWrapped(_ text: String, font: UIFont, color: UIColor,
                                   x: CGFloat, y: CGFloat, maxW: CGFloat,
                                   g: CGContext) -> CGFloat {
        let ps = NSMutableParagraphStyle()
        ps.lineSpacing = 1.5; ps.lineBreakMode = .byWordWrapping
        let attr = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: ps
        ])
        let bnd = attr.boundingRect(with: CGSize(width: maxW, height: 400),
                                    options: .usesLineFragmentOrigin, context: nil)
        attr.draw(in: CGRect(x: x, y: y, width: maxW, height: bnd.height + 2))
        return bnd.height
    }

    private static func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let ps = NSMutableParagraphStyle(); ps.lineSpacing = 1.5
        let attr = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: ps])
        return attr.boundingRect(with: CGSize(width: width, height: 2000),
                                 options: .usesLineFragmentOrigin, context: nil).height
    }

    /// Tronque le texte pour qu'il tienne dans une hauteur max
    private static func truncate(_ text: String, font: UIFont,
                                  width: CGFloat, maxH: CGFloat) -> String {
        let ps = NSMutableParagraphStyle(); ps.lineSpacing = 1.5
        var result = text
        while textHeight(result, font: font, width: width) > maxH && result.count > 10 {
            // Supprimer la dernière phrase ou les derniers mots
            if let range = result.range(of: ".", options: .backwards) {
                result = String(result[..<range.lowerBound])
            } else {
                result = String(result.dropLast(20))
            }
        }
        return result.count < text.count ? result + "…" : result
    }

    private static func fillBg(_ g: CGContext) {
        DS.bg.setFill()
        g.fill(CGRect(x: 0, y: 0, width: DS.W, height: DS.H))
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
