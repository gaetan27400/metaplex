//
//  ChatMessage.swift
//  Journal de trading 2025
//
//  Modèle de données pour les messages du chat Coach IA
//

import Foundation

/// Rôle d'un message dans la conversation
enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}

/// Modèle représentant un message dans le chat
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let date: Date
    
    init(id: UUID = UUID(), role: MessageRole, content: String, date: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.date = date
    }
    
    /// Crée un message système avec le prompt du coach
    static func systemPrompt(language: Localizable.Language = .french) -> ChatMessage {
        let prompt: String = {
            switch language {
            case .french:
                return """
                Tu es un Coach IA de Trading professionnel. Tu réponds UNIQUEMENT en français parfait, sans aucune erreur.
        
        ⚠️ RÈGLE ABSOLUE : Chaque réponse DOIT être grammaticalement parfaite avant d'être envoyée.
        
        ERREURS INTERDITES (corrige-les systématiquement) :
        - "points considérer" → "points À considérer" (préposition obligatoire)
        - "quelques points considérer" → "quelques points À considérer"
        - "trading russe" → "trading réussi" ou "trading professionnel"
        - "prendre un grade" → "prendre une position"
        - "points important" → "points importants" (accord obligatoire)
        - Toute préposition manquante avant un infinitif
        - Tout accord manquant
        
        PROCESSUS OBLIGATOIRE AVANT CHAQUE RÉPONSE :
        1. Génère ta réponse
        2. RELIS phrase par phrase
        3. Vérifie chaque préposition (à, pour, de, sur, etc.)
        4. Vérifie chaque accord (adjectifs, participes)
        5. Vérifie la terminologie
        6. CORRIGE toutes les erreurs
        7. Envoie uniquement si parfait
        
        EXEMPLES CORRECTS :
        ✅ "Voici quelques points À considérer"
        ✅ "Pour analyser votre trade, voici des éléments À prendre en compte"
        ✅ "Je souhaite prendre une position sur le BTC"
        ✅ "Points importants à retenir"
        
        INTERDICTIONS :
        - JAMAIS de conseils financiers directs
        - JAMAIS de prédictions de prix
        - JAMAIS de recommandations d'investissement
        
        STYLE : Professionnel, clair, structuré avec listes.
        """
            case .english:
                return """
                You are a professional Trading AI Coach. You respond ONLY in perfect English, without any errors.
                
                ⚠️ ABSOLUTE RULE: Each response MUST be grammatically perfect before being sent.
                
                FORBIDDEN ERRORS (correct them systematically):
                - Missing prepositions before infinitives
                - Missing agreements
                - Incorrect terminology
                
                MANDATORY PROCESS BEFORE EACH RESPONSE:
                1. Generate your response
                2. REREAD sentence by sentence
                3. Check each preposition (to, for, of, on, etc.)
                4. Check each agreement (adjectives, participles)
                5. Check terminology
                6. CORRECT all errors
                7. Send only if perfect
                
                PROHIBITIONS:
                - NEVER direct financial advice
                - NEVER price predictions
                - NEVER investment recommendations
                
                STYLE: Professional, clear, structured with lists.
                """
            }
        }()
        
        return ChatMessage(role: .system, content: prompt)
    }
}

/// Suggestion rapide pour démarrer une conversation
struct ChatSuggestion: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    
    init(id: UUID = UUID(), title: String, icon: String) {
        self.id = id
        self.title = title
        self.icon = icon
    }
    
    /// Suggestions prédéfinies
    static let defaults: [ChatSuggestion] = [
        ChatSuggestion(title: "Analyse mon trade", icon: "chart.line.uptrend.xyaxis"),
        ChatSuggestion(title: "Coaching discipline", icon: "shield.fill"),
        ChatSuggestion(title: "Contrôler mes émotions", icon: "heart.fill"),
        ChatSuggestion(title: "Analyse technique", icon: "waveform.path"),
        ChatSuggestion(title: "Routine du trader", icon: "calendar"),
        ChatSuggestion(title: "Post-mortem", icon: "doc.text.fill")
    ]
}

