//
//  DataExportImportService.swift
//  Journal de trading 2025
//
//  Service pour exporter et importer toutes les données de l'application
//

import Foundation
import SwiftUI

struct AppDataExport: Codable {
    let version: String
    let exportDate: Date
    let trades: [Trade]
    let exchanges: [Exchange]
    let systems: [TradingSystem]
    let alerts: [Alert]
    let moodEntries: [MoodEntry]
    let progression: Progression?
    let badges: [Badge]
    let challenges: [Challenge]
    
    enum CodingKeys: String, CodingKey {
        case version
        case exportDate
        case trades
        case exchanges
        case systems
        case alerts
        case moodEntries
        case progression
        case badges
        case challenges
    }
}

enum DataExportImportError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case fileNotFound
    case invalidFormat
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Erreur lors de l'encodage des données"
        case .decodingFailed:
            return "Erreur lors du décodage des données"
        case .fileNotFound:
            return "Fichier introuvable"
        case .invalidFormat:
            return "Format de fichier invalide"
        case .importFailed(let reason):
            return "Erreur lors de l'import: \(reason)"
        }
    }
}

class DataExportImportService {
    static let shared = DataExportImportService()
    
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Export
    
    /// Exporte toutes les données de l'application en JSON
    func exportAllData(
        trades: [Trade],
        exchanges: [Exchange],
        systems: [TradingSystem],
        alerts: [Alert],
        moodEntries: [MoodEntry],
        progression: Progression?,
        badges: [Badge],
        challenges: [Challenge]
    ) throws -> Data {
        let export = AppDataExport(
            version: "1.0",
            exportDate: Date(),
            trades: trades,
            exchanges: exchanges,
            systems: systems,
            alerts: alerts,
            moodEntries: moodEntries,
            progression: progression,
            badges: badges,
            challenges: challenges
        )
        
        do {
            let data = try encoder.encode(export)
            return data
        } catch {
            print("❌ [DataExportImportService] Erreur d'encodage: \(error)")
            throw DataExportImportError.encodingFailed
        }
    }
    
    /// Exporte les données vers un fichier dans le répertoire Documents
    func exportToFile(
        trades: [Trade],
        exchanges: [Exchange],
        systems: [TradingSystem],
        alerts: [Alert],
        moodEntries: [MoodEntry],
        progression: Progression?,
        badges: [Badge],
        challenges: [Challenge]
    ) throws -> URL {
        let data = try exportAllData(
            trades: trades,
            exchanges: exchanges,
            systems: systems,
            alerts: alerts,
            moodEntries: moodEntries,
            progression: progression,
            badges: badges,
            challenges: challenges
        )
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "trading_journal_backup_\(formatter.string(from: Date())).json"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        print("✅ [DataExportImportService] Données exportées vers: \(fileURL.path)")
        
        return fileURL
    }
    
    // MARK: - Import
    
    /// Importe les données depuis un fichier JSON
    func importFromFile(_ fileURL: URL) throws -> AppDataExport {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw DataExportImportError.fileNotFound
        }
        
        let data = try Data(contentsOf: fileURL)
        return try importFromData(data)
    }
    
    /// Importe les données depuis des données JSON
    func importFromData(_ data: Data) throws -> AppDataExport {
        do {
            let export = try decoder.decode(AppDataExport.self, from: data)
            
            // Valider la version
            guard export.version == "1.0" else {
                throw DataExportImportError.invalidFormat
            }
            
            return export
        } catch {
            print("❌ [DataExportImportService] Erreur de décodage: \(error)")
            throw DataExportImportError.decodingFailed
        }
    }
    
    // MARK: - Share Sheet Helper
    
    /// Crée un UIActivityViewController pour partager le fichier d'export
    @MainActor
    func createShareSheet(for fileURL: URL) -> UIActivityViewController {
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
        
        // Exclure certaines activités si nécessaire
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]
        
        return activityVC
    }
}

