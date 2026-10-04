# À relire AVANT de publier le jeu

Liste de contrôle du chantier « mode hybride » (branche `hybride`). **Tant que `hybride` n'est
pas fusionnée et que cette liste n'est pas relue, on ne publie pas.** Chaque ligne dit ce qui a
été testé ou non : « testé » veut dire qu'un test a vraiment été fait (dans Studio, DataStore de test).

## 1. Sauvegarde : risques acceptés (à relire)

| # | Risque | Ce qui se passe | Testé ? |
|---|---|---|---|
| 5 | Cadeau donné, puis sauvegarde ratée | Le cadeau (20 fraises) est redonné à la partie suivante. Pas en double : les fraises de la partie ratée sont perdues avec elle | Oui (panne simulée « Sauvegarde ») |
| 6 | Le même joueur sur deux serveurs presque en même temps | Le 2e serveur charge une sauvegarde périmée (pas de verrou de session). Ce risque existait déjà avant le mode hybride | **Non** (impossible dans Studio) |
| 7 | Deux écritures rapprochées sur la même case | Roblox les met en file d'attente (vu : jusqu'à 13 s de retard). Si le serveur s'éteint avant, l'écriture peut se perdre | Vu en partie, **pas** le cas « serveur éteint » |
| 9 | La sauvegarde ne peut pas être lue | Le joueur joue sans être sauvegardé ; un message doux le lui dit et propose de se reconnecter ; sa sauvegarde n'est pas touchée | Oui (panne simulée « Chargement ») |

## 2. À faire avant la publication

- [ ] **Exporter sa vraie sauvegarde** (`tools/exporter_sauvegarde_une_ligne.lua`, barre de commande de Studio) avant la
      1re partie normale sur la branche `hybride` : elle passera alors en version 6.
- [ ] **Remettre `Reglages.HYBRIDE_ACTIF` au bon état** avant la fusion (il est à `true` sur la branche pour les essais).
      Décider si le jeu publié l'a à `true` ou `false`.
- [ ] **Garde-fou de Studio** (`DATASTORE_STUDIO_PAR_DEFAUT = "Test_Hybride"` dans `Sauvegarde.luau`) : décider à la
      fusion si on le garde. Il ne change rien au jeu publié, mais dans Studio la vraie sauvegarde n'est utilisée qu'avec
      l'attribut `UtiliserVraieSauvegarde = true`.
- [ ] **Lieu de test séparé** : la règle « l'attribut `DataStoreTest` est ignoré hors de Studio » n'a été prouvée que
      par un test de la fonction (faux « pas dans Studio »). La seule preuve complète serait un lieu de test publié à part.
      Aucun n'a été publié (décision de l'utilisateur).
- [ ] **Prix** : `Reglages.Hybride.MultiplicateurPrix` (×1,8 sur 3 achats) est un réglage de départ **calculé**. À revoir
      après des parties chronométrées (cible : zone 1 en ≈ 4,5 min pour un joueur actif).
- [ ] **Musique d'ambiance** : l'emplacement `MusiqueAmbiance` est vide. Tout son ou musique ajouté doit avoir une
      **origine et une licence notées** (licence libre, compatible avec un jeu Roblox).
- [ ] **Sons** : aujourd'hui, uniquement le « ping » fourni avec Roblox (`rbxasset://sounds/electronicpingshort.wav`).
- [ ] **Clé API Open Cloud** (fichier personnel, hors du projet) : elle a des droits d'**écriture** sur les fichiers, les
      Game Passes et les Developer Products. La limiter à la lecture seule, ou la désactiver, sur create.roblox.com si
      elle ne sert pas. Elle n'est utilisée par **aucun** script du jeu.
- [ ] Retirer les attributs de test de `ServerStorage` s'il en reste (`DataStoreTest`, `PanneauDebug`,
      `SimulerPanne`, `UtiliserVraieSauvegarde`, `TestSansSauvegarde`). Hors de Studio, ils sont ignorés.
- [ ] Enregistrer la place dans Studio (Ctrl+S) et en garder une copie de secours : `Workspace/Monde`,
      `ServerStorage/ModelesRecolte` et le décor n'existent que dans Studio (reconstruction : `tools/construire_verger.lua`).

## 3. Pas testé (à vérifier par l'utilisateur ou plus tard)

- Le vrai jeu publié (tout a été testé dans Studio).
- Plusieurs vrais joueurs en même temps (la connexion Studio ne lance qu'un joueur).
- L'émulateur de téléphone (ne se pilote pas par script) : tailles calculées, pas vues sur un vrai téléphone.
- Un plantage d'une autre partie du démarrage que les ingrédients (par exemple la production elle-même).
- Voir aussi la section « pas testé » de chaque étape dans `docs/design_hybride.md` et le rapport final du chantier.
