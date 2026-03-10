# Analyse du Problème - Trades Ne S'Affichent Pas

## 🔍 Points de Vérification Identifiés

### 1. TradesView - Filtres Potentiels
- `filteredTrades` dépend de `appState.trades`
- Plusieurs filtres peuvent exclure les trades :
  - `searchText` (recherche par symbole)
  - `selectedSystem` (filtre par système)
  - `filters.apply(to:)` (filtres avancés)

### 2. Flux d'Ajout de Trade
1. `AddTradeView.saveTrade()` → `appState.addTrade(trade)`
2. `addTrade()` ajoute à `appState.trades` (ligne 1759)
3. `objectWillChange.send()` pour notifier SwiftUI (ligne 1765)
4. Sauvegarde SQLite en arrière-plan

### 3. Problèmes Potentiels
- `loadDataFromStores()` pourrait écraser les trades après ajout
- Les filtres dans `TradesView` pourraient exclure tous les trades
- `TradesView` pourrait ne pas observer correctement `appState.trades`

