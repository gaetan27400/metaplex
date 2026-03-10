//
//  EconomicCalendarStore.swift
//  Journal de trading 2025
//
//  Store central pour le calendrier économique avec cache par période
//  Séparation claire entre fetch réseau / parsing / analyse / affichage
//

import Foundation
import Combine

/// Store central pour les événements économiques
/// Gère le cache par période et sépare les données brutes des données filtrées
final class EconomicCalendarStore: ObservableObject {
    static let shared = EconomicCalendarStore()
    
    // MARK: - Published Properties (UI)
    
    /// Tous les événements bruts chargés (non filtrés)
    @Published private(set) var rawEvents: [CalendarEvent] = []
    
    /// Analyse de risque calculée sur les données brutes
    @Published private(set) var riskAnalysis: MarketRiskAnalysis?
    
    /// État de chargement
    @Published private(set) var isLoading = false
    
    /// Message d'erreur
    @Published private(set) var errorMessage: String?
    
    // MARK: - Cache par période
    
    /// Cache des événements bruts par période
    /// Clé: "today", "tomorrow", "week"
    private var eventsCache: [String: (events: [CalendarEvent], analysis: MarketRiskAnalysis?, timestamp: Date)] = [:]
    
    /// Cache HTML par mois (déjà géré par EconomicCalendarService)
    private let cacheValidity: TimeInterval = 14400 // 4 heures — le calendrier change peu en journée
    
    // MARK: - Services
    
    private let calendarService = EconomicCalendarService.shared
    private let calendar = Calendar.current
    
    private init() {}
    
    // MARK: - Public API
    
    /// Charge les événements pour une période donnée
    /// - Parameters:
    ///   - period: La période (today, tomorrow, week)
    ///   - forceRefresh: Si true, force un refetch réseau même si le cache est valide
    /// - Returns: Les événements chargés
    @discardableResult
    func loadEvents(for period: EconomicCalendarView.PeriodFilter, forceRefresh: Bool = false) async throws -> [CalendarEvent] {
        let cacheKey = period.rawValue
        
        // Vérifier le cache
        if !forceRefresh,
           let cached = eventsCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheValidity {
            Logger.default.info("📦 Utilisation du cache pour période '\(period.displayName)'")
            await MainActor.run {
                self.rawEvents = cached.events
                self.riskAnalysis = cached.analysis
            }
            return cached.events
        }
        
        // Refetch réseau nécessaire
        Logger.default.info("🌐 FETCH RÉSEAU ForexFactory - Période: \(period.displayName)")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        defer {
            Task { @MainActor in
                self.isLoading = false
            }
        }
        
        do {
            let (startDate, endDate) = calculateDateRange(for: period)
            
            // Charger TOUS les événements (toutes volatilités) en parallèle
            async let highEvents = calendarService.fetchEvents(
                from: startDate,
                to: endDate,
                timezone: "GMT+0",
                limit: 200,
                volatility: "HIGH"
            )
            async let mediumEvents = calendarService.fetchEvents(
                from: startDate,
                to: endDate,
                timezone: "GMT+0",
                limit: 200,
                volatility: "MEDIUM"
            )
            async let lowEvents = calendarService.fetchEvents(
                from: startDate,
                to: endDate,
                timezone: "GMT+0",
                limit: 200,
                volatility: "LOW"
            )
            async let noneEvents = calendarService.fetchEvents(
                from: startDate,
                to: endDate,
                timezone: "GMT+0",
                limit: 200,
                volatility: "NONE"
            )
            
            let allResults = try await (highEvents, mediumEvents, lowEvents, noneEvents)
            
            // Combiner et dédupliquer
            var allEvents = allResults.0 + allResults.1 + allResults.2 + allResults.3
            var seenIds = Set<String>()
            allEvents = allEvents.filter { event in
                if seenIds.contains(event.id) {
                    return false
                } else {
                    seenIds.insert(event.id)
                    return true
                }
            }
            
            // Filtrer par période et trier
            let now = Date()
            let filteredEvents = allEvents
                .filter { event in
                    guard let eventDate = event.dateValue else { return false }
                    guard eventDate >= startDate && eventDate < endDate else { return false }
                    
                    if period == .today {
                        return true // Inclure même les événements passés d'aujourd'hui
                    }
                    
                    return eventDate >= now
                }
                .sorted { ($0.dateValue ?? .distantPast) < ($1.dateValue ?? .distantPast) }
            
            Logger.default.info("✅ \(filteredEvents.count) événements chargés pour période '\(period.displayName)'")
            
            // Calculer l'analyse IA sur les données BRUTES (non filtrées)
            let analysis = try await calendarService.analyzeMarketRisk(events: filteredEvents)
            
            // Mettre en cache
            eventsCache[cacheKey] = (events: filteredEvents, analysis: analysis, timestamp: Date())
            
            // Mettre à jour les propriétés publiées
            await MainActor.run {
                self.rawEvents = filteredEvents
                self.riskAnalysis = analysis
            }
            
            return filteredEvents
        } catch {
            let errorDescription = error.localizedDescription
            await MainActor.run {
                if errorDescription.contains("Clé API") || errorDescription.contains("API") {
                    self.errorMessage = "Clé API RapidAPI non configurée. Veuillez configurer votre clé API dans les paramètres de l'application."
                } else if errorDescription.contains("Quota mensuel RapidAPI dépassé") {
                    self.errorMessage = "Quota mensuel RapidAPI dépassé. Le plan BASIC a un quota limité. Veuillez attendre le renouvellement mensuel ou passer à un plan supérieur sur RapidAPI."
                } else {
                    self.errorMessage = "Erreur lors du chargement des événements: \(errorDescription)"
                }
            }
            throw error
        }
    }
    
    /// Filtre les événements bruts selon la volatilité (filtre local, pas de refetch)
    /// - Parameter volatility: Le filtre de volatilité (ALL, HIGH, MEDIUM, LOW, NONE)
    /// - Returns: Les événements filtrés
    func filteredEvents(volatility: String) -> [CalendarEvent] {
        guard volatility != "ALL" else {
            return rawEvents
        }
        
        return rawEvents.filter { event in
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
    
    /// Vide le cache pour une période donnée
    func clearCache(for period: EconomicCalendarView.PeriodFilter? = nil) {
        if let period = period {
            eventsCache.removeValue(forKey: period.rawValue)
            Logger.default.info("🗑️ Cache vidé pour période '\(period.displayName)'")
        } else {
            eventsCache.removeAll()
            Logger.default.info("🗑️ Cache vidé pour toutes les périodes")
        }
    }
    
    // MARK: - Helpers
    
    private func calculateDateRange(for period: EconomicCalendarView.PeriodFilter) -> (Date, Date) {
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch period {
        case .today:
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
            return (startOfToday, endOfToday)
            
        case .tomorrow:
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
            let endOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfTomorrow) ?? now
            return (startOfTomorrow, endOfTomorrow)
            
        case .week:
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? now
            return (startOfToday, endOfWeek)
        }
    }
}

// MARK: - PeriodFilter Protocol

/// Protocol pour les filtres de période (compatible avec EconomicCalendarView.PeriodFilter)
protocol PeriodFilterProtocol {
    var rawValue: String { get }
    var displayName: String { get }
}

extension EconomicCalendarView.PeriodFilter: PeriodFilterProtocol {}
