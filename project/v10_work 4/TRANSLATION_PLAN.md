# Plan de Traduction Automatique - TradeMindSet

## Objectif

Implémenter un système de traduction automatique pour :
1. Tous les éléments de l'interface (titres, labels, messages)
2. Tous les résultats générés par l'IA (analyses, recommandations, rapports)
3. Basé sur la langue sélectionnée dans le dashboard (FR/EN)

## Architecture

```
LanguageManager (service centralisé)
    ↓
Localizable (dictionnaire de traductions)
    ↓
Vues SwiftUI (utilisation de Localizable.text())
    ↓
Services IA (paramètre de langue dans les prompts)
```

## Étapes d'implémentation

### 1. Créer LanguageManager

**Fichier à créer :** `Utils/LanguageManager.swift`

Service centralisé pour obtenir la langue actuelle depuis AppStorage.

```swift
final class LanguageManager {
    static let shared = LanguageManager()
    @AppStorage("selectedLanguage") private var selectedLanguage: String = "fr"
    
    var currentLanguage: Localizable.Language {
        Localizable.Language(rawValue: selectedLanguage) ?? .french
    }
}
```

### 2. Étendre Localizable

**Fichier à modifier :** `Models.swift` (section Localizable)

Ajouter toutes les traductions manquantes pour :
- Titres de navigation (Dashboard, Systèmes, Trades, IA)
- Messages et labels dans les vues
- Textes des sections (Métriques, Analyses, etc.)
- Messages d'erreur et de succès
- Jours de la semaine
- Textes des menus

### 3. Modifier les Services IA

#### 3.1 OpenAIChartAnalyzer

**Fichier à modifier :** `Services/API/OpenAIChartAnalyzer.swift`

- Ajouter paramètre `language: Localizable.Language` à `analyzeChart()`
- Modifier le prompt système pour demander la langue :
  - FR : "Réponds UNIQUEMENT en français..."
  - EN : "Respond ONLY in English..."

#### 3.2 OpenAIClient

**Fichier à modifier :** `Services/API/OpenAIClient.swift`

- Ajouter paramètre `language` à `analyze()` et `analyzeMarket()`
- Modifier les prompts système selon la langue

#### 3.3 AIChatService

**Fichier à modifier :** `Services/AIChatService.swift`

- Ajouter paramètre `language` aux méthodes de chat
- Modifier le prompt système du coach selon la langue

#### 3.4 AssistantAIService

**Fichier à modifier :** `Services/AI/AssistantAIService.swift`

- Ajouter paramètre `language` à `makeDailyReport()` et méthodes génératrices
- Traduire les textes générés (headlines, sections, recommandations)

### 4. Traduire les Vues

#### 4.1 TradingJournalApp - CustomBottomBar

**Fichier à modifier :** `Models.swift` (TradingJournalApp)

- Remplacer "Dashboard", "Systèmes", "Trades", "IA" par `Localizable.text()`
- Utiliser `LanguageManager.shared.currentLanguage`

#### 4.2 EnhancedDashboardView

**Fichier à modifier :** `Models.swift` (EnhancedDashboardView)

- Traduire tous les textes statiques :
  - "Performance par Jour"
  - "Lundi → Dimanche"
  - "Métriques avancées"
  - "Analyses avancées"
  - "Émotions"
  - "Heatmap"
  - "Aperçu (4 semaines)"
  - Jours de la semaine (Lun, Mar, Mer, etc.)
  - Tous les labels et messages

#### 4.3 AIAssistantView

**Fichier à modifier :** `Views/AI/AIAssistantView.swift`

- Traduire les titres des onglets (Insights, Conseils, Analyse, etc.)
- Traduire les messages et labels
- Passer la langue aux services IA

#### 4.4 PhotoAnalysisView

**Fichier à modifier :** `Views/AI/PhotoAnalysisView.swift`

- Traduire les titres des cartes d'analyse
- Passer la langue à `OpenAIChartAnalyzer`

#### 4.5 Autres vues

- SystemsView (déjà partiellement traduit)
- TradesView
- AddTradeView
- Toutes les autres vues avec textes statiques

### 5. Mise à jour des Appels aux Services IA

Tous les appels aux services IA doivent passer la langue :

```swift
let language = LanguageManager.shared.currentLanguage
let analysis = try await analyzer.analyzeChart(image, language: language)
```

## Fichiers à créer

1. `Utils/LanguageManager.swift` - Service centralisé pour la langue

## Fichiers à modifier

### Services IA
1. `Services/API/OpenAIChartAnalyzer.swift`
2. `Services/API/OpenAIClient.swift`
3. `Services/AIChatService.swift`
4. `Services/AI/AssistantAIService.swift`

### Vues principales
1. `Models.swift` (TradingJournalApp, EnhancedDashboardView)
2. `Views/AI/AIAssistantView.swift`
3. `Views/AI/PhotoAnalysisView.swift`
4. `Views/Systems/SystemsView.swift` (compléter)
5. Autres vues avec textes statiques

### Modèles
1. `Models.swift` (extension Localizable)

## Points d'attention

- **Cohérence** : Utiliser toujours `LanguageManager.shared.currentLanguage` pour obtenir la langue
- **Prompts IA** : Toujours demander explicitement la langue dans les prompts système
- **Textes statiques** : Remplacer tous les textes en dur par `Localizable.text(key, language: language)`
- **Tests** : Vérifier que le changement de langue fonctionne dans toutes les vues
- **Performance** : Les traductions sont en mémoire, pas d'impact sur les performances

## Ordre d'implémentation recommandé

1. Créer `LanguageManager`
2. Étendre `Localizable` avec toutes les traductions
3. Modifier les services IA (ajouter paramètre langue)
4. Traduire les vues principales (Dashboard, IA, Navigation)
5. Traduire les autres vues
6. Tester le changement de langue
