//
//  CloudFunctionService.swift
//  Journal de trading 2025
//
//  Proxy sécurisé : appelle les Firebase Cloud Functions au lieu des API directement.
//  Les clés API restent côté serveur, jamais dans le binaire de l'app.
//
//  📍 Placer dans : Services/API/CloudFunctionService.swift
//

import Foundation
import FirebaseFunctions

// MARK: - Payload Models

struct ChatMessagePayload {
    let role: String
    let content: String

    var dictionary: [String: String] {
        ["role": role, "content": content]
    }
}

// MARK: - Cloud Function Service

final class CloudFunctionService {
    static let shared = CloudFunctionService()
    private let functions: Functions

    private init() {
        functions = Functions.functions(region: "europe-west1")

        #if DEBUG
        // Décommenter pour tester avec l'émulateur local :
        // functions.useEmulator(withHost: "localhost", port: 5001)
        #endif
    }

    // MARK: - Generic Caller

    /// Appelle une Cloud Function et retourne le résultat sous forme de dictionnaire.
    private func call(_ name: String, data: [String: Any]) async throws -> Any {
        let result = try await functions.httpsCallable(name).call(data)
        return result.data
    }

    // MARK: - 1. TwelveData : Recherche de symboles

    func searchSymbols(query: String) async throws -> [MarketSymbol] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let raw = try await call("searchSymbols", data: ["query": query])

        guard let dict = raw as? [String: Any],
              let items = dict["data"] as? [[String: Any]] else {
            return []
        }

        return items.prefix(15).compactMap { item in
            guard let symbol = item["symbol"] as? String else { return nil }

            let type: InstrumentType
            switch (item["instrument_type"] as? String)?.lowercased() {
            case "common stock", "stock", "etf":            type = .stocks
            case "forex", "physical currency":              type = .forex
            case "commodity":                                type = .futures
            case "digital currency", "cryptocurrency":      type = .crypto
            default:                                         type = .stocks
            }

            return MarketSymbol(
                symbol: symbol,
                displayName: item["instrument_name"] as? String ?? symbol,
                exchange: item["exchange"] as? String,
                instrumentType: type,
                currency: item["currency"] as? String
            )
        }
    }

    // MARK: - 2. TwelveData : Time Series → [Candle]

    func fetchTimeSeries(
        symbol: String,
        interval: String,
        outputSize: Int = 200
    ) async throws -> [Candle] {
        let raw = try await call("fetchTimeSeries", data: [
            "symbol": symbol,
            "interval": interval,
            "outputSize": outputSize
        ])

        guard let dict = raw as? [String: Any] else {
            throw TwelveDataError.apiError("Réponse invalide")
        }

        if let status = dict["status"] as? String, status == "error" {
            throw TwelveDataError.apiError(dict["message"] as? String ?? "Erreur inconnue")
        }

        guard let values = dict["values"] as? [[String: Any]] else { return [] }

        let dtFormatter = DateFormatter()
        dtFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dtFormatter.timeZone = TimeZone(identifier: "UTC")

        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.timeZone = TimeZone(identifier: "UTC")

        return values.reversed().compactMap { item in
            guard let openStr = item["open"] as? String,
                  let highStr = item["high"] as? String,
                  let lowStr = item["low"] as? String,
                  let closeStr = item["close"] as? String,
                  let open = Double(openStr),
                  let high = Double(highStr),
                  let low = Double(lowStr),
                  let close = Double(closeStr) else { return nil }

            let volume = Double(item["volume"] as? String ?? "0") ?? 0
            let datetime = item["datetime"] as? String ?? ""
            let ts = (dtFormatter.date(from: datetime) ?? dateOnly.date(from: datetime))?.timeIntervalSince1970 ?? 0

            return Candle(
                openTime: ts,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                closeTime: ts + 60
            )
        }
    }

    // MARK: - 3. Finnhub : Stock Candles → [Candle]

    func fetchStockCandles(
        symbol: String,
        resolution: String,
        from: Int,
        to: Int
    ) async throws -> [Candle] {
        let raw = try await call("fetchStockCandles", data: [
            "symbol": symbol,
            "resolution": resolution,
            "from": from,
            "to": to
        ])

        guard let dict = raw as? [String: Any],
              let status = dict["s"] as? String else {
            throw FinnhubError.noData
        }

        guard status == "ok",
              let closes = dict["c"] as? [Double],
              let highs = dict["h"] as? [Double],
              let lows = dict["l"] as? [Double],
              let opens = dict["o"] as? [Double],
              let timestamps = dict["t"] as? [Int],
              let volumes = dict["v"] as? [Double] else {
            if status == "no_data" { return [] }
            throw FinnhubError.noData
        }

        let count = min(closes.count, highs.count, lows.count, opens.count, timestamps.count, volumes.count)

        return (0..<count).map { i in
            Candle(
                openTime: Double(timestamps[i]),
                open: opens[i],
                high: highs[i],
                low: lows[i],
                close: closes[i],
                volume: volumes[i],
                closeTime: Double(timestamps[i]) + 60
            )
        }
    }

    // MARK: - 4. Finnhub : Recherche de symboles

    func searchFinnhubSymbols(query: String) async throws -> [MarketSymbol] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let raw = try await call("searchFinnhubSymbols", data: ["query": query])

        guard let dict = raw as? [String: Any],
              let items = dict["result"] as? [[String: Any]] else {
            return []
        }

        return items.prefix(15).compactMap { item in
            guard let symbol = item["symbol"] as? String else { return nil }

            let itemType = (item["type"] as? String)?.lowercased() ?? ""
            let type: InstrumentType
            if itemType.contains("crypto")                              { type = .crypto }
            else if itemType.contains("forex") || itemType.contains("fx") { type = .forex }
            else                                                         { type = .stocks }

            return MarketSymbol(
                symbol: symbol,
                displayName: item["description"] as? String ?? symbol,
                exchange: item["displaySymbol"] as? String,
                instrumentType: type,
                currency: nil
            )
        }
    }

    // MARK: - 5. OpenAI : Chat Completion

    func openAIChat(
        messages: [ChatMessagePayload],
        model: String = "gpt-4o",
        temperature: Double = 0.2,
        responseFormat: String? = nil
    ) async throws -> String {
        var data: [String: Any] = [
            "messages": messages.map { $0.dictionary },
            "model": model,
            "temperature": temperature
        ]
        if let fmt = responseFormat {
            data["responseFormat"] = fmt
        }

        let raw = try await call("openaiChat", data: data)

        guard let dict = raw as? [String: Any],
              let choices = dict["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIChatError.invalidResponse
        }

        return content
    }

    /// Variante JSON : retourne le contenu brut pour parsing côté appelant
    func openAIChatJSON(
        messages: [ChatMessagePayload],
        model: String = "gpt-4o",
        temperature: Double = 0.2
    ) async throws -> String {
        return try await openAIChat(
            messages: messages,
            model: model,
            temperature: temperature,
            responseFormat: "json"
        )
    }

    // MARK: - 6. OpenAI : Analyse d'image (Vision)

    /// Analyse une seule image
    func openAIAnalyzeImage(imageBase64: String, prompt: String) async throws -> String {
        let raw = try await call("openaiAnalyzeImage", data: [
            "imageBase64": imageBase64,
            "prompt": prompt
        ])
        return try Self.extractContent(from: raw)
    }

    /// Analyse plusieurs images (multi-timeframe)
    /// Stratégie : appels séquentiels avec contexte cumulatif
    /// La CF openaiAnalyzeImage n'accepte qu'un seul imageBase64 (string)
    func openAIAnalyzeImages(imagesBase64: [String], prompt: String) async throws -> String {
        guard !imagesBase64.isEmpty else { throw AIChatError.invalidResponse }

        // Si une seule image — appel direct
        if imagesBase64.count == 1 {
            let raw = try await call("openaiAnalyzeImage", data: [
                "imageBase64": imagesBase64[0],
                "prompt": prompt
            ])
            return try Self.extractContent(from: raw)
        }

        // Multi-images : appels séquentiels, analyse de chaque image séparément
        // puis synthèse finale avec toutes les analyses
        var partialAnalyses: [String] = []

        for (index, imageBase64) in imagesBase64.enumerated() {
            let imageNumber = index + 1
            let totalImages = imagesBase64.count
            let imagePrompt = """
            Image \(imageNumber)/\(totalImages) — \(prompt)

            IMPORTANT: Pour cette image \(imageNumber)/\(totalImages), fournis une analyse partielle UNIQUEMENT sur cette image.
            Si c'est la dernière image (\(imageNumber == totalImages ? "oui" : "non")),             \(imageNumber == totalImages
                ? "synthétise TOUTES les analyses précédentes (\(partialAnalyses.count) image(s) analysée(s)) avec celle-ci et retourne le JSON complet final."
                : "retourne juste un résumé JSON partiel de ce que tu vois, tu compléteras à la prochaine image.")
            """

            do {
                let raw = try await call("openaiAnalyzeImage", data: [
                    "imageBase64": imageBase64,
                    "prompt": imagePrompt
                ])
                let analysis = try Self.extractContent(from: raw)
                partialAnalyses.append("=== Analyse image \(imageNumber) ===\n\(analysis)")
                print("✅ [CloudFunction] Image \(imageNumber)/\(totalImages) analysée")
            } catch {
                print("⚠️ [CloudFunction] Image \(imageNumber) échec: \(error.localizedDescription)")
                // Continuer avec les autres images
            }
        }

        guard !partialAnalyses.isEmpty else { throw AIChatError.invalidResponse }

        // Si on a plusieurs analyses partielles, faire une synthèse finale
        if partialAnalyses.count > 1 {
            let synthesisPrompt = """
            Tu as analysé \(partialAnalyses.count) graphiques de trading sur différentes unités de temps.
            Voici les analyses individuelles :

            \(partialAnalyses.joined(separator: "\n\n"))

            \(prompt)

            Synthétise TOUTES ces analyses en UN SEUL JSON complet et cohérent.
            """

            // Utiliser la première image comme "ancre" visuelle pour la synthèse
            let raw = try await call("openaiAnalyzeImage", data: [
                "imageBase64": imagesBase64[0],
                "prompt": synthesisPrompt
            ])
            return try Self.extractContent(from: raw)
        }

        // Cas où une seule analyse partielle a réussi
        return partialAnalyses[0]
    }

    private static func extractContent(from raw: Any) throws -> String {
        // Log brut pour debug
        print("🔍 [CloudFunction] raw type: \(type(of: raw))")

        // Format 1 : String directe
        if let directString = raw as? String {
            print("✅ [CloudFunction] Format: String directe")
            return directString
        }

        guard let dict = raw as? [String: Any] else {
            print("❌ [CloudFunction] raw n'est ni String ni [String:Any]: \(raw)")
            throw AIChatError.invalidResponse
        }

        print("🔍 [CloudFunction] dict keys: \(dict.keys.sorted())")

        // Format 2 : { "choices": [{ "message": { "content": "..." } }] }  (OpenAI brut)
        if let choices = dict["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            print("✅ [CloudFunction] Format: OpenAI choices/message/content")
            return content
        }

        // Format 3 : { "content": "..." }
        if let content = dict["content"] as? String {
            print("✅ [CloudFunction] Format: dict[content]")
            return content
        }

        // Format 4 : { "text": "..." }
        if let text = dict["text"] as? String {
            print("✅ [CloudFunction] Format: dict[text]")
            return text
        }

        // Format 5 : { "result": "..." }
        if let result = dict["result"] as? String {
            print("✅ [CloudFunction] Format: dict[result]")
            return result
        }

        // Format 6 : { "message": "..." }
        if let message = dict["message"] as? String {
            print("✅ [CloudFunction] Format: dict[message]")
            return message
        }

        // Format 7 : { "data": "..." }
        if let data = dict["data"] as? String {
            print("✅ [CloudFunction] Format: dict[data]")
            return data
        }

        // Aucun format reconnu - logger pour diagnostic
        let dictDesc = dict.map { "\($0.key): \(type(of: $0.value))" }.joined(separator: ", ")
        print("❌ [CloudFunction] Format inconnu. Clés: \(dictDesc)")
        throw AIChatError.invalidResponse
    }

    // MARK: - Debug Test

    #if DEBUG
    func testConnection() async {
        do {
            let results = try await searchSymbols(query: "AAPL")
            print("✅ [CloudFunction] Test OK — \(results.count) résultats pour AAPL")
        } catch {
            print("❌ [CloudFunction] Test FAILED — \(error.localizedDescription)")
        }
    }
    #endif
}
