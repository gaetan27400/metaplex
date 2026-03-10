
//  NewsTickerBanner.swift

//  Journal de trading 2025

//

//  Bandeau défilant d'actualités financières market-moving.

//  S'insère entre la top bar et les filtres d'actifs du Dashboard.

//

//  📍 Placer dans : Views/Dashboard/NewsTickerBanner.swift

//

import SwiftUI

struct NewsTickerBanner: View {

@StateObject private var ticker = NewsTickerService.shared

@State private var animationOffset: CGFloat = 0

@State private var textWidth: CGFloat = 0

@State private var animationID = UUID()

// Interaction

@State private var isPaused = false

@State private var showReadingMode = false

private let tickerHeight: CGFloat = 38

private let speed: CGFloat = 42 // points/sec (constante)

private let separator = "   ◆   "

@Environment(\.openURL) private var openURL

var body: some View {

ZStack {

tickerBackground

if ticker.isLoading && ticker.headlines.isEmpty {

loadingState

} else if ticker.headlines.isEmpty {

emptyState

} else {

scrollingTicker

}

lateralFades

}

.frame(height: tickerHeight)

.clipped()

.overlay(borders)

.contentShape(Rectangle())

.onTapGesture {

isPaused.toggle()

}

.onLongPressGesture {

showReadingMode = true

}

.sheet(isPresented: $showReadingMode) {

readingModeSheet

}

.task {

await ticker.refresh()

}

}

// MARK: - Scrolling Ticker

private var scrollingTicker: some View {

GeometryReader { geo in

TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: isPaused)) { timeline in

let containerW = geo.size.width

let rendered = renderableHeadlines(from: ticker.headlines)

let totalW = max(textWidth, containerW + 120)

let elapsed = timeline.date.timeIntervalSince1970

let cycleDuration = Double(totalW / speed)

let cycleOffset = CGFloat(elapsed.truncatingRemainder(dividingBy: cycleDuration)) * speed

HStack(spacing: 0) {

tickerContent(rendered)

tickerContent(rendered)

}

.offset(x: -cycleOffset)

}

}

}

@ViewBuilder

private func tickerContent(_ items: [HeadlineItem]) -> some View {

HStack(spacing: 22) {

ForEach(Array(items.enumerated()), id: \.offset) { index, item in

if let url = item.url {

Button {

openURL(url)

} label: {

headlineRow(item)

}

.buttonStyle(.plain)

} else {

headlineRow(item)

}

if index < items.count - 1 {

Text(separator)

.font(.system(size: 13, weight: .semibold))

.foregroundColor(Color.white.opacity(0.45))

.fixedSize()

}

}

}

.fixedSize(horizontal: true, vertical: false)

.background(

GeometryReader { proxy in

Color.clear.onAppear {

let w = proxy.size.width

if w > textWidth { textWidth = w }

}

}

)

}

private func headlineRow(_ item: HeadlineItem) -> some View {

HStack(spacing: 8) {

Text("⚡ \(item.category)")

.font(.system(size: 11, weight: .bold))

.foregroundColor(Color(red: 0.99, green: 0.74, blue: 0.20))

.textCase(.uppercase)

.fixedSize()

Text(item.title)

.font(.system(size: 14, weight: .medium))

.foregroundStyle(

LinearGradient(

colors: [

Color.white.opacity(0.90),

Color(red: 0.60, green: 0.87, blue: 1.0).opacity(0.85)

],

startPoint: .leading,

endPoint: .trailing

)

)

.lineLimit(1)

.fixedSize(horizontal: true, vertical: false)

}

}

// MARK: - Reading Mode

private var readingModeSheet: some View {

NavigationView {

List {

ForEach(Array(renderableHeadlines(from: ticker.headlines).enumerated()), id: \.offset) { _, item in

if let url = item.url {

Button {

openURL(url)

} label: {

VStack(alignment: .leading, spacing: 6) {

Text("⚡ \(item.category)")

.font(.system(size: 11, weight: .bold))

.foregroundColor(.secondary)

.textCase(.uppercase)

Text(item.title)

.font(.system(size: 15, weight: .regular))

.foregroundColor(.primary)

.multilineTextAlignment(.leading)

Text(url.absoluteString)

.font(.system(size: 12))

.foregroundColor(.secondary)

.lineLimit(1)

}

.padding(.vertical, 4)

}

.buttonStyle(.plain)

} else {

VStack(alignment: .leading, spacing: 6) {

Text("⚡ \(item.category)")

.font(.system(size: 11, weight: .bold))

.foregroundColor(.secondary)

.textCase(.uppercase)

Text(item.title)

.font(.system(size: 15, weight: .regular))

.foregroundColor(.primary)

.multilineTextAlignment(.leading)

}

.padding(.vertical, 4)

}

}

}

.navigationTitle("Bloomberg Feed")

.navigationBarTitleDisplayMode(.inline)

.toolbar {

ToolbarItem(placement: .topBarTrailing) {

Button("Close") { showReadingMode = false }

}

}

}

}

// MARK: - Loading State

private var loadingState: some View {

HStack(spacing: 8) {

ProgressView()

.scaleEffect(0.65)

.tint(Color(red: 0.0, green: 0.83, blue: 1.0))

Text("Loading market news…")

.font(.system(size: 12, weight: .medium))

.foregroundColor(Color(red: 0.0, green: 0.83, blue: 1.0).opacity(0.70))

}

}

// MARK: - Empty State

private var emptyState: some View {

HStack(spacing: 8) {

Image(systemName: "newspaper")

.font(.system(size: 11))

.foregroundColor(AppColors.textTertiary)

Text("No market headlines available")

.font(.system(size: 12, weight: .medium))

.foregroundColor(AppColors.textTertiary)

Spacer()

Button {

Task { await ticker.refresh(force: true) }

} label: {

Image(systemName: "arrow.clockwise")

.font(.system(size: 11, weight: .semibold))

.foregroundColor(AppColors.primary)

}

}

.padding(.horizontal, 12)

}

// MARK: - Visuals

private var tickerBackground: some View {

LinearGradient(

colors: [

Color(red: 0.03, green: 0.05, blue: 0.10),

Color(red: 0.06, green: 0.09, blue: 0.16)

],

startPoint: .leading,

endPoint: .trailing

)

}

private var lateralFades: some View {

HStack(spacing: 0) {

LinearGradient(

colors: [Color(red: 0.04, green: 0.06, blue: 0.11), .clear],

startPoint: .leading,

endPoint: .trailing

)

.frame(width: 30)

Spacer()

LinearGradient(

colors: [.clear, Color(red: 0.04, green: 0.06, blue: 0.11)],

startPoint: .leading,

endPoint: .trailing

)

.frame(width: 30)

}

}

private var borders: some View {

VStack(spacing: 0) {

Rectangle()

.fill(Color.white.opacity(0.06))

.frame(height: 0.5)

Spacer()

Rectangle()

.fill(Color.white.opacity(0.06))

.frame(height: 0.5)

}

}

// MARK: - Parsing & Categorization

private struct HeadlineItem {

let title: String

let url: URL?

let category: String

}

private func renderableHeadlines(from raws: [String]) -> [HeadlineItem] {

raws.map { raw in

let parsed = parseHeadline(raw)

return HeadlineItem(

title: parsed.title,

url: parsed.url,

category: category(for: parsed.title)

)

}

}

/// Supporte:

/// - "Titre | https://..."

/// - "Titre https://..."

/// - "Titre" (sans URL)

private func parseHeadline(_ raw: String) -> (title: String, url: URL?) {

if let pipe = raw.firstIndex(of: "|") {

let title = String(raw[..<pipe]).trimmingCharacters(in: .whitespacesAndNewlines)

let link = String(raw[raw.index(after: pipe)...]).trimmingCharacters(in: .whitespacesAndNewlines)

return (title.isEmpty ? raw : title, URL(string: link))

}

if let range = raw.range(of: #"https?://\S+"#, options: .regularExpression) {

let link = String(raw[range]).trimmingCharacters(in: .whitespacesAndNewlines)

let title = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

return (title.isEmpty ? raw : title, URL(string: link))

}

return (raw.trimmingCharacters(in: .whitespacesAndNewlines), nil)

}

private func category(for title: String) -> String {

let lower = title.lowercased()

let macroKeywords = [

"fed", "ecb", "inflation", "rates", "gdp", "cpi", "central bank", "macro", "treasury", "yield"

]

let cryptoKeywords = [

"bitcoin", "btc", "ethereum", "eth", "crypto", "token", "blockchain", "solana", "binance"

]

let marketsKeywords = [

"stocks", "equity", "futures", "oil", "gold", "nasdaq", "s&p", "dow", "market", "volatility"

]

if macroKeywords.contains(where: { lower.contains($0) }) { return "MACRO" }

if cryptoKeywords.contains(where: { lower.contains($0) }) { return "CRYPTO" }

if marketsKeywords.contains(where: { lower.contains($0) }) { return "MARKETS" }

return "MARKETS"

}

}
