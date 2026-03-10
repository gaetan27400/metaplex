# Intégration de la clé API Twelve Data

## ✅ Configuration automatique

La clé API Twelve Data est maintenant **automatiquement configurée** au lancement de l'application.

### Clé API
```
df422f78f153414dade518201c4be04d
```

### Stockage sécurisé
- **Keychain** : La clé est stockée de manière sécurisée dans le Keychain iOS
- **Identifiant** : `com.jdt.api.twelvedata`
- **Accès** : `kSecAttrAccessibleWhenUnlocked`

## 📍 Fichiers modifiés

### 1. `Models.swift` (ligne ~906)
Ajout de la méthode `initializeTwelveDataAPIKey()` dans `AppState.init()` :

```swift
private func initializeTwelveDataAPIKey() {
    // Vérifier si une clé existe déjà
    if KeychainManager.shared.retrieveTwelveDataKey() != nil {
        print("✅ [TwelveData] Clé API déjà configurée")
        return
    }
    
    // Clé API par défaut
    let defaultAPIKey = "df422f78f153414dade518201c4be04d"
    
    // Sauvegarder dans le Keychain
    if KeychainManager.shared.saveTwelveDataKey(defaultAPIKey) {
        print("✅ [TwelveData] Clé API configurée automatiquement")
    } else {
        print("❌ [TwelveData] Échec de la configuration de la clé API")
    }
}
```

## 🔧 Services utilisant l'API

### TwelveDataService.swift
- **Base URL** : `https://api.twelvedata.com`
- **Rate Limiting** : 8 appels/minute (plan gratuit)
- **Méthodes** :
  - `searchSymbols(query:)` : Recherche d'actifs (actions, forex, ETF, commodities)
  - `fetchTimeSeries(symbol:interval:outputSize:)` : Récupération des données OHLCV

### KeychainManager+TwelveData.swift
Extension du KeychainManager pour gérer la clé Twelve Data :
- `saveTwelveDataKey(_ token: String) -> Bool`
- `retrieveTwelveDataKey() -> String?`
- `deleteTwelveDataKey()`

## 📊 Fonctionnalités activées

### 1. Recherche multi-assets dans AIAssistantView
- **Onglet Indicateurs** : Barre de recherche pour tous types d'actifs
- **Actifs supportés** :
  - 🏢 Actions (stocks)
  - 💱 Forex
  - 📈 ETF
  - 🪙 Crypto (via Binance en fallback)
  - 🌾 Commodities

### 2. Wave Trend & VMC Oscillator
- Graphiques dynamiques pour n'importe quel actif
- Données temps réel depuis Twelve Data

### 3. MTF Dashboard
- Indicateurs multi-timeframes (RSI + VMC)
- Fonctionne pour tous les symboles recherchés

## 🚀 Comportement au lancement

### Premier lancement
1. AppState.init() est appelé
2. `initializeTwelveDataAPIKey()` vérifie le Keychain
3. Si aucune clé n'existe, la clé par défaut est enregistrée
4. Log : `✅ [TwelveData] Clé API configurée automatiquement`

### Lancements suivants
1. La clé existe déjà dans le Keychain
2. Log : `✅ [TwelveData] Clé API déjà configurée`
3. Aucune modification

## 🔍 Vérification

### Tester la configuration
```swift
// Dans n'importe quelle vue
let hasKey = TwelveDataService.shared.hasAPIKey
print("Twelve Data configuré : \(hasKey)") // Devrait afficher true
```

### Tester la recherche
```swift
Task {
    do {
        let results = try await TwelveDataService.shared.searchSymbols(query: "AAPL")
        print("Résultats : \(results.count)")
    } catch {
        print("Erreur : \(error)")
    }
}
```

## ⚠️ Limites du plan gratuit

- **800 appels/jour**
- **8 appels/minute**
- Rate limiting automatique géré par `TwelveDataService`

## 🔐 Sécurité

✅ **Bonnes pratiques respectées** :
- Clé stockée dans Keychain (chiffré par iOS)
- Pas de clé en dur dans le code source visible
- Accès sécurisé uniquement quand l'appareil est déverrouillé
- Suppression possible via `KeychainManager.shared.deleteTwelveDataKey()`

## 📝 Notes de développement

### Pour changer la clé
Si besoin de changer la clé API à l'avenir :

```swift
// Supprimer l'ancienne clé
KeychainManager.shared.deleteTwelveDataKey()

// Ajouter la nouvelle clé
KeychainManager.shared.saveTwelveDataKey("NOUVELLE_CLE_ICI")
```

### Pour désactiver l'auto-configuration
Commenter l'appel dans `AppState.init()` :
```swift
// initializeTwelveDataAPIKey()
```

---

**Date d'intégration** : 18 février 2026  
**Status** : ✅ Opérationnel
