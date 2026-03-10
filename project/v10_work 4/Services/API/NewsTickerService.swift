//
//  NewsTickerService.swift
//  Journal de trading 2025
//
//  Service pour le bandeau d'actualités défilant du dashboard.
//  Flux : RSS Bloomberg → GPT filter → 5 headlines courtes.
//  Fallback : si RSS bloqué, GPT génère directement les headlines.
//
//  📍 Placer dans : Services/API/NewsTickerService.swift
//

import Foundation
import Combine

@MainActor
final class NewsTickerService: ObservableObject {
    static let shared = NewsTickerService()

    @Published var headlines: [String] = []
    @Published var isLoading = false
    @Published var lastRefresh: Date?
    @Published var errorMessage: String?

    private let cooldown: TimeInterval = 600

    private let feeds: [(url: String, label: String)] = [
        ("https://feeds.bloomberg.com/markets/news.rss", "Markets"),
        ("https://feeds.bloomberg.com/economics/news.rss", "Economics"),
        ("https://feeds.bloomberg.com/politics/news.rss", "Politics"),
        ("https://feeds.bloomberg.com/crypto/news.rss", "Crypto")
    ]

    private init() {}

    // MARK: - Public

    func refresh(force: Bool = false) async {
        if !force, let last = lastRefresh, Date().timeIntervalSince(last) < cooldown {
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            // 1. Essayer les RSS
            let rawTitles = await fetchAllFeeds()
            print("📰 [Ticker] \(rawTitles.count) titres RSS bruts")

            if rawTitles.isEmpty {
                // RSS bloqué → fallback GPT direct
                print("📰 [Ticker] RSS vide → fallback GPT")
                let fallback = try await fallbackGPTHeadlines()
                headlines = fallback
            } else {
                // Filtrer avec GPT
                let filtered = try await filterWithGPT(titles: rawTitles)

                if filtered.isEmpty {
                    print("⚠️ [Ticker] GPT filtre vide → fallback titres RSS")
                    headlines = Array(rawTitles.prefix(5))
                } else {
                    headlines = filtered
                }
            }
            lastRefresh = Date()
            isLoading = false
            print("📰 [Ticker] ✅ \(headlines.count) headlines prêtes")

        } catch {
            print("❌ [Ticker] Erreur: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false

            if headlines.isEmpty {
                headlines = ["Market data temporarily unavailable"]
            }
        }
    }

    // MARK: - RSS Fetch

    private func fetchAllFeeds() async -> [String] {
        await withTaskGroup(of: [String].self) { group in
            for feed in feeds {
                group.addTask { await self.fetchFeed(feed.url, label: feed.label) }
            }
            var all: [String] = []
            for await titles in group {
                all.append(contentsOf: titles)
            }
            return Array(all.prefix(40))
        }
    }

    private nonisolated func fetchFeed(_ urlString: String, label: String) async -> [String] {
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/rss+xml, application/xml, text/xml, */*", forHTTPHeaderField: "Accept")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                let contentType = http.value(forHTTPHeaderField: "Content-Type") ?? "unknown"
                print("📰 [Ticker/\(label)] HTTP \(http.statusCode) — \(data.count) bytes — \(contentType)")
                guard (200...299).contains(http.statusCode) else {
                    print("⚠️ [Ticker/\(label)] HTTP error \(http.statusCode)")
                    return []
                }
            }

            // Vérifier que c'est du XML (pas du HTML de redirection / page d'erreur)
            if let prefix = String(data: data.prefix(500), encoding: .utf8) {
                let isXML = prefix.contains("<?xml") || prefix.contains("<rss") || prefix.contains("<feed")
                if !isXML {
                    print("⚠️ [Ticker/\(label)] Réponse non-XML. Début: \(prefix.prefix(120))")
                    return []
                }
            }

            let titles = SimpleTickerRSSParser.parseTitles(from: data)
            print("📰 [Ticker/\(label)] ✅ \(titles.count) titres parsés")
            if titles.isEmpty {
                // Debug : afficher un extrait du XML pour comprendre
                if let xmlSnippet = String(data: data.prefix(600), encoding: .utf8) {
                    print("📰 [Ticker/\(label)] XML début: \(xmlSnippet.prefix(300))")
                }
            }
            return titles
        } catch {
            print("⚠️ [Ticker/\(label)] Fetch error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - GPT Filter (RSS → headlines)

    private func filterWithGPT(titles: [String]) async throws -> [String] {
        let titlesList = titles
            .enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        let systemPrompt = """
        You are a financial news summarizer for a trading dashboard ticker.
        Rules:
        - Focus ONLY on market-moving news.
        - Priority: central banks, inflation, rates, geopolitics, oil, major tech, crypto, economic data.
        - Each headline: max 10 words, ultra concise.
        - Neutral factual tone. No commentary.
        - Return ONLY a JSON array of strings, no markdown.
        Return exactly 5 headlines sorted by market impact.
        """

        let messages = [
            ChatMessagePayload(role: "system", content: systemPrompt),
            ChatMessagePayload(role: "user", content: "Filter into 5 ultra-short market headlines:\n\n\(titlesList)")
        ]

        let response = try await CloudFunctionService.shared.openAIChatJSON(
            messages: messages,
            model: "gpt-4o-mini",
            temperature: 0.1
        )
        return parseJSONArray(response)
    }

    // MARK: - Fallback GPT (pas de RSS → GPT direct)

    private func fallbackGPTHeadlines() async throws -> [String] {
        let systemPrompt = """
        You are a financial news summarizer for a trading dashboard ticker.
        Generate the 5 most important current market-moving headlines.
        Rules:
        - Focus ONLY on news impacting financial markets RIGHT NOW.
        - Priority: central banks, inflation, rates, geopolitics, oil, major tech, crypto, economic data.
        - Each headline: max 10 words, ultra concise.
        - Neutral factual tone.
        - Return ONLY a JSON array of 5 strings, no markdown.
        """

        let messages = [
            ChatMessagePayload(role: "system", content: systemPrompt),
            ChatMessagePayload(role: "user", content: "Generate 5 current market-moving headlines for today's trading session.")
        ]

        let response = try await CloudFunctionService.shared.openAIChatJSON(
            messages: messages,
            model: "gpt-4o-mini",
            temperature: 0.3
        )
        return parseJSONArray(response)
    }

    // MARK: - JSON

    private func parseJSONArray(_ json: String) -> [String] {
        let cleaned = json
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            print("❌ [Ticker] JSON parse failed: \(cleaned.prefix(300))")
            return []
        }
        return Array(array.prefix(5))
    }
}

// MARK: - RSS Parser (robuste)

/// Item parsé depuis le flux RSS Bloomberg
struct RSSTickerItem {
    let title: String
    let imageURL: String?   // media:content url
    let link: String?
}

private enum SimpleTickerRSSParser {
    /// Retourne uniquement les titres (rétrocompatible)
    static func parseTitles(from data: Data) -> [String] {
        return parseItems(from: data).map { $0.title }
    }

    /// Retourne les items complets (titre + image + lien)
    static func parseItems(from data: Data) -> [RSSTickerItem] {
        let delegate = RSSTickerParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        parser.parse()

        if let error = parser.parserError {
            print("⚠️ [RSSParser] XML parse error: \(error.localizedDescription)")
        }

        return delegate.items
    }
}

/// XMLParserDelegate robuste pour Bloomberg RSS.
///
/// Logique clé : on capture le titre quand `</title>` se ferme
/// (et non quand `</item>` se ferme), car `foundCharacters` peut
/// être appelé plusieurs fois par fragment et le buffer doit être
/// finalisé dès la fin de la balise `<title>`.
private class RSSTickerParserDelegate: NSObject, XMLParserDelegate {
    var items: [RSSTickerItem] = []

    // État du parsing
    private var isInsideItem = false
    private var isInsideTitle = false
    private var isInsideLink = false

    // Buffers pour l'item courant
    private var titleBuffer = ""
    private var currentItemTitle = ""
    private var currentItemImage: String?
    private var currentItemLink = ""

    // Ignore le <title> du channel (celui hors <item>)
    private var channelTitleCaptured = false

    // MARK: - didStartElement

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {

        let localName = elementName.lowercased()

        // Détection <item> ou <entry> (Atom)
        if localName == "item" || localName == "entry" {
            isInsideItem = true
            currentItemTitle = ""
            currentItemImage = nil
            currentItemLink = ""
            return
        }

        // <title> — on commence à capturer
        if localName == "title" {
            isInsideTitle = true
            titleBuffer = ""
            return
        }

        // <link> — capturer le href (Atom) ou le contenu texte (RSS)
        if localName == "link" && isInsideItem {
            isInsideLink = true
            // Atom : <link href="..."/>
            if let href = attributeDict["href"], !href.isEmpty {
                currentItemLink = href
            }
            return
        }

        // media:content url="..." — image de l'article
        // XMLParser sans namespace reçoit "media:content" comme nom
        if (localName == "media:content" || localName == "content" || qName?.lowercased() == "media:content"),
           isInsideItem,
           let url = attributeDict["url"], !url.isEmpty {
            currentItemImage = url
            return
        }

        // media:thumbnail comme fallback image
        if (localName == "media:thumbnail" || qName?.lowercased() == "media:thumbnail"),
           isInsideItem,
           currentItemImage == nil,
           let url = attributeDict["url"], !url.isEmpty {
            currentItemImage = url
            return
        }
    }

    // MARK: - foundCharacters

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInsideTitle {
            titleBuffer += string
        }
        if isInsideLink && isInsideItem {
            currentItemLink += string
        }
    }

    // MARK: - foundCDATA

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if isInsideTitle, let str = String(data: CDATABlock, encoding: .utf8) {
            titleBuffer += str
        }
    }

    // MARK: - didEndElement

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {

        let localName = elementName.lowercased()

        // </title> — finaliser le titre
        if localName == "title" {
            isInsideTitle = false
            let trimmed = titleBuffer
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "  ", with: " ")

            if isInsideItem {
                // Titre de l'item
                currentItemTitle = trimmed
            } else {
                // Titre du channel — on l'ignore
                channelTitleCaptured = true
            }
            titleBuffer = ""
            return
        }

        // </link>
        if localName == "link" {
            isInsideLink = false
            return
        }

        // </item> ou </entry> — on sauvegarde l'item complet
        if localName == "item" || localName == "entry" {
            if !currentItemTitle.isEmpty {
                items.append(RSSTickerItem(
                    title: currentItemTitle,
                    imageURL: currentItemImage,
                    link: currentItemLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil
                        : currentItemLink.trimmingCharacters(in: .whitespacesAndNewlines)
                ))
            }
            isInsideItem = false
            currentItemTitle = ""
            currentItemImage = nil
            currentItemLink = ""
            return
        }
    }

    // MARK: - Error

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("⚠️ [RSSParser] Parse error: \(parseError.localizedDescription)")
    }
}
