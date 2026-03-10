//
//  WTNotificationPreferences.swift
//  Journal de trading 2025
//
//  Gestion des préférences de notifications Wave Trend par timeframe
//

import Foundation
import Combine

final class WTNotificationPreferences: ObservableObject {
    static let shared = WTNotificationPreferences()
    
    private let userDefaults = UserDefaults.standard
    private let enabledTimeframesKey = "wt_notification_enabled_timeframes"
    private let lastSignalsKey = "wt_last_signals"
    
    // Timeframes activés pour les notifications
    @Published private(set) var enabledTimeframes: Set<WTTimeframe> = []
    
    // Dernier signal par timeframe
    @Published private(set) var lastSignals: [WTTimeframe: WTSignal] = [:]
    
    private init() {
        loadPreferences()
    }
    
    // MARK: - Load/Save Preferences
    
    private func loadPreferences() {
        // Charger les timeframes activés
        if let data = userDefaults.data(forKey: enabledTimeframesKey),
           let timeframes = try? JSONDecoder().decode([String].self, from: data) {
            enabledTimeframes = Set(timeframes.compactMap { WTTimeframe(rawValue: $0) })
        } else {
            // Par défaut, activer 1h et 4h
            enabledTimeframes = [.h1, .h4]
            saveEnabledTimeframes()
        }
        
        // Charger les derniers signaux
        if let data = userDefaults.data(forKey: lastSignalsKey),
           let signalsDict = try? JSONDecoder().decode([String: String].self, from: data) {
            lastSignals = signalsDict.compactMapKeys { WTTimeframe(rawValue: $0) }
                .compactMapValues { WTSignal(rawValue: $0) }
        }
    }
    
    private func saveEnabledTimeframes() {
        let timeframes = enabledTimeframes.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(timeframes) {
            userDefaults.set(data, forKey: enabledTimeframesKey)
        }
    }
    
    private func saveLastSignals() {
        let signalsDict = lastSignals.mapKeys { $0.rawValue }.mapValues { $0.rawValue }
        if let data = try? JSONEncoder().encode(signalsDict) {
            userDefaults.set(data, forKey: lastSignalsKey)
        }
    }
    
    // MARK: - Public API
    
    func isEnabled(for timeframe: WTTimeframe) -> Bool {
        enabledTimeframes.contains(timeframe)
    }
    
    func toggle(for timeframe: WTTimeframe) {
        if enabledTimeframes.contains(timeframe) {
            enabledTimeframes.remove(timeframe)
        } else {
            enabledTimeframes.insert(timeframe)
        }
        saveEnabledTimeframes()
    }
    
    func getLastSignal(for timeframe: WTTimeframe) -> WTSignal? {
        return lastSignals[timeframe]
    }
    
    func updateLastSignal(_ signal: WTSignal?, for timeframe: WTTimeframe) {
        if let signal = signal {
            lastSignals[timeframe] = signal
        } else {
            lastSignals.removeValue(forKey: timeframe)
        }
        saveLastSignals()
    }
    
    func shouldNotify(signal: WTSignal, for timeframe: WTTimeframe, quality: WTSignalQuality? = nil) -> Bool {
        // Ne pas notifier si :
        // 1. Le timeframe n'est pas activé
        // 2. Le signal est neutral
        // 3. Le signal est identique au précédent
        guard isEnabled(for: timeframe) else { return false }
        guard signal != .neutral else { return false }
        guard signal != getLastSignal(for: timeframe) else { return false }
        
        // Optionnel : Filtrer par score de qualité si disponible (seuil minimum 40)
        if let quality = quality, quality.score < 40 {
            return false
        }
        
        return true
    }
}

// MARK: - Dictionary Extension

private extension Dictionary {
    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
    
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result: [T: Value] = [:]
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }
}
