//
//  OpenAIChartAnalyzer.swift
//  Journal de trading 2025
//
//  Service pour analyser des graphiques de trading via OpenAI Vision
//  Supporte l'analyse mono-image et multi-timeframe
//

import Foundation
import UIKit

final class OpenAIChartAnalyzer {
    private let model: String
    
    init?(model: String = "gpt-4o") {
        self.model = model
        print("✅ [OpenAIChartAnalyzer] Initialized with model: \(model) (via Cloud Functions)")
    }
    
    // MARK: - Analyse mono-image (rétrocompatibilité)
    
    func analyzeChart(_ image: UIImage, language: Localizable.Language = .french) async throws -> ChartAnalysis {
        print("🔄 [OpenAIChartAnalyzer] Starting single chart analysis (language: \(language.rawValue))")
        let images = [TimeframeImage(timeframe: .daily, image: image)]
        return try await analyzeMultiTimeframe(images: images, language: language, isSingleImage: true)
    }
    
    // MARK: - Analyse multi-timeframe
    
    func analyzeMultiTimeframe(images: [TimeframeImage], language: Localizable.Language = .french, isSingleImage: Bool = false) async throws -> ChartAnalysis {
        let sortedImages = images.sorted { $0.timeframe.sortOrder < $1.timeframe.sortOrder }
        let timeframeCount = sortedImages.count
        let isMulti = timeframeCount > 1
        
        print("🔄 [OpenAIChartAnalyzer] Starting analysis with \(timeframeCount) timeframe(s) (language: \(language.rawValue))")
        
        // Construire les contenus image en base64
        var imageContents: [[String: Any]] = []
        var timeframeList: [String] = []
        
        for tfImage in sortedImages {
            guard let imageData = tfImage.image.jpegData(compressionQuality: 0.8) else {
                throw ChartAnalysisError.invalidImage
            }
            let base64Image = imageData.base64EncodedString()
            
            timeframeList.append(tfImage.timeframe.rawValue)
            
            // Ajouter un label texte avant chaque image
            imageContents.append([
                "type": "text",
                "text": "📊 Timeframe: \(tfImage.timeframe.rawValue)"
            ])
            
            imageContents.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)"
                ]
            ])
        }
        
        // Prompt selon langue et mode (mono vs multi)
        let (prompt, systemMessageContent) = buildPrompt(
            language: language,
            isMulti: isMulti,
            isSingleImage: isSingleImage,
            timeframes: timeframeList
        )
        
        // Ajouter le prompt en premier dans les contenus
        var allContents: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]
        allContents.append(contentsOf: imageContents)
        
        let userMessage: [String: Any] = [
            "role": "user",
            "content": allContents
        ]
        
        let systemMessage: [String: Any] = [
            "role": "system",
            "content": systemMessageContent
        ]
        
        // Ajuster la compression selon le nombre d'images pour rester dans les limites de tokens
        // Plus d'images = compression plus forte pour éviter les timeout/erreurs de taille
        // Compression adaptative : plus d'images = images plus légères pour éviter timeout Firebase
        let compression: CGFloat = timeframeCount == 1 ? 0.80 : timeframeCount == 2 ? 0.60 : 0.45

        // Encoder TOUTES les images en base64
        var allBase64: [String] = []
        for img in sortedImages {
            // Redimensionner si nécessaire pour limiter la taille du payload
            let resized = Self.resizeIfNeeded(img.image, maxDimension: 1024)
            guard let imageData = resized.jpegData(compressionQuality: compression) else {
                throw ChartAnalysisError.invalidImage
            }
            let sizeKB = imageData.count / 1024
            print("📦 [OpenAIChartAnalyzer] Image \(img.timeframe.rawValue): \(sizeKB) KB")
            allBase64.append(imageData.base64EncodedString())
        }

        guard !allBase64.isEmpty else { throw ChartAnalysisError.invalidImage }

        let fullPrompt = systemMessageContent + "\n\n" + prompt

        print("🌐 [OpenAIChartAnalyzer] Calling Cloud Function for chart analysis (\(timeframeCount) image(s))")

        do {
            let responseText: String
            if allBase64.count == 1 {
                // Mono-image : appel direct
                responseText = try await CloudFunctionService.shared.openAIAnalyzeImage(
                    imageBase64: allBase64[0],
                    prompt: fullPrompt
                )
            } else {
                // Multi-images : envoyer toutes les images
                responseText = try await CloudFunctionService.shared.openAIAnalyzeImages(
                    imagesBase64: allBase64,
                    prompt: fullPrompt
                )
            }
            
            print("✅ [OpenAIChartAnalyzer] Response received, length: \(responseText.count)")
            print("🔍 [OpenAIChartAnalyzer] Response preview: \(responseText.prefix(200))")
            
            // Nettoyer le contenu — extraction robuste du bloc JSON
            let analysis = try Self.parseChartAnalysis(from: responseText, isMulti: isMulti)
            return analysis
        } catch let error as ChartAnalysisError {
            throw error
        } catch {
            print("❌ [OpenAIChartAnalyzer] Cloud Function error: \(error)")
            throw ChartAnalysisError.decodingError(error)
        }
    }
    
    // MARK: - Prompt Builder
    
    private func buildPrompt(language: Localizable.Language, isMulti: Bool, isSingleImage: Bool, timeframes: [String]) -> (String, String) {
        let tfList = timeframes.joined(separator: ", ")
        
        switch language {
        case .french:
            return buildFrenchPrompt(isMulti: isMulti, isSingleImage: isSingleImage, tfList: tfList)
        case .english:
            return buildEnglishPrompt(isMulti: isMulti, isSingleImage: isSingleImage, tfList: tfList)
        }
    }
    
    private func buildFrenchPrompt(isMulti: Bool, isSingleImage: Bool, tfList: String) -> (String, String) {
        let multiBlock: String
        if isMulti {
            multiBlock = """
            
            ⚠️ IMPORTANT — ANALYSE MULTI-TIMEFRAME :
            L'utilisateur fournit \(tfList.components(separatedBy: ", ").count) graphiques sur les UT suivantes : \(tfList).
            Tu dois CROISER les informations de chaque UT pour fournir une analyse enrichie.
            
            Pour chaque section, précise ce que tu vois sur chaque UT et les convergences/divergences.
            
            CHAMPS SUPPLÉMENTAIRES OBLIGATOIRES :
            - "confluences" : Détaille les confluences entre UT (zones de prix, niveaux clés, patterns qui se retrouvent sur plusieurs UT)
            - "risques" : Risques spécifiques identifiés par le croisement des UT (divergences, incohérences)
            - "scenario_alternatif" : Scénario alternatif si le plan principal échoue, basé sur les UT supérieures
            - "rr" dans plan : Ratio risque/récompense estimé
            - "zones_retournement" dans plan : Zones de retournement éventuel identifiées par croisement des UT
            """
        } else {
            multiBlock = """
            
            Note : L'utilisateur fournit une seule image. Les champs "confluences", "risques", "scenario_alternatif", "rr" et "zones_retournement" doivent être null dans ta réponse.
            """
        }
        
        let prompt = """
        Tu es un trader professionnel expert en price action, structure de marché et analyse technique multi-timeframe.

        L'utilisateur envoie \(isMulti ? "plusieurs captures d'écran de graphiques sur différentes unités de temps" : "une capture d'écran d'un graphique") (crypto, actions ou forex).
        \(multiBlock)

        Ta mission n'est PAS de décrire l'image.
        Ta mission est de produire une ANALYSE DE TRADING CLAIRE, PROFESSIONNELLE et IMMÉDIATEMENT ACTIONNABLE.

        Tu dois penser comme un trader, mais t'exprimer comme un pédagogue.

        STRUCTURE OBLIGATOIRE DE SORTIE :

        🔎 Lecture rapide du marché
        🧱 Structure de marché
        📍 Zones clés
        📈 Tendance & Momentum
        🕯️ Patterns & Chandeliers
        📊 Indicateurs
        🧭 Lecture Multi-Timeframe\(isMulti ? " (CROISEMENT DÉTAILLÉ de chaque UT fournie)" : "")
        🎯 Plan de trade\(isMulti ? " (ENRICHI avec R:R et zones de retournement)" : "")
        🧠 Psychologie de marché\(isMulti ? "\n🔗 Confluences inter-UT\n⚠️ Risques identifiés\n🔄 Scénario alternatif" : "")

        RÈGLES :
        - Pas de description visuelle
        - Pas de phrases génériques
        - Phrases courtes, claires, actionnables
        - Réponds UNIQUEMENT en français\(isMulti ? "\n- CROISE systématiquement les informations entre les différentes UT" : "")

        DÉTECTION DU SYMBOLE :
        Si tu identifies clairement l'actif (ex: BTC/USDT, ETH/USDT, SOL/USDT...), retourne son symbole Binance sans slash (ex: "BTCUSDT").
        Si c'est une action, forex, ou si tu ne peux pas identifier l'actif avec certitude, retourne null.

        Réponds STRICTEMENT au format JSON suivant, sans aucun texte autour :

        {
          "symbol": "BTCUSDT",
          "resume": "",
          "structure": "",
          "zones": "",
          "momentum": "",
          "patterns": "",
          "indicateurs": "",
          "mtf": "",
          "plan": {
            "biais": "",
            "entree": "",
            "stop": "",
            "objectifs": "",
            "confirmation": "",
            "invalidation": ""\(isMulti ? ",\n    \"rr\": \"\",\n    \"zones_retournement\": \"\"" : ",\n    \"rr\": null,\n    \"zones_retournement\": null")
          },
          "psychologie": ""\(isMulti ? ",\n  \"confluences\": \"\",\n  \"risques\": \"\",\n  \"scenario_alternatif\": \"\"" : ",\n  \"confluences\": null,\n  \"risques\": null,\n  \"scenario_alternatif\": null")
        }
        """
        
        let system = "Tu es un trader professionnel expert. Réponds UNIQUEMENT en français et en JSON valide, sans aucun texte avant ou après. Le JSON doit être valide et commencer par '{' et finir par '}'.\(isMulti ? " Tu reçois plusieurs images de différentes unités de temps — croise les analyses pour un résultat enrichi." : "")"
        
        return (prompt, system)
    }
    
    private func buildEnglishPrompt(isMulti: Bool, isSingleImage: Bool, tfList: String) -> (String, String) {
        let multiBlock: String
        if isMulti {
            multiBlock = """
            
            ⚠️ IMPORTANT — MULTI-TIMEFRAME ANALYSIS:
            The user provides \(tfList.components(separatedBy: ", ").count) charts on the following timeframes: \(tfList).
            You must CROSS-REFERENCE information from each TF to provide an enriched analysis.
            
            For each section, specify what you see on each TF and the convergences/divergences.
            
            MANDATORY ADDITIONAL FIELDS:
            - "confluences": Detail confluences between TFs (price zones, key levels, patterns found on multiple TFs)
            - "risques": Specific risks identified by cross-referencing TFs (divergences, inconsistencies)
            - "scenario_alternatif": Alternative scenario if the main plan fails, based on higher TFs
            - "rr" in plan: Estimated risk/reward ratio
            - "zones_retournement" in plan: Potential reversal zones identified by cross-referencing TFs
            """
        } else {
            multiBlock = """
            
            Note: The user provides a single image. The fields "confluences", "risques", "scenario_alternatif", "rr" and "zones_retournement" must be null in your response.
            """
        }
        
        let prompt = """
        You are a professional trader expert in price action, market structure and multi-timeframe technical analysis.

        The user sends \(isMulti ? "multiple chart screenshots from different timeframes" : "a screenshot of a chart") (crypto, stocks or forex).
        \(multiBlock)

        Your mission is NOT to describe the image.
        Your mission is to produce a CLEAR, PROFESSIONAL and IMMEDIATELY ACTIONABLE TRADING ANALYSIS.

        Think like a trader, but express yourself like a teacher.

        MANDATORY OUTPUT STRUCTURE:

        🔎 Quick market read
        🧱 Market structure
        📍 Key zones
        📈 Trend & Momentum
        🕯️ Patterns & Candlesticks
        📊 Indicators
        🧭 Multi-Timeframe reading\(isMulti ? " (DETAILED CROSS-REFERENCE of each provided TF)" : "")
        🎯 Trade plan\(isMulti ? " (ENRICHED with R:R and reversal zones)" : "")
        🧠 Market psychology\(isMulti ? "\n🔗 Inter-TF Confluences\n⚠️ Identified risks\n🔄 Alternative scenario" : "")

        RULES:
        - No visual description
        - No generic phrases
        - Short, clear, actionable sentences
        - Respond ONLY in English\(isMulti ? "\n- SYSTEMATICALLY cross-reference information between different TFs" : "")

        SYMBOL DETECTION:
        If you clearly identify the asset (e.g. BTC/USDT, ETH/USDT, SOL/USDT...), return its Binance symbol without slash (e.g. "BTCUSDT").
        If it's a stock, forex, or you cannot identify the asset with certainty, return null.

        Respond STRICTLY in the following JSON format, without any text before or after:

        {
          "symbol": "BTCUSDT",
          "resume": "",
          "structure": "",
          "zones": "",
          "momentum": "",
          "patterns": "",
          "indicateurs": "",
          "mtf": "",
          "plan": {
            "biais": "",
            "entree": "",
            "stop": "",
            "objectifs": "",
            "confirmation": "",
            "invalidation": ""\(isMulti ? ",\n    \"rr\": \"\",\n    \"zones_retournement\": \"\"" : ",\n    \"rr\": null,\n    \"zones_retournement\": null")
          },
          "psychologie": ""\(isMulti ? ",\n  \"confluences\": \"\",\n  \"risques\": \"\",\n  \"scenario_alternatif\": \"\"" : ",\n  \"confluences\": null,\n  \"risques\": null,\n  \"scenario_alternatif\": null")
        }
        """
        
        let system = "You are a professional trader expert. Respond ONLY in English and in valid JSON, without any text before or after. The JSON must be valid and start with '{' and end with '}'.\(isMulti ? " You receive multiple images from different timeframes — cross-reference analyses for enriched results." : "")"
        
        return (prompt, system)
    }
}

// MARK: - Image Helpers

extension OpenAIChartAnalyzer {
    /// Redimensionne une image si elle dépasse maxDimension en largeur ou hauteur
    static func resizeIfNeeded(_ image: UIImage, maxDimension: CGFloat = 1024) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - JSON Parser

extension OpenAIChartAnalyzer {

    /// Extraction robuste du JSON depuis la réponse GPT
    /// Gère : ```json ... ```, texte avant {, réponses partielles
    static func parseChartAnalysis(from response: String, isMulti: Bool) throws -> ChartAnalysis {
        var text = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Retirer les blocs de code markdown
        if text.hasPrefix("```json") { text = String(text.dropFirst(7)) }
        else if text.hasPrefix("```")  { text = String(text.dropFirst(3)) }
        if text.hasSuffix("```")       { text = String(text.dropLast(3)) }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 2. Extraire uniquement le bloc JSON (de { à })
        if let jsonStart = text.firstIndex(of: "{"),
           let jsonEnd   = text.lastIndex(of:  "}") {
            text = String(text[jsonStart...jsonEnd])
        }

        guard let data = text.data(using: .utf8) else {
            throw ChartAnalysisError.invalidJSON
        }

        do {
            let analysis = try JSONDecoder().decode(ChartAnalysis.self, from: data)
            print("✅ [OpenAIChartAnalyzer] Decoded OK (multi: \(isMulti))")
            return analysis
        } catch {
            print("❌ [OpenAIChartAnalyzer] JSON decode error: \(error)")
            print("❌ Raw JSON (first 500 chars): \(text.prefix(500))")
            throw ChartAnalysisError.decodingError(error)
        }
    }
}

enum ChartAnalysisError: LocalizedError {
    case invalidImage
    case invalidResponse
    case httpError(Int)
    case emptyContent
    case invalidJSON
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Impossible de traiter l'image."
        case .invalidResponse:
            return "Réponse invalide du serveur."
        case .httpError(let code):
            return "Erreur HTTP: \(code)"
        case .emptyContent:
            return "Réponse vide du serveur."
        case .invalidJSON:
            return "Format JSON invalide."
        case .decodingError(let error):
            return "Erreur de décodage: \(error.localizedDescription)"
        }
    }
}
