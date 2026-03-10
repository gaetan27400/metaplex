//
//  EconomicCalendarService.swift
//  Journal de trading 2025
//
//  Service pour récupérer les événements du calendrier économique depuis ForexFactory
//

import Foundation

final class EconomicCalendarService {
    static let shared = EconomicCalendarService()
    
    private let parser = ForexFactoryParser.shared
    private var htmlCache: [String: (html: String, timestamp: Date)] = [:]
    private let cacheValidity: TimeInterval = 3600 // 1 heure de cache
    
    private let baseURL = "https://www.forexfactory.com"
    
    private init() {}
    
    /// Télécharge le HTML de ForexFactory pour une date donnée
    private func fetchForexFactoryHTML(for date: Date) async throws -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMdd" // Format "Jan25" pour ForexFactory
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let _ = dateFormatter.string(from: date).lowercased()
        
        // ForexFactory utilise un format d'URL avec le mois et le jour
        // Exemple: https://www.forexfactory.com/calendar?month=jan.2026
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        
        guard let year = components.year,
              let month = components.month else {
            throw APIError.invalidURL
        }
        
        let monthNames = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        guard month >= 1 && month <= 12 else {
            throw APIError.invalidURL
        }
        
        let monthName = monthNames[month - 1]
        let urlString = "\(baseURL)/calendar?month=\(monthName).\(year)"
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.default.error("ForexFactory HTTP Error: réponse invalide")
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            Logger.default.error("ForexFactory HTTP Error: \(httpResponse.statusCode)")
            throw APIError.invalidResponse
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw APIError.invalidResponse
        }
        
        Logger.default.info("✅ ForexFactory HTML récupéré: \(html.count) caractères")
        return html
    }
    
    /// Parse le HTML fourni manuellement (pour tests ou usage avancé)
    func parseEvents(from htmlContent: String, referenceDate: Date = Date()) throws -> [CalendarEvent] {
        let forexEvents = try parser.parseEvents(from: htmlContent, referenceDate: referenceDate)
        return forexEvents.map { convertToCalendarEvent($0) }
    }
    
    /// Récupère les événements économiques pour une période donnée depuis ForexFactory
    ///
    /// ⚠️ LOG DE DEBUG: Ce log apparaît uniquement lors d'un vrai fetch réseau
    func fetchEvents(
        countryCode: String? = nil,
        from startDate: Date,
        to endDate: Date,
        timezone: String = "GMT+0",
        limit: Int = 200,
        volatility: String = "ALL"
    ) async throws -> [CalendarEvent] {
        Logger.default.info("🌐 FETCH RÉSEAU ForexFactory - Dates: \(startDate) -> \(endDate), Volatility: \(volatility)")
        // Vérifier le cache
        let calendar = Calendar.current
        let cacheKey = "\(calendar.component(.year, from: startDate))-\(calendar.component(.month, from: startDate))"
        
        var html: String
        if let cached = htmlCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheValidity {
            html = cached.html
            Logger.default.info("📦 Utilisation du cache HTML pour \(cacheKey)")
        } else {
            // Télécharger le HTML pour le mois de startDate
            html = try await fetchForexFactoryHTML(for: startDate)
            htmlCache[cacheKey] = (html: html, timestamp: Date())
        }
        
        // Parser les événements depuis le HTML
        let forexEvents = try parser.parseEvents(from: html, referenceDate: startDate)
        
        // Convertir en CalendarEvent
        var calendarEvents = forexEvents.map { convertToCalendarEvent($0) }
        
        // Filtrer par période (startDate à endDate)
        calendarEvents = calendarEvents.filter { event in
            guard let eventDate = event.dateValue else { return false }
            return eventDate >= startDate && eventDate <= endDate
        }
        
        // Filtrer par volatilité si nécessaire
        if volatility != "ALL" {
            calendarEvents = calendarEvents.filter { event in
                let impact = event.impactValue
                switch volatility.uppercased() {
                case "HIGH": return impact == .high
                case "MEDIUM": return impact == .medium
                case "LOW": return impact == .low
                case "NONE": return impact == .low
                default: return true
                }
            }
        }
        
        // Limiter le nombre de résultats
        if calendarEvents.count > limit {
            calendarEvents = Array(calendarEvents.prefix(limit))
        }
        
        Logger.default.info("✅ \(calendarEvents.count) événements extraits depuis ForexFactory")
        return calendarEvents
    }
    
    /// Convertit un ForexFactoryEvent en CalendarEvent
    private func convertToCalendarEvent(_ forexEvent: ForexFactoryEvent) -> CalendarEvent {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        var dateUtc = dateFormatter.string(from: forexEvent.date)
        
        // Ajouter l'heure si disponible
        if let time = forexEvent.time {
            let components = time.split(separator: ":")
            if components.count == 2,
               let hour = Int(components[0]),
               let minute = Int(components[1]) {
                let calendar = Calendar.current
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: forexEvent.date)
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.second = 0
                dateComponents.timeZone = TimeZone(secondsFromGMT: 0) // UTC
                
                if let dateWithTime = calendar.date(from: dateComponents) {
                    dateUtc = dateFormatter.string(from: dateWithTime)
                }
            }
        }
        
        // Déterminer le pays depuis la devise
        let countryCode = getCountryCode(for: forexEvent.currency)
        
        // Déterminer la catégorie depuis le nom de l'événement
        let categoryId = detectCategory(from: forexEvent.name)
        
        return CalendarEvent(
            id: forexEvent.id.uuidString,
            eventId: nil,
            name: forexEvent.name,
            countryCode: countryCode,
            currencyCode: forexEvent.currency,
            dateUtc: dateUtc,
            periodDateUtc: nil,
            periodType: nil,
            volatility: forexEvent.impact.rawValue.uppercased(),
            actual: forexEvent.actual,
            revised: nil,
            consensus: forexEvent.forecast,
            previous: forexEvent.previous,
            unit: nil,
            categoryId: categoryId,
            ratioDeviation: nil,
            isBetterThanExpected: nil,
            isScoreTrackable: nil,
            isAllDay: forexEvent.isAllDay,
            isTentative: forexEvent.isTentative,
            isPreliminary: nil,
            isReport: nil,
            isSpeech: forexEvent.isSpeech,
            hasHistorical: nil
        )
    }
    
    /// Mapping devise -> code pays
    private func getCountryCode(for currency: String) -> String {
        let mapping: [String: String] = [
            "USD": "US", "EUR": "EU", "GBP": "GB", "JPY": "JP",
            "AUD": "AU", "CAD": "CA", "CHF": "CH", "CNY": "CN",
            "NZD": "NZ", "SEK": "SE", "NOK": "NO", "DKK": "DK",
            "PLN": "PL", "HUF": "HU", "CZK": "CZ", "BRL": "BR",
            "MXN": "MX", "ZAR": "ZA", "INR": "IN", "KRW": "KR"
        ]
        return mapping[currency.uppercased()] ?? "XX"
    }
    
    /// Détecte la catégorie depuis le nom de l'événement
    private func detectCategory(from eventName: String) -> String? {
        let name = eventName.lowercased()
        
        if name.contains("interest rate") || name.contains("taux d'intérêt") || name.contains("fed") || name.contains("ecb") || name.contains("boe") {
            return "interest rate"
        } else if name.contains("inflation") || name.contains("cpi") || name.contains("ppi") {
            return "inflation"
        } else if name.contains("gdp") || name.contains("pib") || name.contains("gross domestic product") {
            return "gdp"
        } else if name.contains("employment") || name.contains("emploi") || name.contains("nfp") || name.contains("non-farm payrolls") || name.contains("unemployment") {
            return "employment"
        } else if name.contains("trade") || name.contains("commerce") || name.contains("balance") {
            return "trade"
        } else if name.contains("central bank") || name.contains("banque centrale") {
            return "central bank"
        }
        
        return nil
    }
    /// Récupère les événements pour aujourd'hui
    func fetchTodayEvents(
        countryCode: String? = nil,
        timezone: String = "GMT+0",
        limit: Int = 200,
        volatility: String = "ALL"
    ) async throws -> [CalendarEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        return try await fetchEvents(
            countryCode: countryCode,
            from: today,
            to: tomorrow,
            timezone: timezone,
            limit: limit,
            volatility: volatility
        )
    }
    
    /// Récupère les événements pour demain
    func fetchTomorrowEvents(
        countryCode: String? = nil,
        timezone: String = "GMT+0",
        limit: Int = 200,
        volatility: String = "ALL"
    ) async throws -> [CalendarEvent] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let dayAfter = Calendar.current.date(byAdding: .day, value: 1, to: tomorrow) ?? Date()
        return try await fetchEvents(
            countryCode: countryCode,
            from: tomorrow,
            to: dayAfter,
            timezone: timezone,
            limit: limit,
            volatility: volatility
        )
    }
    
    /// Récupère un événement économique spécifique par son ID
    /// Note: Avec ForexFactory, on doit charger les événements et chercher par ID
    func fetchEvent(by id: String, timezone: String = "GMT+0") async throws -> CalendarEvent {
        // Charger les événements de la semaine en cours pour trouver l'événement
        let today = Calendar.current.startOfDay(for: Date())
        let weekLater = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? Date()
        
        let events = try await fetchEvents(
            from: today,
            to: weekLater,
            timezone: timezone,
            limit: 500,
            volatility: "ALL"
        )
        
        if let event = events.first(where: { $0.id == id }) {
            return event
        }
        
        throw APIError.custom("Événement avec l'ID \(id) non trouvé")
    }
    
    /// Récupère les fuseaux horaires supportés
    /// Note: ForexFactory utilise principalement GMT/UTC, on retourne une liste statique
    func fetchTimezones() async throws -> [TimezoneInfo] {
        // Retourner une liste statique de timezones courants
        // Note: TimezoneInfo.offset est un String, pas un Int
        return [
            TimezoneInfo(timezone: "GMT+0", zone: "UTC", offset: "0", name: "UTC"),
            TimezoneInfo(timezone: "GMT+1", zone: "CET", offset: "1", name: "Central European Time"),
            TimezoneInfo(timezone: "GMT+2", zone: "EET", offset: "2", name: "Eastern European Time"),
            TimezoneInfo(timezone: "GMT-5", zone: "EST", offset: "-5", name: "Eastern Standard Time"),
            TimezoneInfo(timezone: "GMT-8", zone: "PST", offset: "-8", name: "Pacific Standard Time"),
            TimezoneInfo(timezone: "GMT+9", zone: "JST", offset: "9", name: "Japan Standard Time")
        ]
    }
    
    /// Récupère le fuseau horaire par défaut
    func fetchDefaultTimezone() async throws -> String {
        return "GMT+0"
    }
    
    /// Génère une analyse IA des risques basée sur les événements
    func analyzeMarketRisk(events: [CalendarEvent]) async throws -> MarketRiskAnalysis {
        // Compter les événements par niveau de volatilité
        let highImpactEvents = events.filter { $0.impactValue == .high }
        let mediumImpactEvents = events.filter { $0.impactValue == .medium }
        let lowImpactEvents = events.filter { $0.impactValue == .low }
        
        // Événements critiques (taux, inflation, PIB) - tous niveaux de volatilité
        let criticalEvents = events.filter { event in
            let category = event.category ?? .other
            return category == .interestRate || category == .inflation || category == .gdp
        }
        
        // Calculer un score de risque pondéré avec pondération plus fine
        let riskScore = Double(highImpactEvents.count) * 3.0 +
                       Double(mediumImpactEvents.count) * 2.0 +
                       Double(lowImpactEvents.count) * 1.0 +
                       Double(criticalEvents.count) * 2.5 // Bonus pour événements critiques
        
        // Normaliser le score selon le nombre total d'événements
        let _ = events.isEmpty ? 0.0 : riskScore / Double(max(events.count, 1))
        
        // Déterminer le niveau de risque avec plus de granularité
        let riskLevel: MarketRiskAnalysis.RiskLevel
        if criticalEvents.count >= 4 || (criticalEvents.count >= 3 && highImpactEvents.count >= 3) || riskScore >= 20.0 {
            riskLevel = .critical
        } else if criticalEvents.count >= 3 || (criticalEvents.count >= 2 && highImpactEvents.count >= 4) || riskScore >= 15.0 {
            riskLevel = .veryHigh
        } else if criticalEvents.count >= 2 || highImpactEvents.count >= 5 || riskScore >= 10.0 {
            riskLevel = .high
        } else if highImpactEvents.count >= 2 || mediumImpactEvents.count >= 5 || riskScore >= 5.0 {
            riskLevel = .medium
        } else {
            riskLevel = .low
        }
        
        // Générer un résumé
        let summary = generateRiskSummary(events: events, riskLevel: riskLevel)
        
        // Générer des recommandations générales
        let recommendations = generateRecommendations(events: events, riskLevel: riskLevel)
        
        // Générer des recommandations spécifiques par marché
        let marketRecommendations = generateMarketRecommendations(events: events, riskLevel: riskLevel)
        
        // Identifier les marchés affectés
        let affectedMarkets = identifyAffectedMarkets(events: events)
        
        // Calculer le sentiment de marché et son argumentation (amélioré)
        let (sentiment, argumentation) = calculateMarketSentiment(events: events, riskLevel: riskLevel, totalCount: events.count)
        
        return MarketRiskAnalysis(
            date: Date(),
            riskLevel: riskLevel,
            summary: summary,
            events: events,
            recommendations: recommendations,
            marketRecommendations: marketRecommendations,
            affectedMarkets: affectedMarkets,
            marketSentiment: sentiment,
            sentimentArgumentation: argumentation
        )
    }
    
    // MARK: - Market Sentiment Calculation
    
    private func calculateMarketSentiment(events: [CalendarEvent], riskLevel: MarketRiskAnalysis.RiskLevel, totalCount: Int) -> (MarketRiskAnalysis.MarketSentiment, String) {
        // Si aucun événement, retourner neutre avec message explicite
        guard !events.isEmpty else {
            return (.neutral, "Aucun événement économique dans la période sélectionnée. Le sentiment de marché reste neutre en l'absence de données macroéconomiques significatives. Surveillez les événements à venir pour une analyse plus précise.")
        }
        
        // Analyser les événements pour déterminer le sentiment avec plus de nuance
        var bullishScore = 0.0
        var bearishScore = 0.0
        
        for event in events {
            let category = event.category ?? .other
            let impact = event.impactValue
            let impactWeight: Double = impact == .high ? 3.0 : (impact == .medium ? 2.0 : 1.0)
            
            // Analyser selon la catégorie
            switch category {
            case .gdp:
                if let isBetter = event.isBetterThanExpected, isBetter {
                    bullishScore += impactWeight * 2.0
                } else if let actual = event.actual, let consensus = event.consensus,
                          let actualVal = Double(actual.replacingOccurrences(of: ",", with: ".")),
                          let consensusVal = Double(consensus.replacingOccurrences(of: ",", with: ".")) {
                    if actualVal > consensusVal {
                        bullishScore += impactWeight * 1.5
                    } else if actualVal < consensusVal {
                        bearishScore += impactWeight * 1.5
                    }
                } else {
                    // Pré-publication : PIB généralement positif
                    bullishScore += impactWeight * 0.5
                }
                
            case .inflation:
                if let isBetter = event.isBetterThanExpected, !isBetter {
                    bearishScore += impactWeight * 2.5 // Inflation élevée = très négatif
                } else if let isBetter = event.isBetterThanExpected, isBetter {
                    bullishScore += impactWeight * 1.5 // Inflation basse = positif
                } else {
                    bearishScore += impactWeight * 1.0 // Par défaut, inflation = préoccupation
                }
                
            case .interestRate:
                // Les décisions de taux sont complexes
                bearishScore += impactWeight * 1.5 // Généralement négatif pour actions
                
            case .employment:
                if let isBetter = event.isBetterThanExpected, isBetter {
                    bullishScore += impactWeight * 2.0 // Emploi fort = très positif
                } else if let isBetter = event.isBetterThanExpected, !isBetter {
                    bearishScore += impactWeight * 2.0 // Emploi faible = très négatif
                } else {
                    bullishScore += impactWeight * 0.3 // Légèrement positif par défaut
                }
                
            default:
                break
            }
        }
        
        // Normaliser selon le nombre total d'événements
        let totalScore = bullishScore + bearishScore
        let bullishRatio = totalScore > 0 ? bullishScore / totalScore : 0.5
        let bearishRatio = totalScore > 0 ? bearishScore / totalScore : 0.5
        
        // Déterminer le sentiment avec seuils plus stricts
        let sentiment: MarketRiskAnalysis.MarketSentiment
        let argumentation: String
        let isEN = LanguageManager.shared.currentLanguage == .english
        
        if bullishRatio > 0.65 && bullishScore > bearishScore * 1.5 {
            sentiment = .bullish
            let strength = isEN
                ? (bullishScore > bearishScore * 2.0 ? "strongly" : "moderately")
                : (bullishScore > bearishScore * 2.0 ? "fortement" : "modérément")
            argumentation = isEN
                ? "Analysis of \(totalCount) events: \(strength) positive sentiment (score: \(String(format: "%.1f", bullishScore)) vs \(String(format: "%.1f", bearishScore))). Favorable economic indicators, including solid GDP growth and employment data, create a bullish environment. Markets should react positively to announcements, with moderate upward volatility."
                : "Analyse des \(totalCount) événements : sentiment \(strength) positif (score: \(String(format: "%.1f", bullishScore)) vs \(String(format: "%.1f", bearishScore))). Les indicateurs économiques favorables, notamment les données de croissance (PIB) et d'emploi solides, créent un environnement propice à une dynamique haussière. Les marchés devraient réagir favorablement aux annonces positives, avec une volatilité modérée orientée à la hausse."
        } else if bearishRatio > 0.65 && bearishScore > bullishScore * 1.5 {
            sentiment = .bearish
            let strength = isEN
                ? (bearishScore > bullishScore * 2.0 ? "strongly" : "moderately")
                : (bearishScore > bullishScore * 2.0 ? "fortement" : "modérément")
            argumentation = isEN
                ? "Analysis of \(totalCount) events: \(strength) negative sentiment (score: \(String(format: "%.1f", bearishScore)) vs \(String(format: "%.1f", bullishScore))). Inflationary concerns, restrictive interest rate decisions and disappointing employment data create a bearish environment. Markets should face downward pressure with increased volatility, particularly in rate-sensitive sectors."
                : "Analyse des \(totalCount) événements : sentiment \(strength) négatif (score: \(String(format: "%.1f", bearishScore)) vs \(String(format: "%.1f", bullishScore))). Les préoccupations inflationnistes, les décisions de taux d'intérêt restrictives et les données d'emploi décevantes créent un environnement baissier. Les marchés devraient subir une pression à la baisse avec une volatilité accrue, particulièrement sur les secteurs sensibles aux taux d'intérêt."
        } else {
            sentiment = .neutral
            argumentation = isEN
                ? "Analysis of \(totalCount) events: neutral sentiment with balanced forces (positive score: \(String(format: "%.1f", bullishScore)), negative score: \(String(format: "%.1f", bearishScore))). Positive and negative factors offset each other, creating a period of moderate uncertainty. Markets should trade sideways with normal volatility, requiring heightened vigilance without a clear directional bias."
                : "Analyse des \(totalCount) événements : sentiment neutre avec équilibre des forces (score positif: \(String(format: "%.1f", bullishScore)), score négatif: \(String(format: "%.1f", bearishScore))). Les facteurs positifs et négatifs se compensent, créant une période d'incertitude modérée. Les marchés devraient évoluer dans une fourchette latérale avec une volatilité normale, nécessitant une vigilance accrue sans orientation directionnelle claire."
        }
        
        return (sentiment, argumentation)
    }
    
    // MARK: - Helper Methods
    
    private func generateRiskSummary(events: [CalendarEvent], riskLevel: MarketRiskAnalysis.RiskLevel) -> String {
        let highImpactCount = events.filter { $0.impactValue == .high }.count
        let mediumImpactCount = events.filter { $0.impactValue == .medium }.count
        let lowImpactCount = events.filter { $0.impactValue == .low }.count
        let totalCount = events.count
        let upcomingEvents = events.filter { ($0.dateValue ?? .distantPast) > Date() }
        let isEN = LanguageManager.shared.currentLanguage == .english
        
        switch riskLevel {
        case .critical:
            return isEN
                ? "⚠️ Critical risk detected: \(totalCount) events scheduled (\(highImpactCount) high, \(mediumImpactCount) medium, \(lowImpactCount) low), including several simultaneous major announcements (interest rates, inflation, GDP). This concentration of critical events creates an extremely high volatility environment with potentially extreme market moves. Traders should expect significant gaps and violent reactions to announcements."
                : "⚠️ Risque critique détecté : \(totalCount) événements prévus (\(highImpactCount) élevés, \(mediumImpactCount) moyens, \(lowImpactCount) faibles), dont plusieurs annonces majeures simultanées (taux d'intérêt, inflation, PIB). Cette concentration d'événements critiques crée un environnement de très haute volatilité avec des mouvements de marché potentiellement extrêmes. Les traders doivent s'attendre à des gaps importants et des réactions violentes aux annonces."
        case .veryHigh:
            return isEN
                ? "🔴 Very high risk: \(totalCount) economic events scheduled (\(highImpactCount) high, \(mediumImpactCount) medium). Several major announcements are scheduled, creating a high-volatility environment. Markets should react strongly to releases, with risks of significant directional moves."
                : "🔴 Risque très élevé : \(totalCount) événements économiques prévus (\(highImpactCount) élevés, \(mediumImpactCount) moyens). Plusieurs annonces majeures sont programmées, créant un environnement de haute volatilité. Les marchés devraient réagir fortement aux publications, avec des risques de mouvements directionnels importants."
        case .high:
            return isEN
                ? "🟠 High risk: \(totalCount) economic events scheduled (\(highImpactCount) high, \(mediumImpactCount) medium). Significant increase in expected volatility, particularly on interest rate and inflation-linked markets. Traders must be prepared for substantial market moves."
                : "🟠 Risque élevé : \(totalCount) événements économiques prévus (\(highImpactCount) élevés, \(mediumImpactCount) moyens). Augmentation significative de la volatilité attendue, particulièrement sur les marchés liés aux taux d'intérêt et à l'inflation. Les traders doivent être préparés à des mouvements de marché substantiels."
        case .medium:
            return isEN
                ? "🟡 Moderate risk: \(upcomingEvents.count) economic events scheduled (\(highImpactCount) high, \(mediumImpactCount) medium). Some events may impact market volatility, especially central bank announcements. Normal to moderate volatility expected."
                : "🟡 Risque modéré : \(upcomingEvents.count) événements économiques prévus (\(highImpactCount) élevés, \(mediumImpactCount) moyens). Certains événements peuvent impacter la volatilité des marchés, notamment les annonces de banques centrales. Volatilité normale à modérée attendue."
        case .low:
            return isEN
                ? "🟢 Low risk: \(totalCount) economic events scheduled, mostly low-impact. Relatively stable market conditions expected with normal volatility. Good trading opportunities in a calm environment."
                : "🟢 Risque faible : \(totalCount) événements économiques prévus, majoritairement à faible impact. Conditions de marché relativement stables attendues avec une volatilité normale. Opportunités de trading dans un environnement calme."
        }
    }
    
    private func generateRecommendations(events: [CalendarEvent], riskLevel: MarketRiskAnalysis.RiskLevel) -> [String] {
        var recommendations: [String] = []
        let isEN = LanguageManager.shared.currentLanguage == .english
        
        let interestRateEvents = events.filter { ($0.category ?? .other) == .interestRate }
        let inflationEvents = events.filter { ($0.category ?? .other) == .inflation }
        let employmentEvents = events.filter { ($0.category ?? .other) == .employment }
        
        switch riskLevel {
        case .critical:
            recommendations.append(isEN ? "Drastically reduce exposure on high-leverage positions (max 2:1)" : "Réduire drastiquement l'exposition aux positions à fort effet de levier (max 2:1)")
            recommendations.append(isEN ? "Monitor all central bank and macroeconomic announcements in real time" : "Surveiller en temps réel toutes les annonces de banques centrales et macroéconomiques")
            recommendations.append(isEN ? "Place very tight stop-loss orders (max 1-2%) on all positions" : "Placer des ordres stop-loss très serrés (1-2% maximum) sur toutes les positions")
            recommendations.append(isEN ? "Avoid opening new positions in the hours before major announcements" : "Éviter d'ouvrir de nouvelles positions dans les heures précédant les annonces majeures")
            if !interestRateEvents.isEmpty {
                recommendations.append(isEN ? "Anticipate extreme volatility around rate decisions: reduce positions 24h before" : "Anticiper une volatilité extrême autour des décisions de taux : réduire les positions 24h avant")
            }
        case .veryHigh:
            recommendations.append(isEN ? "Significantly reduce exposure on high-leverage positions (max 3:1)" : "Réduire significativement l'exposition aux positions à fort effet de levier (max 3:1)")
            recommendations.append(isEN ? "Closely monitor central bank and macroeconomic announcements" : "Surveiller attentivement les annonces de banques centrales et macroéconomiques")
            recommendations.append(isEN ? "Place tight stop-loss orders (max 2-3%) on all positions" : "Placer des ordres stop-loss serrés (2-3% maximum) sur toutes les positions")
            recommendations.append(isEN ? "Avoid opening new positions in the 12h before major announcements" : "Éviter d'ouvrir de nouvelles positions dans les 12h précédant les annonces majeures")
            if !interestRateEvents.isEmpty {
                recommendations.append(isEN ? "Anticipate very high volatility around rate decisions" : "Anticiper une volatilité très élevée autour des décisions de taux")
            }
        case .high:
            recommendations.append(isEN ? "Increase vigilance on open positions and slightly reduce leverage" : "Augmenter la vigilance sur les positions ouvertes et réduire légèrement l'effet de levier")
            recommendations.append(isEN ? "Monitor major economic events and their impacts" : "Surveiller les événements économiques majeurs et leurs impacts")
            recommendations.append(isEN ? "Place moderate stop-loss orders (3-5%) on sensitive positions" : "Placer des ordres stop-loss modérés (3-5%) sur les positions sensibles")
            if !inflationEvents.isEmpty {
                recommendations.append(isEN ? "Inflation data can significantly impact markets: be ready to react quickly" : "Les données d'inflation peuvent impacter significativement les marchés : être prêt à réagir rapidement")
            }
        case .medium:
            recommendations.append(isEN ? "Maintain normal position monitoring with increased vigilance" : "Maintenir une surveillance normale des positions avec vigilance accrue")
            recommendations.append(isEN ? "Monitor economic events to anticipate moves" : "Surveiller les événements économiques pour anticiper les mouvements")
            if !employmentEvents.isEmpty {
                recommendations.append(isEN ? "Employment data can influence markets, especially forex" : "Les données d'emploi peuvent influencer les marchés, notamment le forex")
            }
        case .low:
            recommendations.append(isEN ? "Favorable market conditions for trading with normal volatility" : "Conditions de marché favorables pour le trading avec volatilité normale")
            recommendations.append(isEN ? "Maintain standard risk management" : "Maintenir une gestion de risque standard")
        }
        
        return recommendations
    }
    
    // MARK: - Market-Specific Recommendations (Amélioré avec analyse précise et directive)
    
    private func generateMarketRecommendations(events: [CalendarEvent], riskLevel: MarketRiskAnalysis.RiskLevel) -> [MarketRiskAnalysis.MarketRecommendation] {
        var marketRecs: [MarketRiskAnalysis.MarketRecommendation] = []
        
        let interestRateEvents = events.filter { ($0.category ?? .other) == .interestRate }
        let inflationEvents = events.filter { ($0.category ?? .other) == .inflation }
        let gdpEvents = events.filter { ($0.category ?? .other) == .gdp }
        let employmentEvents = events.filter { ($0.category ?? .other) == .employment }
        
        // Trouver l'événement le plus important (priorité: taux > inflation > emploi > PIB)
        let mostImportantEvent = findMostImportantEvent(events: events)
        
        // Crypto - Analyse précise et directive
        let cryptoAnalysis = generateCryptoAnalysis(
            events: events,
            inflationEvents: inflationEvents,
            interestRateEvents: interestRateEvents,
            mostImportantEvent: mostImportantEvent,
            riskLevel: riskLevel
        )
        marketRecs.append(cryptoAnalysis)
        
        // Forex - Analyse précise et directive
        let forexAnalysis = generateForexAnalysis(
            events: events,
            interestRateEvents: interestRateEvents,
            inflationEvents: inflationEvents,
            employmentEvents: employmentEvents,
            gdpEvents: gdpEvents,
            mostImportantEvent: mostImportantEvent,
            riskLevel: riskLevel
        )
        marketRecs.append(forexAnalysis)
        
        // Actions - Analyse précise et directive
        let actionsAnalysis = generateActionsAnalysis(
            events: events,
            interestRateEvents: interestRateEvents,
            gdpEvents: gdpEvents,
            inflationEvents: inflationEvents,
            mostImportantEvent: mostImportantEvent,
            riskLevel: riskLevel
        )
        marketRecs.append(actionsAnalysis)
        
        // Commodities - Analyse précise et directive
        let commoditiesAnalysis = generateCommoditiesAnalysis(
            events: events,
            inflationEvents: inflationEvents,
            gdpEvents: gdpEvents,
            interestRateEvents: interestRateEvents,
            mostImportantEvent: mostImportantEvent,
            riskLevel: riskLevel
        )
        marketRecs.append(commoditiesAnalysis)
        
        return marketRecs
    }
    
    // MARK: - Helper Functions pour analyses précises
    
    private func findMostImportantEvent(events: [CalendarEvent]) -> CalendarEvent? {
        // Priorité: taux > inflation > emploi > PIB
        let sortedEvents = events.sorted { event1, event2 in
            let priority1 = eventPriority(event1)
            let priority2 = eventPriority(event2)
            if priority1 != priority2 {
                return priority1 > priority2
            }
            // Si même priorité, prendre celui avec le plus haut impact
            return event1.impactValue.rawValue > event2.impactValue.rawValue
        }
        return sortedEvents.first
    }
    
    private func eventPriority(_ event: CalendarEvent) -> Int {
        let category = event.category ?? .other
        switch category {
        case .interestRate, .centralBank: return 4
        case .inflation: return 3
        case .employment: return 2
        case .gdp: return 1
        default: return 0
        }
    }
    
    private func generateCryptoAnalysis(
        events: [CalendarEvent],
        inflationEvents: [CalendarEvent],
        interestRateEvents: [CalendarEvent],
        mostImportantEvent: CalendarEvent?,
        riskLevel: MarketRiskAnalysis.RiskLevel
    ) -> MarketRiskAnalysis.MarketRecommendation {
        let analyzer = AIEventAnalyzer.shared
        
        // Déterminer le titre basé sur l'événement le plus important
        let title: String
        let sentiment: MarketRiskAnalysis.MarketSentiment
        let intensity: String
        let explanation: String
        var actionableRecs: [String] = []
        
        if let mainEvent = mostImportantEvent {
            let insight = analyzer.analyzeEvent(mainEvent)
            let eventName = mainEvent.name.contains("CPI") ? "CPI" : (mainEvent.name.contains("Inflation") ? "Inflation" : mainEvent.name)
            
            // Déterminer la direction pour le titre
            if let actual = mainEvent.actual, let previous = mainEvent.previous {
                let parser = MacroValueParser.shared
                let actualParsed = parser.parseMacroValue(actual)
                let previousParsed = parser.parseMacroValue(previous)
                
                if actualParsed.isValid && previousParsed.isValid,
                   let actualVal = actualParsed.numericValue,
                   let previousVal = previousParsed.numericValue {
                    if actualVal > previousVal {
                        title = "Crypto — \(eventName) en hausse"
                        sentiment = .bearish
                    } else if actualVal < previousVal {
                        title = "Crypto — \(eventName) en baisse"
                        sentiment = .bullish
                    } else {
                        title = "Crypto — \(eventName) stable"
                        sentiment = .neutral
                    }
                } else {
                    title = "Crypto — \(eventName)"
                    sentiment = insight.eventSentiment == .bullish ? .bullish : (insight.eventSentiment == .bearish ? .bearish : .neutral)
                }
            } else {
                title = "Crypto — \(eventName)"
                sentiment = insight.eventSentiment == .bullish ? .bullish : (insight.eventSentiment == .bearish ? .bearish : .neutral)
            }
            
            intensity = insight.intensity
            
            // Générer l'explication détaillée
            if mainEvent.category == .inflation {
                if sentiment == .bearish {
                    explanation = "Un \(eventName) supérieur au précédent indique une inflation persistante, renforçant les anticipations de politique monétaire restrictive et de liquidité réduite. Ce contexte est généralement très défavorable aux cryptomonnaies, qui réagissent comme des actifs à risque."
                } else {
                    explanation = "Un \(eventName) inférieur au précédent peut réduire les pressions sur la liquidité, potentiellement favorable aux cryptomonnaies. Cependant, la réaction dépendra de l'interprétation des banques centrales."
                }
            } else if mainEvent.category == .interestRate {
                explanation = "Les décisions de taux d'intérêt impactent directement la liquidité globale. Une hausse de taux réduit la liquidité disponible pour les actifs risqués comme les cryptomonnaies, créant une pression baissière."
            } else {
                explanation = insight.summary
            }
            
            // Recommandations actionnables
            if sentiment == .bearish {
                actionableRecs.append("Pression baissière accrue")
                actionableRecs.append("Volatilité élevée")
                actionableRecs.append("Altcoins particulièrement vulnérables")
                actionableRecs.append("Risque de liquidations sur les positions à levier")
            } else if sentiment == .bullish {
                actionableRecs.append("Potentiel de rebond si liquidité améliorée")
                actionableRecs.append("Surveiller les réactions des banques centrales")
            } else {
                actionableRecs.append("Volatilité modérée attendue")
            }
        } else {
            title = "Crypto — Aucun événement majeur"
            sentiment = .neutral
            intensity = "Faible"
            explanation = "Aucun événement économique majeur prévu. Conditions de marché normales pour les cryptomonnaies."
            actionableRecs.append("Maintenir une position prudente avec des stop-loss serrés")
        }
        
        // Ajouter des recommandations générales selon le niveau de risque
        if riskLevel == .critical || riskLevel == .veryHigh {
            actionableRecs.append("Réduire l'exposition, éviter le levier élevé, privilégier le spot")
        }
        
        return MarketRiskAnalysis.MarketRecommendation(
            market: "Crypto",
            recommendations: actionableRecs,
            rationale: explanation,
            title: title,
            sentiment: sentiment,
            intensity: intensity,
            explanation: explanation,
            actionableRecommendations: actionableRecs
        )
    }
    
    private func generateForexAnalysis(
        events: [CalendarEvent],
        interestRateEvents: [CalendarEvent],
        inflationEvents: [CalendarEvent],
        employmentEvents: [CalendarEvent],
        gdpEvents: [CalendarEvent],
        mostImportantEvent: CalendarEvent?,
        riskLevel: MarketRiskAnalysis.RiskLevel
    ) -> MarketRiskAnalysis.MarketRecommendation {
        // Similar logic for Forex
        let title = mostImportantEvent != nil ? "Forex — \(mostImportantEvent!.name)" : "Forex — Aucun événement majeur"
        let sentiment: MarketRiskAnalysis.MarketSentiment = .neutral
        let intensity = riskLevel == .critical || riskLevel == .veryHigh ? "Élevée" : (riskLevel == .high ? "Modérée" : "Faible")
        let explanation = "Le forex est directement impacté par les décisions de banques centrales et les données macroéconomiques."
        var actionableRecs: [String] = []
        
        if !interestRateEvents.isEmpty {
            actionableRecs.append("Surveiller les paires majeures (EUR/USD, GBP/USD, USD/JPY)")
            actionableRecs.append("Anticiper les réactions des devises : hausse de taux = renforcement de la devise")
        }
        if !inflationEvents.isEmpty {
            actionableRecs.append("L'inflation impacte les devises : inflation élevée = dépréciation potentielle")
        }
        if actionableRecs.isEmpty {
            actionableRecs.append("Maintenir une vigilance sur les positions ouvertes avec des stop-loss adaptés")
        }
        
        return MarketRiskAnalysis.MarketRecommendation(
            market: "Forex",
            recommendations: actionableRecs,
            rationale: explanation,
            title: title,
            sentiment: sentiment,
            intensity: intensity,
            explanation: explanation,
            actionableRecommendations: actionableRecs
        )
    }
    
    private func generateActionsAnalysis(
        events: [CalendarEvent],
        interestRateEvents: [CalendarEvent],
        gdpEvents: [CalendarEvent],
        inflationEvents: [CalendarEvent],
        mostImportantEvent: CalendarEvent?,
        riskLevel: MarketRiskAnalysis.RiskLevel
    ) -> MarketRiskAnalysis.MarketRecommendation {
        let title = mostImportantEvent != nil ? "Actions — \(mostImportantEvent!.name)" : "Actions — Aucun événement majeur"
        let sentiment: MarketRiskAnalysis.MarketSentiment = .neutral
        let intensity = riskLevel == .critical || riskLevel == .veryHigh ? "Élevée" : (riskLevel == .high ? "Modérée" : "Faible")
        let explanation = "Les actions sont sensibles aux décisions de taux d'intérêt et aux données macroéconomiques."
        var actionableRecs: [String] = []
        
        if !interestRateEvents.isEmpty {
            actionableRecs.append("Réduire l'exposition aux secteurs sensibles aux taux (immobilier, utilities)")
            actionableRecs.append("Privilégier les secteurs défensifs (consommation, santé)")
        }
        if actionableRecs.isEmpty {
            actionableRecs.append("Maintenir une allocation équilibrée avec une vigilance accrue")
        }
        
        return MarketRiskAnalysis.MarketRecommendation(
            market: "Actions",
            recommendations: actionableRecs,
            rationale: explanation,
            title: title,
            sentiment: sentiment,
            intensity: intensity,
            explanation: explanation,
            actionableRecommendations: actionableRecs
        )
    }
    
    private func generateCommoditiesAnalysis(
        events: [CalendarEvent],
        inflationEvents: [CalendarEvent],
        gdpEvents: [CalendarEvent],
        interestRateEvents: [CalendarEvent],
        mostImportantEvent: CalendarEvent?,
        riskLevel: MarketRiskAnalysis.RiskLevel
    ) -> MarketRiskAnalysis.MarketRecommendation {
        let title = mostImportantEvent != nil ? "Commodities — \(mostImportantEvent!.name)" : "Commodities — Aucun événement majeur"
        let sentiment: MarketRiskAnalysis.MarketSentiment = .neutral
        let intensity = riskLevel == .critical || riskLevel == .veryHigh ? "Élevée" : (riskLevel == .high ? "Modérée" : "Faible")
        let explanation = "Les matières premières réagissent à l'inflation, à la croissance et à la politique monétaire."
        var actionableRecs: [String] = []
        
        if !inflationEvents.isEmpty {
            actionableRecs.append("L'inflation est généralement positive pour les matières premières (or, pétrole)")
            actionableRecs.append("L'or peut servir de couverture contre l'inflation")
        }
        if actionableRecs.isEmpty {
            actionableRecs.append("Surveiller les positions avec une attention particulière aux données macroéconomiques")
        }
        
        return MarketRiskAnalysis.MarketRecommendation(
            market: "Commodities",
            recommendations: actionableRecs,
            rationale: explanation,
            title: title,
            sentiment: sentiment,
            intensity: intensity,
            explanation: explanation,
            actionableRecommendations: actionableRecs
        )
    }
    
    private func identifyAffectedMarkets(events: [CalendarEvent]) -> [String] {
        var markets: Set<String> = []
        
        for event in events where event.impactValue == .high {
            let category = event.category ?? .other
            switch category {
            case .interestRate, .centralBank:
                markets.insert("Forex")
                markets.insert("Obligations")
                markets.insert("Actions")
            case .inflation:
                markets.insert("Forex")
                markets.insert("Obligations")
                markets.insert("Matières premières")
            case .gdp:
                markets.insert("Actions")
                markets.insert("Forex")
            case .employment:
                markets.insert("Forex")
                markets.insert("Actions")
            case .trade:
                markets.insert("Forex")
                markets.insert("Matières premières")
            case .other:
                break
            }
        }
        
        return Array(markets).sorted()
    }
}

// MARK: - API Error Extension

extension APIError {
    static let missingAPIKey = APIError.custom("Clé API RapidAPI manquante. Veuillez configurer votre clé API dans les paramètres.")
}
