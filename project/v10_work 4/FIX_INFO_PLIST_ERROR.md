# Correction de l'erreur "Multiple commands produce Info.plist"

## Problème

L'erreur indique que `ShareExtension/Info.plist` est inclus dans le target principal alors qu'il ne devrait être que dans le target de l'extension.

## Solution

J'ai renommé le fichier en `ShareExtension-Info.plist` pour éviter le conflit avec le `Info.plist` généré automatiquement par Xcode.

### Étapes dans Xcode

1. **Ouvrir Xcode**

2. **Supprimer l'ancien fichier du projet** (si présent) :
   - Dans le navigateur de projet, trouvez `ShareExtension/Info.plist`
   - Clic droit → **Delete**
   - Choisissez **Remove Reference** (ne pas supprimer du disque)

3. **Ajouter le nouveau fichier** :
   - Clic droit sur le dossier `ShareExtension`
   - **Add Files to "Journal de trading 2025"...**
   - Sélectionnez `ShareExtension-Info.plist`
   - **Important** :
     - ✅ Cocher "Copy items if needed"
     - ✅ Cocher **UNIQUEMENT** le target "TradeMindSetShareExtension"
     - ❌ **Décocher** le target principal "TradeMindSet"
   - Cliquez **Add**

4. **Configurer le target Share Extension** :
   - Sélectionnez le target "TradeMindSetShareExtension"
   - Onglet **Build Settings**
   - Recherchez "Info.plist File" ou "INFOPLIST_FILE"
   - Définissez la valeur : `ShareExtension/ShareExtension-Info.plist`
   - (Ou le chemin relatif correct selon votre structure)

5. **Vérifier Target Membership** :
   - Sélectionnez `ShareExtension-Info.plist`
   - File Inspector → **Target Membership**
   - ✅ **Uniquement** "TradeMindSetShareExtension"
   - ❌ **Pas** le target principal

6. **Nettoyer et rebuilder** :
   - **Product → Clean Build Folder** (⇧⌘K)
   - **Product → Build** (⌘B)

## Alternative : Utiliser le nom Info.plist

Si vous préférez garder le nom `Info.plist`, vous devez absolument :

1. S'assurer qu'il n'est **PAS** dans le target principal
2. Dans le target Share Extension, Build Settings → **INFOPLIST_FILE** doit pointer vers `ShareExtension/Info.plist`
3. Vérifier que le fichier n'est pas dans "Copy Bundle Resources" du target principal

## Vérification

Après ces étapes, l'erreur devrait disparaître. Si elle persiste :

1. Vérifiez **Build Phases → Copy Bundle Resources** du target principal
2. Supprimez tout fichier `Info.plist` de l'extension s'il y est
3. Vérifiez que `ShareExtension-Info.plist` est uniquement dans le target de l'extension
