import SwiftUI

struct NewsTickerBanner: View {
    @StateObject private var service = NewsTickerService()
    @State private var isPaused = false
    @State private var showReadingMode = false
    @State private var offset: CGFloat = 0

    private let tickerHeight: CGFloat = 36
    private let animationSpeed: Double = 30

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)

            GeometryReader { geometry in
                let headlineWidth = calculateTotalWidth(geometry: geometry)

                HStack(spacing: 40) {
                    ForEach(Array(repeatingHeadlines.enumerated()), id: \.offset) { index, headline in
                        headlineButton(headline: headline, geometry: geometry)
                    }
                }
                .offset(x: isPaused ? offset : offset)
                .onAppear {
                    offset = geometry.size.width
                    if !isPaused {
                        startAnimation(totalWidth: headlineWidth, screenWidth: geometry.size.width)
                    }
                }
                .onChange(of: isPaused) { newValue in
                    if !newValue {
                        startAnimation(totalWidth: headlineWidth, screenWidth: geometry.size.width)
                    }
                }
            }
        }
        .frame(height: tickerHeight)
        .onTapGesture {
            isPaused.toggle()
        }
        .onLongPressGesture {
            showReadingMode = true
        }
        .sheet(isPresented: $showReadingMode) {
            readingModeView
        }
    }

    private func headlineButton(headline: String, geometry: GeometryProxy) -> some View {
        Button(action: {
            openHeadlineURL(headline)
        }) {
            Text(headline)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var readingModeView: some View {
        NavigationView {
            List {
                ForEach(service.headlines, id: \.self) { headline in
                    Button(action: {
                        openHeadlineURL(headline)
                    }) {
                        Text(headline)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Bloomberg News")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showReadingMode = false
                    }
                }
            }
        }
    }

    private var repeatingHeadlines: [String] {
        guard !service.headlines.isEmpty else {
            return ["Loading Bloomberg news..."]
        }
        return service.headlines + service.headlines
    }

    private func calculateTotalWidth(geometry: GeometryProxy) -> CGFloat {
        let headlines = repeatingHeadlines
        let spacing: CGFloat = 40

        var totalWidth: CGFloat = 0
        for headline in headlines {
            let size = headline.size(
                withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .regular)]
            )
            totalWidth += size.width + spacing
        }
        return totalWidth
    }

    private func startAnimation(totalWidth: CGFloat, screenWidth: CGFloat) {
        let duration = Double(totalWidth + screenWidth) / animationSpeed

        withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
            offset = -totalWidth
        }
    }

    private func openHeadlineURL(_ headline: String) {
        let searchQuery = headline.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.bloomberg.com/search?query=\(searchQuery)"

        if let url = URL(string: urlString) {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #elseif canImport(AppKit)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
}

extension String {
    func size(withAttributes attributes: [NSAttributedString.Key: Any]) -> CGSize {
        let attributedString = NSAttributedString(string: self, attributes: attributes)
        return attributedString.size()
    }
}

class NewsTickerService: ObservableObject {
    @Published var headlines: [String] = []

    init() {
        fetchHeadlines()
    }

    func fetchHeadlines() {
        Task {
            do {
                let feedURLString = "https://feeds.bloomberg.com/markets/news.rss"
                guard let feedURL = URL(string: feedURLString) else { return }

                let (data, _) = try await URLSession.shared.data(from: feedURL)

                let parser = RSSParser(data: data)
                let items = parser.parse()

                await MainActor.run {
                    self.headlines = items.map { $0.title }
                }
            } catch {
                print("Error fetching Bloomberg RSS: \(error)")
                await MainActor.run {
                    self.headlines = ["Unable to load Bloomberg news"]
                }
            }
        }
    }

    func refresh() {
        fetchHeadlines()
    }
}

struct RSSItem {
    let title: String
    let link: String
}

class RSSParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var items: [RSSItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""

    init(data: Data) {
        self.data = data
    }

    func parse() -> [RSSItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            currentTitle = ""
            currentLink = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if currentElement == "title" {
            currentTitle += trimmed
        } else if currentElement == "link" {
            currentLink += trimmed
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            if !currentTitle.isEmpty {
                items.append(RSSItem(title: currentTitle, link: currentLink))
            }
        }
    }
}

struct NewsTickerBanner_Previews: PreviewProvider {
    static var previews: some View {
        NewsTickerBanner()
            .previewLayout(.fixed(width: 375, height: 36))
    }
}
