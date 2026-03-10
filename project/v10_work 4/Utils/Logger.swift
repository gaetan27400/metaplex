//
//  Logger.swift
//  Journal de trading 2025
//
//  Système de logging structuré avec niveaux et filtrage
//

import Foundation
import OSLog

enum LogLevel: String, Comparable {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }
    
    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.priority < rhs.priority
    }
}

/// Logger structuré pour l'application
struct Logger {
    private let category: String
    private let osLogger: OSLog?
    
    /// Crée un logger pour une catégorie spécifique
    /// - Parameter category: Catégorie (ex: "AppState", "TradeStore", "Dashboard")
    init(category: String) {
        self.category = category
        #if DEBUG
        self.osLogger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.tradingjournal", category: category)
        #else
        self.osLogger = nil
        #endif
    }
    
    /// Log un message avec un niveau
    func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        // En debug, on affiche tout
        let logMessage = "[\(category)] \(message)"
        print("\(level.rawValue) \(logMessage)")
        
        // Utiliser OSLog pour une meilleure intégration avec Instruments
        if let osLogger = osLogger {
            let osLogType: OSLogType = {
                switch level {
                case .debug: return .debug
                case .info: return .info
                case .warning: return .default
                case .error: return .error
                }
            }()
            os_log("%{public}@", log: osLogger, type: osLogType, logMessage)
        }
        #else
        // En production, on log seulement warnings et errors
        if level >= .warning {
            let logMessage = "[\(category)] \(message)"
            print("\(level.rawValue) \(logMessage)")
            
            // TODO: Envoyer à Crashlytics/Sentry en production
            // Crashlytics.crashlytics().log(logMessage)
        }
        #endif
    }
    
    /// Log debug (seulement en DEBUG)
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    /// Log info
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    /// Log warning
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    /// Log error
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var fullMessage = message
        if let error = error {
            fullMessage += " - Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error, file: file, function: function, line: line)
    }
}

// MARK: - Extensions pour faciliter l'utilisation

extension Logger {
    /// Logger par défaut pour les logs généraux
    static let `default` = Logger(category: "App")
    
    /// Logger pour AppState
    static let appState = Logger(category: "AppState")
    
    /// Logger pour les stores
    static let store = Logger(category: "Store")
    
    /// Logger pour les analytics
    static let analytics = Logger(category: "Analytics")
    
    /// Logger pour l'UI
    static let ui = Logger(category: "UI")
    
    /// Logger pour les API
    static let api = Logger(category: "API")
}
