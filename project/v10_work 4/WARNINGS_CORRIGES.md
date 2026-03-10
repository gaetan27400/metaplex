# Warnings Corrigés

## ✅ Corrections Appliquées

### 1. OpenTradesManager - Variable `previousPnL` non utilisée
**Fichier** : `Services/OpenTradesManager.swift`
**Ligne** : 75
**Correction** : Suppression de la variable `previousPnL` qui n'était jamais utilisée après sa déclaration.

### 2. SocialVerificationView - Variable `code` non utilisée
**Fichier** : `Views/Social/SocialVerificationView.swift`
**Ligne** : 348
**Correction** : Remplacement de `let code: String` par `_ =` pour ignorer la valeur retournée par les fonctions OAuth.

### 3. SocialVerificationView - Color non-optionnel avec `??`
**Fichier** : `Views/Social/SocialVerificationView.swift`
**Lignes** : 388, 397
**Correction** : Suppression de `?? AppColors.primary` car `Color(hex:)` retourne un `Color` non-optionnel.

### 4. Models.swift - `MoodStore` doit être `any MoodStore`
**Fichier** : `Models.swift`
**Ligne** : 1002
**Correction** : Changement du type de retour de `createMoodStore()` de `MoodStore` à `any MoodStore`.

## 🔍 Relation avec le Problème des Trades

**Ces warnings ne sont PAS liés au problème des trades qui ne s'ajoutent pas.**

Les warnings corrigés concernent :
- Des variables non utilisées (ne causent pas de bugs fonctionnels)
- Des types de protocoles (ne causent pas de problèmes d'exécution)
- Des opérateurs nil-coalescing inutiles (ne causent pas de problèmes fonctionnels)

Le problème des trades qui ne s'ajoutent pas est lié à :
- La synchronisation entre `appState.trades` et SQLite
- Les filtres dans `TradesView` qui peuvent exclure les trades
- Le timing entre `addTrade()` et `loadDataFromStores()`

**Les logs de diagnostic ajoutés précédemment permettront d'identifier le problème exact.**

