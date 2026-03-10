//
//  IndicatorExportViews.swift
//  Journal de trading 2025
//
//  Vues d'export statiques pour le partage des indicateurs.
//  Conçues pour ImageRenderer : pas de @State, pas de Charts framework,
//  pas d'animations, pas de NavigationStack.
//  Les graphiques sont dessinés en SwiftUI natif (Canvas/Path).
//

import SwiftUI

// MARK: - Couleurs thème (inline pour éviter dépendances)

private extension Color {
    static let exportBg = Color(red: 0.08, green: 0.08, blue: 0.14)
    static let exportCard = Color(red: 0.12, green: 0.12, blue: 0.20)
    static let wtCyan = Color(red: 0, green: 0.86, blue: 1.0)
    static let wtPink = Color(red: 0.91, green: 0.12, blue: 0.39)
}

// MARK: - WTExportView

struct WTExportView: View {
    let snapshot: WTSnapshot
    let symbol: String
    let timeframe: String

    private let W: CGFloat = 390
    private let chartH: CGFloat = 200

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wave Trend Oscillator")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(symbol) · \(timeframe)")
                        .font(.system(size: 11))
                        .foregroundColor(.wtCyan)
                }
                Spacer()
                signalBadge
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.exportCard)

            // Graphique Canvas
            GeometryReader { geo in
                Canvas { ctx, size in
                    drawWTChart(ctx: ctx, size: size)
                }
            }
            .frame(height: chartH)
            .background(Color.exportBg)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Valeurs
            HStack(spacing: 0) {
                valueCell(label: "WT1",
                          value: String(format: "%.2f", snapshot.currentWT1),
                          color: .wtCyan)
                Divider().frame(width: 1, height: 40).background(Color.white.opacity(0.1))
                valueCell(label: "WT2",
                          value: String(format: "%.2f", snapshot.currentWT2),
                          color: .wtPink)
                Divider().frame(width: 1, height: 40).background(Color.white.opacity(0.1))
                valueCell(label: "Histogram",
                          value: String(format: "%.2f", snapshot.currentHistogram),
                          color: snapshot.currentHistogram >= 0 ? .wtCyan : .wtPink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.exportCard)

            // Biais IA + Momentum
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(snapshot.currentMarketBias.color)
                        .frame(width: 8, height: 8)
                    Text("IA · \(snapshot.currentMarketBias.displayName)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(snapshot.currentMarketBias.color)
                }
                Spacer()
                Text(String(format: "Momentum %.1f", snapshot.currentMomentum))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(red: 0.10, green: 0.10, blue: 0.18))
        }
        .background(Color.exportBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.wtCyan.opacity(0.3), lineWidth: 1)
        )
        .frame(width: W)
    }

    // MARK: - Signal Badge

    private var signalBadge: some View {
        Group {
            if let signal = snapshot.currentSignal {
                HStack(spacing: 6) {
                    Image(systemName: signalIcon(signal))
                        .font(.system(size: 13, weight: .bold))
                    Text(signal.displayName)
                        .font(.system(size: 12, weight: .heavy))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(signal.color.opacity(0.25))
                        .overlay(Capsule().stroke(signal.color, lineWidth: 1.5))
                )
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .font(.system(size: 13))
                    Text("NEU")
                        .font(.system(size: 12, weight: .heavy))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(Capsule().stroke(Color.gray.opacity(0.4), lineWidth: 1.5))
                )
            }
        }
    }

    private func signalIcon(_ signal: WTSignal) -> String {
        switch signal {
        case .bullishReversal, .bullishSmartReversal: return "arrow.up.circle.fill"
        case .bearishReversal, .bearishSmartReversal: return "arrow.down.circle.fill"
        case .neutral: return "arrow.left.arrow.right.circle.fill"
        }
    }

    // MARK: - Chart (Canvas natif — pas de Charts framework)

    private func drawWTChart(ctx: GraphicsContext, size: CGSize) {
        let readings = snapshot.readings
        guard readings.count > 1 else { return }

        let allValues = readings.flatMap { [$0.wt1, $0.wt2] }
        let minV = min(allValues.min() ?? -80, -80.0)
        let maxV = max(allValues.max() ?? 80, 80.0)
        let range = maxV - minV
        guard range > 0 else { return }

        func x(_ i: Int) -> CGFloat {
            CGFloat(i) / CGFloat(readings.count - 1) * size.width
        }
        func y(_ v: Double) -> CGFloat {
            size.height - CGFloat((v - minV) / range) * size.height
        }

        // Ligne zéro
        var zeroPath = Path()
        let zy = y(0)
        zeroPath.move(to: CGPoint(x: 0, y: zy))
        zeroPath.addLine(to: CGPoint(x: size.width, y: zy))
        ctx.stroke(zeroPath, with: .color(.white.opacity(0.2)),
                   style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // Zone surachat / survente
        let obY = y(snapshot.overboughtLevel)
        let osY = y(snapshot.oversoldLevel)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: obY)),
                 with: .color(Color.wtPink.opacity(0.06)))
        ctx.fill(Path(CGRect(x: 0, y: osY, width: size.width, height: size.height - osY)),
                 with: .color(Color.wtCyan.opacity(0.06)))

        // Histogramme (rectangles WT1-WT2)
        for (i, r) in readings.enumerated() {
            guard abs(r.histogram) > 0.5 else { continue }
            let x0 = x(i)
            let barW = max(1, size.width / CGFloat(readings.count) - 0.5)
            let y1 = y(r.wt1)
            let y2 = y(r.wt2)
            let barRect = CGRect(x: x0 - barW/2,
                                 y: min(y1, y2),
                                 width: barW,
                                 height: abs(y1 - y2))
            let barColor = r.histogram >= 0 ? Color.wtCyan.opacity(0.5) : Color.wtPink.opacity(0.5)
            ctx.fill(Path(barRect), with: .color(barColor))
        }

        // Ligne WT2 (rose) — dessous
        var wt2Path = Path()
        for (i, r) in readings.enumerated() {
            let pt = CGPoint(x: x(i), y: y(r.wt2))
            if i == 0 { wt2Path.move(to: pt) } else { wt2Path.addLine(to: pt) }
        }
        ctx.stroke(wt2Path, with: .color(Color.wtPink.opacity(0.8)),
                   style: StrokeStyle(lineWidth: 1.5))

        // Ligne WT1 (cyan) — dessus
        var wt1Path = Path()
        for (i, r) in readings.enumerated() {
            let pt = CGPoint(x: x(i), y: y(r.wt1))
            if i == 0 { wt1Path.move(to: pt) } else { wt1Path.addLine(to: pt) }
        }
        ctx.stroke(wt1Path, with: .color(Color.wtCyan.opacity(0.9)),
                   style: StrokeStyle(lineWidth: 2))

        // Points de signal
        for (i, r) in readings.enumerated() {
            guard let signal = r.signal else { continue }
            let pt = CGPoint(x: x(i), y: y(r.wt2))
            let radius: CGFloat = 4
            let dotRect = CGRect(x: pt.x - radius, y: pt.y - radius,
                                 width: radius*2, height: radius*2)
            ctx.fill(Path(ellipseIn: dotRect), with: .color(signal.color))
            ctx.stroke(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.8)),
                       style: StrokeStyle(lineWidth: 1.5))
        }
    }

    // MARK: - Value Cell

    private func valueCell(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

// MARK: - VMCExportView

struct VMCExportView: View {
    let snapshot: VMCOscillatorSnapshot
    let symbol: String
    let timeframe: String

    private let W: CGFloat = 390
    private let chartH: CGFloat = 180
    private let accent = Color.orange

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.title3)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(LinearGradient(colors: [accent, accent.opacity(0.7)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("VMC Oscillator")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(symbol) · \(timeframe)")
                        .font(.system(size: 11))
                        .foregroundColor(accent.opacity(0.8))
                }
                Spacer()

                // Status badge
                Text(snapshot.statusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(snapshot.statusColor))

                // Ribbon
                if snapshot.ribbonBull {
                    Text("BULL").font(.system(size: 9, weight: .bold)).foregroundColor(.green)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(Color.green.opacity(0.2)))
                } else if snapshot.ribbonBear {
                    Text("BEAR").font(.system(size: 9, weight: .bold)).foregroundColor(.red)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule().fill(Color.red.opacity(0.2)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.exportCard)

            // Graphique Canvas
            GeometryReader { _ in
                Canvas { ctx, size in
                    drawVMCChart(ctx: ctx, size: size)
                }
            }
            .frame(height: chartH)
            .background(Color.exportBg)
            .padding(10)

            // Valeurs
            HStack(spacing: 0) {
                valueCell("Sig", String(format: "%.1f", snapshot.currentSig), accent)
                Divider().frame(width: 1, height: 36).background(Color.white.opacity(0.1))
                valueCell("Signal", String(format: "%.1f", snapshot.currentSigSignal),
                          Color(red: 0.2, green: 0.88, blue: 1.0))
                Divider().frame(width: 1, height: 36).background(Color.white.opacity(0.1))
                valueCell("Mom", String(format: "%.1f", snapshot.currentMomentum),
                          snapshot.currentMomentum >= 0 ? .green : .red)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.exportCard)
        }
        .background(Color.exportBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(accent.opacity(0.3), lineWidth: 1))
        .frame(width: W)
    }

    private func valueCell(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 10)).foregroundColor(.white.opacity(0.5))
            Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 6)
    }

    private func drawVMCChart(ctx: GraphicsContext, size: CGSize) {
        let readings = snapshot.readings
        guard readings.count > 1 else { return }

        let sigVals = readings.map { $0.sig }
        let all = sigVals + readings.map { $0.sigSignal }
        let minV = (all.min() ?? -100) - 5
        let maxV = (all.max() ?? 100) + 5
        let range = maxV - minV
        guard range > 0 else { return }

        func x(_ i: Int) -> CGFloat { CGFloat(i) / CGFloat(readings.count - 1) * size.width }
        func y(_ v: Double) -> CGFloat { size.height - CGFloat((v - minV) / range) * size.height }

        // Ligne zéro
        var zeroPath = Path()
        zeroPath.move(to: CGPoint(x: 0, y: y(0)))
        zeroPath.addLine(to: CGPoint(x: size.width, y: y(0)))
        ctx.stroke(zeroPath, with: .color(.white.opacity(0.15)),
                   style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

        // Zones OB/OS
        let obY = y(snapshot.upperThreshold)
        let osY = y(snapshot.lowerThreshold)
        ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: obY)),
                 with: .color(Color.red.opacity(0.06)))
        ctx.fill(Path(CGRect(x: 0, y: osY, width: size.width, height: size.height - osY)),
                 with: .color(Color.green.opacity(0.06)))

        // Ligne sigSignal (bleu)
        var sigSignalPath = Path()
        for (i, r) in readings.enumerated() {
            let pt = CGPoint(x: x(i), y: y(r.sigSignal))
            if i == 0 { sigSignalPath.move(to: pt) } else { sigSignalPath.addLine(to: pt) }
        }
        ctx.stroke(sigSignalPath, with: .color(Color(red: 0.2, green: 0.88, blue: 1.0).opacity(0.7)),
                   style: StrokeStyle(lineWidth: 1.5))

        // Ligne sig (orange)
        var sigPath = Path()
        for (i, r) in readings.enumerated() {
            let pt = CGPoint(x: x(i), y: y(r.sig))
            if i == 0 { sigPath.move(to: pt) } else { sigPath.addLine(to: pt) }
        }
        ctx.stroke(sigPath, with: .color(Color.orange.opacity(0.9)),
                   style: StrokeStyle(lineWidth: 2))

        // Signaux (points)
        for (i, r) in readings.enumerated() {
            guard let signal = r.signal else { continue }
            let pt = CGPoint(x: x(i), y: y(r.sig))
            let radius: CGFloat = 4
            let dotRect = CGRect(x: pt.x - radius, y: pt.y - radius,
                                 width: radius*2, height: radius*2)
            ctx.fill(Path(ellipseIn: dotRect), with: .color(signal.color))
        }
    }
}

// MARK: - MTFExportView

struct MTFExportView: View {
    let snapshot: MTFSnapshot
    let symbol: String

    private let W: CGFloat = 812  // format paysage iPhone
    private let H: CGFloat = 360

    var body: some View {
        HStack(spacing: 0) {
            // Colonne gauche : ticker + signal global
            VStack(spacing: 8) {
                // Ticker
                let ticker = symbol.replacingOccurrences(of: "USDT", with: "")
                Text(ticker)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.orange)
                Text("USDT")
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.7))

                Divider().background(Color.white.opacity(0.1))

                // Signal global
                Text(snapshot.globalSignal.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(snapshot.globalSignal.color.opacity(0.3))
                        .overlay(Capsule().stroke(snapshot.globalSignal.color, lineWidth: 1.5)))

                // Barres globales
                HStack(spacing: 4) {
                    mtfBar(label: "RSI",
                           value: (MTFCombiner.normalizeRSI(snapshot.globalRSI) + 100) / 200,
                           rawValue: snapshot.globalRSI,
                           isRSI: true,
                           width: 22)
                    mtfBar(label: "VMC",
                           value: normalizeVMC(snapshot.globalVMC),
                           rawValue: snapshot.globalVMC,
                           isRSI: false,
                           width: 30)
                }

                Text(String(format: "%.1f", snapshot.globalCombinedScore))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 4)
                        .fill(scoreColor(snapshot.globalCombinedScore).opacity(0.3)))

                Text("Global")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(width: 68)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.5)))
            .padding(.trailing, 8)

            // Colonnes timeframes
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(VMCTimeframe.allCases.reversed(), id: \.self) { tf in
                        if let reading = snapshot.readings[tf] {
                            mtfColumn(reading: reading, tf: tf)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.exportBg)
        .frame(width: W, height: H)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }

    private func mtfColumn(reading: MTFReading, tf: VMCTimeframe) -> some View {
        VStack(spacing: 6) {
            // Timeframe label
            Text(tf.displayName)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .frame(height: 18)

            // Signal
            Text(reading.combinedSignal.displayName)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Capsule().fill(reading.combinedSignal.color.opacity(0.3))
                    .overlay(Capsule().stroke(reading.combinedSignal.color, lineWidth: 1)))
                .lineLimit(1)

            // Barres RSI + VMC
            HStack(spacing: 4) {
                mtfBar(label: "R",
                       value: (reading.rsiNormalized + 100) / 200,
                       rawValue: reading.rsiValue,
                       isRSI: true,
                       width: 20)
                mtfBar(label: "V",
                       value: normalizeVMC(reading.vmcValue),
                       rawValue: reading.vmcValue,
                       isRSI: false,
                       width: 26)
            }
            .frame(height: 80)

            // Valeurs numériques
            VStack(spacing: 2) {
                Text(String(format: "%.0f", reading.rsiValue))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(rsiColor(reading.rsiValue))
                Text(String(format: "%.1f", reading.vmcValue))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(vmcColor(reading.vmcValue))
            }

            // Score combiné
            Text(String(format: "%.0f", reading.combinedScore))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(scoreColor(reading.combinedScore).opacity(0.3)))
        }
        .frame(width: 56)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4)))
    }

    private func mtfBar(label: String, value: Double, rawValue: Double, isRSI: Bool, width: CGFloat) -> some View {
        let clampedValue = max(0, min(1, value))
        let barColor: Color = isRSI ? rsiColor(rawValue) : vmcColor(rawValue)
        let barHeight: CGFloat = 70

        return VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: width, height: barHeight)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor.opacity(0.8))
                    .frame(width: width, height: barHeight * clampedValue)
            }
        }
    }

    private func normalizeVMC(_ v: Double) -> Double {
        (v + 100) / 200.0
    }

    private func rsiColor(_ v: Double) -> Color {
        if v >= 70 { return .red }
        if v <= 30 { return .green }
        return .white
    }

    private func vmcColor(_ v: Double) -> Color {
        if v > 20 { return .red }
        if v < -20 { return .green }
        return .gray
    }

    private func scoreColor(_ score: Double) -> Color {
        if score > 30 { return .green }
        if score < -30 { return .red }
        return .gray
    }
}
