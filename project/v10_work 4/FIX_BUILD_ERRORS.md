# Correction des erreurs de build Xcode

## Problème

Erreurs "Multiple commands produce" pour :
- `Info.plist`
- `README.md`

## Solution

Ces fichiers du dossier `ShareExtension/` sont inclus dans le target principal alors qu'ils ne devraient être que dans le target de l'extension.

### Étapes de correction dans Xcode

1. **Ouvrir Xcode**

2. **Pour `ShareExtension/Info.plist`** :
   - Sélectionnez le fichier dans le navigateur de projet
   - Dans le **File Inspector** (panneau de droite)
   - Onglet **Target Membership**
   - **Décochez** le target principal "TradeMindSet" (ou "Journal de trading 2025")
   - **Cochez uniquement** le target "TradeMindSetShareExtension"

3. **Pour `ShareViewController.swift`** :
   - Même procédure
   - **Décochez** le target principal
   - **Cochez uniquement** le target "TradeMindSetShareExtension"

4. **Pour `SharedImageService.swift`** :
   - Ce fichier DOIT être dans les DEUX targets (app principale ET extension)
   - **Cochez les deux targets**

5. **Nettoyer le build** :
   - Dans Xcode : **Product > Clean Build Folder** (⇧⌘K)
   - Puis rebuild : **Product > Build** (⌘B)

### Alternative : Vérifier les Build Phases

1. Sélectionnez le target principal "TradeMindSet"
2. Onglet **Build Phases**
3. Section **Copy Bundle Resources**
4. Si `ShareExtension/Info.plist` ou `ShareExtension/README.md` y sont présents, **supprimez-les**

5. Répétez pour le target "TradeMindSetShareExtension" et vérifiez que ces fichiers y sont bien présents

## Note

Le fichier `README.md` a été déplacé à la racine du projet (`SHARE_EXTENSION_README.md`) car c'est de la documentation et ne doit pas être dans le bundle de l'app.
