import SwiftUI

// MARK: - NewsTickerBanner

/// A horizontally scrolling news ticker banner that displays Bloomberg RSS headlines.
///
/// Features:
/// - Infinite smooth marquee scroll
/// - Tap to pause / resume (with visual indicator)
/// - Tap individual headline to open article via `openURL`
/// - Long press to open a full reading-list sheet
/// - System font (replaces monospaced), height 35 pt, generous spacing
///
/// Usage:
/// ```swift
/// NewsTickerBanner(
///     headlines: service.headlines,
///     headlineURLs: service.headlineURLs
/// )
/// ```
struct NewsTickerBanner: View {

    // MARK: - Input

    /// Plain-text headline strings from `NewsTickerService`.
    let headlines: [String]

    /// Matching URLs for each headline (same index). Pass `nil` when unavailable.
    let headlineURLs: [URL?]

    // MARK: - Environment

    @Environment(\.openURL) private var openURL

    // MARK: - State

    /// Whether the ticker is currently paused.
    @State private var isPaused: Bool = false

    /// Current horizontal translation applied to the scrolling content.
    @State private var tickerOffset: CGFloat = 0

    /// Whether the reading-list sheet is visible.
    @State private var showReadingList: Bool = false

    /// Measured width of the doubled-content HStack; drives animation duration.
    @State private var contentWidth: CGFloat = 0

    /// Incremented each time a new animation cycle should start.
    /// Callbacks compare against the value captured at launch time and bail if stale.
    @State private var animationGeneration: Int = 0

    // MARK: - Constants

    private let bannerHeight: CGFloat = 35
    private let scrollSpeed: Double = 55      // pt / s  — comfortable reading pace
    private let itemPadding: CGFloat = 32     // horizontal padding around each headline text
    private let separatorText: String = "  ●  "

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.ignoresSafeArea(edges: .horizontal)

            scrollingStrip
                .offset(x: tickerOffset)
        }
        .frame(height: bannerHeight)
        .clipped()
        // Tap → pause / resume
        .onTapGesture {
            togglePause()
        }
        // Long press → open reading list (also pauses)
        .onLongPressGesture(minimumDuration: 0.55) {
            isPaused = true
            showReadingList = true
        }
        .onAppear {
            launchScroll()
        }
        // Resume after reading list is dismissed
        .sheet(isPresented: $showReadingList, onDismiss: {
            isPaused = false
            launchScroll()
        }) {
            readingListSheet
        }
        // Trailing pause badge
        .overlay(alignment: .trailing) {
            if isPaused {
                pauseBadge
            }
        }
    }

    // MARK: - Scrolling Strip

    private var scrollingStrip: some View {
        HStack(spacing: 0) {
            // Doubled content enables seamless loop: when the first copy has
            // scrolled fully off-screen we snap back to the start position.
            ForEach(doubledItems) { item in
                headlineCell(item)

                Text(separatorText)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.35))
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    if contentWidth == 0 {
                        contentWidth = geo.size.width
                    }
                }
            }
        )
    }

    // MARK: - Headline Cell

    @ViewBuilder
    private func headlineCell(_ item: TickerItem) -> some View {
        let hasURL = item.articleURL != nil

        Button {
            if let url = item.articleURL {
                openURL(url)
            }
        } label: {
            Text(item.headline)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(hasURL ? Color(red: 1, green: 0.85, blue: 0.3) : .white)
                .lineLimit(1)
                .padding(.horizontal, itemPadding)
        }
        .buttonStyle(.plain)
        // Disable button interaction but still allow the parent tap (pause)
        // when no URL is available, to avoid swallowing the gesture.
        .allowsHitTesting(hasURL)
        .overlay(
            // Transparent overlay captures tap for pause even over buttons
            hasURL ? nil :
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { togglePause() }
        )
    }

    // MARK: - Pause Badge

    private var pauseBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "pause.fill")
                .font(.system(size: 8, weight: .semibold))
            Text("PAUSED")
                .font(.system(size: 8, weight: .semibold))
                .kerning(0.5)
        }
        .foregroundColor(.white.opacity(0.6))
        .padding(.trailing, 10)
    }

    // MARK: - Reading List Sheet

    private var readingListSheet: some View {
        NavigationView {
            List {
                ForEach(Array(headlines.enumerated()), id: \.offset) { idx, text in
                    readingListRow(headline: text, url: url(at: idx))
                }
            }
            .listStyle(.plain)
            .navigationTitle("Bloomberg Headlines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showReadingList = false }
                        .fontWeight(.medium)
                }
            }
        }
    }

    @ViewBuilder
    private func readingListRow(headline: String, url: URL?) -> some View {
        Button {
            if let url = url {
                openURL(url)
                showReadingList = false
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(headline)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if url != nil {
                        Label("Read on Bloomberg", systemImage: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(url == nil)
    }

    // MARK: - Data Helpers

    private struct TickerItem: Identifiable {
        let id: Int          // unique across the doubled array
        let originalIndex: Int
        let headline: String
        let articleURL: URL?
    }

    private var doubledItems: [TickerItem] {
        guard !headlines.isEmpty else { return [] }
        let base = headlines.indices.map { i in
            TickerItem(id: i, originalIndex: i, headline: headlines[i], articleURL: url(at: i))
        }
        let doubled = base + base.map { item in
            TickerItem(id: item.id + headlines.count, originalIndex: item.originalIndex,
                       headline: item.headline, articleURL: item.articleURL)
        }
        return doubled
    }

    private func url(at index: Int) -> URL? {
        guard index < headlineURLs.count else { return nil }
        return headlineURLs[index]
    }

    // MARK: - Animation Engine

    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            // Cancel in-flight animation by bumping the generation counter.
            // The pending DispatchQueue callback will see a stale generation and exit.
            animationGeneration &+= 1
            // Stop the SwiftUI animation immediately
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                // tickerOffset stays at its current interpolated position;
                // SwiftUI snaps to the last committed value.
                // We freeze by cancelling the continuation rather than setting offset.
            }
        } else {
            launchScroll()
        }
    }

    /// Starts (or restarts) the infinite scrolling animation.
    private func launchScroll() {
        guard !isPaused, !headlines.isEmpty else { return }

        // Bump generation so any pending callbacks from a previous cycle
        // recognise they are stale and do not fire.
        let generation = animationGeneration &+ 1
        animationGeneration = generation

        // Reset to the logical start so the animation always begins cleanly.
        // A tiny async hop lets layout complete and contentWidth settle first.
        var snapTransaction = Transaction()
        snapTransaction.disablesAnimations = true
        withTransaction(snapTransaction) {
            tickerOffset = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            scrollCycle(generation: generation)
        }
    }

    /// Animates one full scroll of the first content copy, then resets and loops.
    private func scrollCycle(generation: Int) {
        guard animationGeneration == generation, !isPaused else { return }

        // Measure: if not yet available, wait a frame and retry.
        let half = contentWidth / 2
        guard half > 1 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollCycle(generation: generation)
            }
            return
        }

        // Compute duration based on remaining distance (supports mid-scroll resume)
        let remaining = half + tickerOffset          // tickerOffset is ≤ 0
        let duration  = Double(max(remaining, 0)) / scrollSpeed

        withAnimation(.linear(duration: duration)) {
            tickerOffset = -half
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard animationGeneration == generation, !self.isPaused else { return }
            // Instant reset (no animation) then start next cycle
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { tickerOffset = 0 }

            DispatchQueue.main.async {
                scrollCycle(generation: generation)
            }
        }
    }
}

// MARK: - Convenience Init (headlines only, no URLs)

extension NewsTickerBanner {
    /// Initialise with headlines only when article URLs are not available.
    init(headlines: [String]) {
        self.headlines = headlines
        self.headlineURLs = []
    }
}

// MARK: - Preview

#if DEBUG
struct NewsTickerBanner_Previews: PreviewProvider {
    static let sampleHeadlines = [
        "Fed signals two rate cuts in 2025 amid cooling inflation data",
        "S&P 500 hits record high as tech stocks lead broad market rally",
        "OPEC+ extends production cuts through Q3; Brent crude rises 1.4%",
        "Apple unveils M4 Pro chip family with hardware AI acceleration cores",
        "Euro zone GDP growth beats expectations at +0.6% in Q1 2025",
    ]

    static let sampleURLs: [URL?] = [
        URL(string: "https://www.bloomberg.com/news/articles/2025-01-01/fed-rates"),
        URL(string: "https://www.bloomberg.com/news/articles/2025-01-02/sp500-record"),
        URL(string: "https://www.bloomberg.com/news/articles/2025-01-03/opec-cuts"),
        URL(string: "https://www.bloomberg.com/news/articles/2025-01-04/apple-m4"),
        URL(string: "https://www.bloomberg.com/news/articles/2025-01-05/eurozone-gdp"),
    ]

    static var previews: some View {
        VStack(spacing: 12) {
            Text("With URLs (yellow = clickable)")
                .font(.caption)
                .foregroundColor(.white)

            NewsTickerBanner(headlines: sampleHeadlines, headlineURLs: sampleURLs)

            Text("Without URLs (non-clickable)")
                .font(.caption)
                .foregroundColor(.white)

            NewsTickerBanner(headlines: sampleHeadlines)
        }
        .padding()
        .background(Color(white: 0.08))
        .previewLayout(.sizeThatFits)
    }
}
#endif
