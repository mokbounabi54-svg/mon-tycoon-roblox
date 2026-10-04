# Mode hybride : récolte d'ingrédients + usine (PLAN, version 3.1 : l'archipel)

> **Statut : plan, version 3.1 du 2026-10-04 (décisions finales de l'utilisateur).** Branche `hybride`,
> créée depuis `nuit-auto` (`a0953ab`).
>
> **Autorisé** : étapes 0, 1 et 2. Pour les tests, des objets **temporaires** dans `Workspace/TestHybride`,
> supprimés à la fin de chaque test.
>
> **Interdit** :
> - l'étape 3 (construction du monde) ;
> - monétisation, Halloween, récompense quotidienne ;
> - toute clé API (le fichier `bill.txt` ne doit jamais être ouvert) ;
> - tout commit sans le mot « commit » de l'utilisateur ;
> - toute fusion dans `main` ;
> - toute lecture, écriture ou suppression de `Joueurs_v2`.
>
> En cas de conflit entre ce plan et le message de décisions finales, **le message l'emporte**.

## Décisions finales (v3.1)

| | Décision |
|---|---|
| a | **Murs de l'est** : `MurEst`, la falaise (277, 0) **et les 2 falaises voisines** (Z = ±55,7) rangés dans `Decor_Anciens` ; 2 morceaux de mur avec 14 studs d'ouverture. Aucune autre falaise touchée. |
| b | **Mer** : fond de mer solide en sable sous une surface d'eau décorative **sans collision** ; pentes de sable pour remonter ; murs invisibles loin au large ; **rambardes du pont décoratives, sans collision**. **Pas d'eau en Terrain** (pas de nage). On ne doit ni se coincer, ni mourir, ni sortir de la carte. « Rentrer » marche de n'importe où. (Étape 3, pas encore autorisée.) |
| c | **Règle E**, affichée : « Mélangeur 1 : tranquille ×0,5 / gourmand ×2 ; Mélangeur 2 : ×1 / gourmand ×2 ». |
| d | **`Reglages.Hybride.MultiplicateurPrix`**, seulement si `HYBRIDE_ACTIF` : Cuiseur1 = 1, Mouleur1 = 1, Emballeuse1 = 1,8, Melangeur1B = 1,8, Zone2 = 1,8. Aucun autre prix ne change. |
| e | **Fraisier doré** : décrit, pas construit ; bonus de **+5 à +8 % de revenu en moyenne** (section k). |
| f | **Cadeau de 20 fraises**, pour tous les comptes, une seule fois. |
| g | **Ton** : doux, gourmand, relaxant ; aucun minuteur qui presse ; aucune perte punitive ; aucun texte culpabilisant ; sons courts et doux ; volumes dans `Theme.Sons` ; `MusiqueAmbiance` vide + bouton pour la couper. Aucun son ni musique importé sans en donner l'origine et la licence. |

## Protection de la vraie sauvegarde (`Joueurs_v2`)

- **Avant chaque partie de test** : je vérifie que `ServerStorage.DataStoreTest = "Test_Hybride"`.
  **Après le lancement** : je vérifie dans la sortie que le jeu utilise bien ce DataStore. Sinon, je ne lance pas.
- Je ne lis, n'écris et ne supprime **jamais** `Joueurs_v2`.
- **`tools/exporter_sauvegarde.lua`** : un script en **lecture seule**, à coller dans la barre de commande
  de Studio, qui affiche ta sauvegarde en texte et la liste des anciennes versions. **C'est toi qui le
  lances**, avant ta 1re partie normale (celle qui fera passer ta sauvegarde en version 6).
- **Anciennes versions** : Roblox garde **chaque version d'une clé pendant 30 jours** (DataStores standards).
  - Pour les lister : `DataStore:ListVersionsAsync(clé)`. Pour en lire une : `DataStore:GetVersionAsync(clé, version)`.
  - Pour revenir en arrière, il faut relire l'ancienne version puis la **réécrire** avec `SetAsync`.
    C'est une écriture dans la vraie sauvegarde : je ne la ferai jamais sans ta demande.
  - Les versions se consultent aussi sur le site du Créateur (Creator Hub → ton jeu → Data Stores),
    selon ce que Roblox propose pour ton compte (non vérifié).
- **À la fin de chaque étape**, je remets en état et je le contrôle :
  - `DataStoreTest` vide ;
  - `HYBRIDE_ACTIF = false` ;
  - dossier `Workspace/TestHybride` supprimé.

### « Le DataStore de test ne marche que dans Studio » : ce qu'on peut vraiment tester

Dans Studio, Roblox répond **toujours** « oui » à `RunService:IsStudio()` : il est impossible d'y simuler
le jeu publié. Voici ce que je peux faire, du plus faible au plus fort :
1. **Lecture du code** (déjà vrai) : `choisirDataStore` n'utilise l'attribut que si `RunService:IsStudio()` est vrai.
2. **Test de la logique** (étape 1) : je sépare la décision dans une petite fonction qui reçoit
   « est-on dans Studio ? » en paramètre. Je l'appelle avec `false` et je vérifie qu'elle renvoie
   le vrai DataStore, même avec l'attribut posé. Ça teste la règle, mais pas le vrai Roblox publié.
3. **Test réel** (seul le jeu publié le peut) : publier sur un **lieu de test séparé** et regarder la sortie
   du serveur. **Décision : aucun lieu de test n'est publié.**

**Fait à l'étape 1** :
- `Sauvegarde.choisirNom(estStudio, …)` et `Sauvegarde.attributIgnore(estStudio, nomTest)` sont des fonctions pures.
- Dans le jeu publié, l'attribut `DataStoreTest` est **ignoré**, avec un `warn()` (une fois par serveur) s'il est posé.
- Les deux fonctions sont testées avec un faux « je ne suis pas dans Studio ».

**Cette preuve est partielle** : elle vérifie la règle écrite dans le code, mais pas le comportement du vrai
jeu publié (dans Studio, `RunService:IsStudio()` vaut toujours `true`).

### Garde-fou de la branche (ajouté après l'étape 1)
- **Dans Studio**, la sauvegarde utilisée par défaut est **`Test_Hybride`**.
  La vraie (`Joueurs_v2`) ne sert que si `ServerStorage.UtiliserVraieSauvegarde = true` (un vrai booléen).
  Un `warn` « ATTENTION : VRAIE sauvegarde » s'affiche alors.
- Si `DataStoreTest` désigne `Joueurs_v2`, il faut aussi l'autorisation, sinon c'est `Test_Hybride`.
- **Dans le jeu publié** : rien ne change, c'est toujours `Joueurs_v2`, et les attributs sont ignorés.
- Testé : 14 cas sur 14 avec le faux « pas dans Studio » ; une partie de Studio démarre normalement.
- **À décider à la fusion** : garder ou retirer ce comportement (constante `DATASTORE_STUDIO_PAR_DEFAUT`).

### Retour en arrière vers la version 5 (testé dans `Test_Hybride`)
1. Sauvegarde v6 → partie avec le code de `nuit-auto` (v5) → argent, achats, inventaire, seuil, carnet et les
   deux pitiés **conservés**. Mais le code v5 **retire le champ `Ingredients`** et remet `Version = 5`.
2. Retour au code v6 → la migration 5 → 6 recrée des ingrédients **vides**, avec `CadeauRecu = false`.
   Le panier et le bac sont **perdus**, et le cadeau serait **redonné**. Mesuré : panier 12 + bac 37 → 0.

### Le vrai retour en arrière : `HYBRIDE_ACTIF = false`
**Pour revenir en arrière, on ne remet pas un ancien code : on passe `Reglages.HYBRIDE_ACTIF` à `false`.**
Le jeu redevient celui d'avant (rythmes, prix, rien de plus à l'écran), et la sauvegarde garde ses ingrédients
pour plus tard. `nuit-auto` n'est pas modifiée : remettre son code ferait perdre les ingrédients (voir ci-dessus).

### Correctifs ajoutés avant l'étape 2 (testés dans `Test_Hybride`)
- **Le DataStore est choisi UNE SEULE FOIS, au démarrage du serveur**, pour le chargement et toutes les sauvegardes.
  - La sortie l'annonce : « DataStore choisi pour toute la partie : '…' ».
  - Mesuré : `UtiliserVraieSauvegarde = true` et `DataStoreTest = "Test_Hybride_B"` posés **en pleine partie** →
    la sauvegarde va quand même dans `Test_Hybride` ; `Test_Hybride_B` ne reçoit rien ; aucun avertissement « vraie sauvegarde ».
- **Compatibilité avec une version plus récente** :
  - la sauvegarde garde ses champs inconnus et ne baisse jamais son numéro de version ;
  - mesuré : une sauvegarde v7 avec `Quartiers` et `ChampFutur` est rechargée puis réécrite en **v7**,
    avec ses 2 champs intacts ;
  - limite : un champ inconnu **à l'intérieur** d'un champ connu (par exemple un nouveau sous-champ de `Ingredients`) n'est pas gardé.
- **Pannes simulées** : `server/PanneSimulee.luau`, attribut `SimulerPanne` = `Chargement`, `Sauvegarde` ou `Ingredients`.
  **Seulement dans Studio** (vérifié avec un faux « pas dans Studio » : jamais actif).

| Panne | Le joueur est-il sauvegardé ? | Perd-il sa progression ? | Message dans la sortie | Cadeau redonné à tort ? |
|---|---|---|---|---|
| Chargement (risque 9) | Non (voulu) | Celle de cette partie seulement ; l'ancienne sauvegarde est intacte | Oui : 3 essais ratés + « cette partie ne sera pas sauvegardée » | Non (pas de cadeau dans cette partie) |
| Sauvegarde (risque 10) | Non (3 essais ratés) | **Oui, celle de la partie** (mesuré : +1 000 $ perdus) ; l'ancienne sauvegarde est intacte | Oui : « ses derniers progrès sont perdus » | Redonné à la partie suivante, **mais pas en double** : celui de la partie ratée est perdu avec elle |
| Démarrage des ingrédients (risque 4) | Non | Celle de la partie (rien ne peut avancer) ; ancienne sauvegarde intacte | Oui : erreur avec la ligne exacte | Non |

**Problème vu au test du risque 4** : le joueur restait bloqué au Départ, avec une usine posée dont **toutes les
machines étaient visibles mais rien ne tournait**. **Corrigé** :
- `Parcelles` place d'abord le joueur dans son usine, puis démarre chaque partie séparément (`demarrerProtege`, avec `pcall`).
- Si l'une plante, le reste marche, le joueur n'est **pas sauvegardé** pendant cette partie, et l'attribut
  `PartieNonSauvegardee` (« Probleme » ou « Chargement ») prévient son écran.
- `client/AvisSauvegarde.luau` affiche un panneau doux et honnête (« ce que tu fais pendant cette partie ne sera pas
  enregistré », « reconnecte-toi »), puis un petit rappel discret en haut à droite.
- Testé (pannes « Ingredients » et « Chargement ») :
  - joueur à 0,4 stud de l'entrée de son usine ;
  - production qui tourne (bonbons vendus, caisse à 96 $ et à 24 $) ;
  - sauvegarde de test non écrasée ;
  - aucun message dans une partie normale.

### Risques acceptés, à relire avant la publication
- **Risque 5** : cadeau donné, puis sauvegarde ratée → cadeau redonné à la partie suivante (pas en double, voir ci-dessus).
- **Risque 6** : le même joueur sur deux serveurs presque en même temps → le 2e charge une sauvegarde périmée
  (il n'y a pas de verrou de session ; ce risque existait déjà avant le mode hybride).
- **Risque 7** : deux écritures rapprochées sur la même case → Roblox les met en file d'attente (vu : jusqu'à 13 s de retard) ;
  si le serveur s'éteint avant, l'écriture peut se perdre.
>
> **Légende des chiffres** : 🧮 = **calculé** (pas encore vérifié en jeu) · 📏 = **mesuré**.
> Aujourd'hui, **tous les chiffres de ce plan sont 🧮 calculés.** Rien n'a encore été mesuré en jeu.

**Décisions prises :**
- archipel (île + pont) ;
- règle E pour le 2e mélangeur, expliquée à l'écran ;
- quartier du prototype à l'est ;
- chiffres d'un tour gardés ;
- 20 fraises offertes une fois à tous ;
- `MultiplicateurPrix` (×1,8 sur 3 achats, seulement en mode hybride) ;
- ton doux ;
- aucune donnée de joueur collectée.

Les maquettes sont dans `docs/design/Archipel_Plan.dc.png` et `docs/design/Archipel_Ambiance.dc.png`
(pas dans un sous-dossier `archipel/`). Elles ne sont pas encore dans Git.

---

## a. État actuel (court)

- Branche `nuit-auto`. Rien en attente, sauf ce plan et tes 2 images de l'archipel (pas encore suivis par Git).
- Aucun bug connu. Pas de partie lancée (une partie normale lirait ET écrirait ta vraie sauvegarde).
- La production passe par une boucle par mélangeur (`Production.luau`). La sauvegarde est en version 5.
- La carte actuelle : intérieur de X -262 à 262 et de Z -195 à 195, avec un anneau de falaises et 4 murs invisibles.
  `Baseplate` de 512 × 512. Vitesse de marche : 16 studs/s.
- **Le StreamingEnabled est déjà activé.**

---

## b. La carte : l'archipel

### Cible à terme (PAS dans ce chantier)

D'après ta maquette :
- une île centrale (fontaine, statue, arrivée) ;
- **6 îlots d'usine en couronne**, à égale distance du centre, donc plus d'inégalité entre parcelles ;
- de grandes îles de récolte au loin, reliées par des ponts de bonbon ;
- une mer peu profonde qui ne tue pas, et une barrière invisible loin au large.

Ce qu'il faudra le jour venu (je le note pour ne pas l'oublier) :
- poser les parcelles **tournées de 60° en 60°** (aujourd'hui seulement 0° et 180°) ; c'est ce que vérifie le test b.1 ;
- refaire tout le décor (`docs/decor-carte.md`) ;
- probablement retirer l'anneau de falaises.

**Aucune parcelle ne bouge maintenant.**

### Prototype : l'Île du Verger, à l'est de la carte actuelle

```
   carte actuelle (inchangée)                          mer décorative (peu profonde)
 ┌──────────────────────────────┐
 │ P1        P2        P3       │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 │                              │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ╭───────────╮ ~
 │ Départ ── HUB ══•══•══•══•══•▐▓▓▓▓▓▓▓ PONT DE BONBON ▓▓▓▓▓▓▓▓▶│ ÎLE DU    │ ~
 │          (38,0)   buissons  ▐ (262,0)      188 studs   (450,0)│ VERGER    │ ~
 │                              │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ │ 8 arbres  │ ~
 │ P4        P5        P6       │ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ ╰───────────╯ ~
 └──────────────────────────────┘ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  centre (530,0)
   ▐ = ouverture de 14 studs dans le mur est (voir « désaccord 1 »)
```

| Élément | Où (coordonnées de la carte) | Détail |
|---|---|---|
| Sentier `VersVerger` | du bord de la place (38, 0) au bord est (262, 0) | caramel, largeur 10, 224 studs (comme les chemins actuels) |
| 5 buissons « en passant » | le long du sentier, X = 70, 110, 150, 190, 230, à 7 studs du bord | 1er buisson à ≈ 2 s du hub 🧮 |
| **Barrière de quartier** | à l'entrée du pont (266, 0), 12 de large | Part invisible `Barriere` (le verrou, voir plus bas) |
| **Pont de bonbon** | de (262, 0) à (450, 0) : **188 studs**, largeur 12 | tablier à rayures rose / blanc (un bloc tous les 6 studs) + 2 rambardes basses **décoratives, sans collision** (décision b) |
| **Île du Verger** | centre (530, 0), **rayon 80** (X de 450 à 610) | disque d'herbe (Ø 160) + anneau de sable (Ø 172), dessus à Y = 0,05 |
| 5 buissons sur l'île | 2 au bout du pont, 3 sur le sentier de l'île | |
| **8 arbres** | 2 arcs de 4, à partir de X ≈ 486 | 1er arbre à 36 studs du bout du pont |
| Mer décorative | plan d'eau de X 287 à ≈ 1 000, Z ± 450, à Y = -1,5 | bleu `#7FD3EE`, légèrement transparent, **sans collision**. **Pas d'eau en Terrain** (pas de nage) |
| Fond de la mer | à Y = -3,5, même taille, **en sable, avec collision** | on marche dans l'eau peu profonde, on ne tombe jamais dans le vide |
| Pentes de sable | 8 coins autour de l'île, au bout du pont et **le long du bord est de la carte** | pour remonter partout où l'on peut descendre : **on ne se coince nulle part** |
| Murs invisibles au large | 4 murs à ≈ 150 studs autour de l'île, hauteur 80 | on ne sort pas de la carte |
| Décor de l'île | 3 sucettes et 4 champignons (copies de `ModelesDecor`), au bord | sans collision |

### Trajets (16 studs/s, à pied, en coupant par l'herbe) 🧮

| Départ | Jusqu'au pont | Pont + rive → 1er arbre | **Total jusqu'au 1er arbre** | 1er buisson |
|---|---|---|---|---|
| **Bord du hub** | 224 | 224 | **448 studs = 28 s** ✅ (objectif ≈ 28 s) | 2 s |
| Parcelles 3 et 6 | 134 | 224 | 358 = **22 s** | ≈ 3 s |
| Parcelles 2 et 5 | 268 | 224 | 492 = **31 s** | ≈ 5 s |
| Parcelles 1 et 4 | ≈ 410 | 224 | 634 = **40 s** | ≈ 13 s |

L'écart entre P1 et P3 reste de 18 s. Il disparaîtra avec l'archipel complet (îlots en couronne).
D'ici là, l'effet sur l'argent est d'environ 5 % (tableau d) 🧮.

### Déplacements (rien n'est supprimé ; ancienne position notée dans `decor-carte.md`)

| Objet | Ce qui change |
|---|---|
| Falaise de l'anneau en (277, 0) | rangée dans `Decor_Anciens` (le pont passe à sa place) |
| **Les 2 falaises voisines** en (277, ±55,7) | rangées dans `Decor_Anciens` (décision a : dégager la vue vers l'île). Aucune autre falaise n'est touchée |
| `MurEst` (mur invisible en X = 264) | rangé dans `Decor_Anciens`, remplacé par **2 morceaux identiques** qui laissent 14 studs d'ouverture (Z de -7 à 7) pour le pont |
| Bord est, entre Z = -85 et 85 (là où étaient les 3 falaises) | les 2 morceaux de mur ferment déjà ce bord, sauf l'ouverture. L'herbe s'arrête net en X = 262 : il faut une **pente de sable** devant l'ouverture, pour qu'un joueur tombé dans l'eau à côté du pont puisse remonter |
| Arbre à barbe à papa en (230, 0) | déplacé en (230, -60) (il est sur le sentier) |
| Champignons | **rien** : ils ne gênent plus |

### Le verrou de quartier (prêt pour plus tard, ouvert dans le prototype)

- **Rangement** : `Workspace/Monde/Iles/Verger/`, avec les dossiers `Pont`, `Ile`, `Recolte`, `Decor`, `Mer`
  et la Part `Barriere`. Le dossier de l'île porte l'attribut `Quartier = "Verger"`.
- **Serveur (le vrai verrou)** : une récolte sur une île fermée pour ce joueur est refusée. Comme
  aujourd'hui la mer est franchissable à pied (voir le désaccord 2), **seul ce refus compte vraiment**.
- **Écran (le verrou visible)** : la `Barriere` devient solide pour ce joueur seulement.
  Ça marche parce que c'est son écran qui calcule les mouvements de son personnage.
- **Prototype** : `Reglages.Hybride.Quartiers.Verger.Ouvert = true`. Pas encore de champ de sauvegarde pour les îles ouvertes.

### Pièces ajoutées 🧮

| Quoi | Pièces |
|---|---|
| Pont (tablier 32 + rambardes 2 + poteaux 16) | ≈ 50 |
| 8 arbres × 8 | 64 |
| 10 buissons × 5 | 50 |
| Île (herbe, sable) + 8 pentes de plage | 10 |
| Mer + fond + 4 murs loin au large | 6 |
| Décor de l'île (3 sucettes × 4 + 4 champignons × 2) | 20 |
| Sentier + barrière + 2 morceaux de mur | 4 |
| **Monde : total** | **≈ 204** |
| Bacs (6 pièces × 6 parcelles occupées) | 36 |

---

## c. Une minute et demie de jeu (parcelle 2, un mélangeur) 🧮

**Ton du jeu** : pas de compte à rebours qui presse, pas de perte, pas de texte qui culpabilise.
Le « sac » devient le **panier**. Le rythme s'affiche « tranquille ×0,5 » ou « gourmand ×2 ».

| Temps | Action | Ce qui se passe |
|---|---|---|
| 0 s | Apparaît à l'entrée | Bac « 🍓 20 · Rythme gourmand ×2 ». Bulle : « Tes 20 fraises font tourner ton mélangeur deux fois plus vite ! » |
| 5 s | **Cueille** le 1er buisson | +2 🍓 (son doux) |
| 5-17 s | 4 autres buissons en passant | Panier ≈ 12. Bulle : « Le pont de bonbon mène à l'Île du Verger 🍓 » |
| 17 s | Monte sur le pont | La mer et l'île se découvrent |
| 20 s | Le cadeau est épuisé | Le bac passe à « tranquille ×0,5 » (aucun message) |
| 29-31 s | Arrive sur l'île | 2 buissons au bout du pont |
| 31-55 s | 3 buissons et 8 arbres | Panier ≈ 81/100 |
| 55 s | **« 🏠 Rentrer »** | Court fondu, et il est à l'entrée de sa parcelle (pas de chiffres qui défilent) |
| 58 s | Marche dans le **bac** | « +81 🍓 » → « gourmand ×2 » pendant ≈ 80 s |
| 60-75 s | Caisse, achat, sorcière ou inventaire | — |
| 75 s | Repart, ou reste | Tout a repoussé ; le bac tient encore ≈ 60 s |

---

## d. L'économie

### Règle E (décidée)

| Mélangeur | Bac vide | Bac avec fraises |
|---|---|---|
| 1er (`Melangeur1A`) | ×0,5 (1 bonbon / 4 s) | ×2 (1 bonbon / s, 1 fraise chacun) |
| 2e (`Melangeur1B`) | ×1 (comme aujourd'hui) | ×2 |

Texte à l'écran (décision c), sur le bac et dans la bulle de la pastille :
**« Mélangeur 1 : tranquille ×0,5 / gourmand ×2 ; Mélangeur 2 : ×1 / gourmand ×2 »**.

- Le bac nourrit **d'abord le 1er** mélangeur. C'est là qu'une fraise rapporte le plus : 0,75 bonbon de plus, contre 0,5 pour le 2e.
- Pour avoir cette priorité, **un seul « chef d'orchestre » par usine et par type** fait les tics des mélangeurs dans l'ordre de la liste `Reglages.Hybride.Melangeurs`.
- La liste des mélangeurs est dans `Reglages` (on ne devine pas le « 2e » à son nom).
- Sans fraises, le rythme ne dépend d'aucun hasard (un compteur).
- Limite de 80 bonbons atteinte : aucune fraise n'est consommée.

### Un tour (chiffres gardés pour le prototype) 🧮

| | Quantité | Gain | Repousse (par joueur) |
|---|---|---|---|
| Arbres de l'île | 8 | 5 à 9 (moy. 7) | 60 s |
| Buissons | 10 | 2 à 3 (moy. 2,5) | 45 s |
| **Total d'un tour** | | **≈ 81 fraises** | |

- **Durée d'un tour** = aller + 10 buissons (10 s) + 8 arbres (20 s) + retour (3 s) + usine (15 s).
  Ça donne **70 s** (P3), **79 s** (P2) et **88 s** (P1).
- **Apport moyen** : **1,15 / 1,03 / 0,92 fraise/s**. Un joueur « peu actif » (1 tour toutes les ≈ 3 min 20) : 0,4 fraise/s.
- **Panier** : 100. **Bac** : 200.

### Tableau de progression : zone 1 jusqu'à l'achat de `Zone2`, règle E, rareté comprise 🧮

`MultiplicateurPrix` (seulement si `HYBRIDE_ACTIF`) :

| Achat | Multiplicateur | Prix |
|---|---|---|
| Cuiseur1 | ×1 | 60 |
| Mouleur1 | ×1 | 250 |
| Emballeuse1 | ×1,8 | **1 800** |
| Melangeur1B | ×1,8 | **6 300** |
| Zone2 | ×1,8 | **18 000** |

| Achat suivant | Aujourd'hui (sans hybride, anciens prix) | Inactif | Peu actif (0,4/s) | Actif P1 (0,92) | Actif P2 (1,03) | Actif P3 (1,15) |
|---|---|---|---|---|---|---|
| Cuiseur1 | 13 s | 26 s | 12 s | 7 s | 6 s | 6 s |
| Mouleur1 | 27 s | 54 s | 24 s | 14 s | 13 s | 13 s |
| Emballeuse1 | 54 s | 3 min 14 | 1 min 28 | 51 s | 48 s | 48 s |
| Melangeur1B | 1 min 15 | 4 min 31 | 2 min 03 | 1 min 12 | 1 min 08 | 1 min 08 |
| Zone2 | 1 min 48 | 4 min 18 | 3 min 04 | 2 min 14 | 2 min 09 | 2 min 09 |
| **Total zone 1** | **4,6 min** | **13,4 min** | **7,2 min** ⚠️ | **4,65 min** | **4,4 min** | **4,4 min** |

Les mêmes avec les anciens prix (×1), pour comparer : inactif 8,0 · peu actif 4,3 · P1 2,7 · P2 et P3 2,6 min.

- ✅ **Actif ≈ 4,6 min, comme demandé** (4,4 à 4,65 selon la parcelle).
- ✅ Actif ≈ **3× plus rapide qu'inactif**. Inactif : il progresse toujours, jamais bloqué.
- ⚠️ **Le « peu actif » (un tour toutes les 3 min) devient plus lent qu'aujourd'hui** (7,2 min au lieu de 4,6),
  et le joueur de P1 l'est de 2 s. Avec ×1,8, il faut récolter **sans arrêt** pour égaler l'ancien jeu (voir le désaccord 3).
- Seuil « jamais plus lent qu'aujourd'hui » pour **tous** les joueurs qui récoltent un peu : **×1,1 au plus**
  (et alors l'actif finit en ≈ 3 min). On ne peut pas avoir les deux en même temps.
- Les zones 2 et 3 ne changent pas (pas d'ingrédient, pas de multiplicateur).

### Les multiplicateurs qui s'empilent (risque) et comment les suivre

Aujourd'hui, le revenu d'un bonbon et le rythme se multiplient :

| | Valeur |
|---|---|
| Machines | jusqu'à ×10 par zone |
| Rareté | moyenne ×2,32 ; jusqu'à ×500 |
| Fraises | rythme ×0,5 à ×2 |
| Plus tard : bonus de chance (fraisier doré) | +28,5 % de rareté moyenne 🧮 |
| Plus tard : un pass de gain | ×2 ? |

Ensemble, ×2,32 × 2 × 1,285 × 2 ≈ **×12** par rapport à la valeur de départ.
**Risque** : chaque ajout raccourcit tout le jeu, et on ne le remarque qu'après coup.

Comment le suivre :
1. **Un registre** dans `Reglages.Hybride` (commenté) : chaque multiplicateur, sa source, sa valeur maximale,
   et s'il est déjà branché. Un nouveau multiplicateur = une ligne de plus dans le registre + **ce tableau de progression refait** dans ce document.
2. **Un affichage dans le panneau de debug** (Studio seulement) : « revenu calculé » à côté de
   « revenu mesuré sur les 60 dernières secondes ». C'est ce qui transformera les 🧮 en 📏.
3. **Une règle de conception pour plus tard** : un futur bonus (pass, événement) **s'additionne** sur le même
   axe au lieu de multiplier (par exemple +1 au rythme gourmand, et non ×2 sur tout), avec un plafond total dans `Reglages`.

---

## e. Canaux, vérifications, sauvegarde, interface

(Inchangé depuis la version 2, sauf les noms : sac → panier, rythme « tranquille / gourmand ».)

### Modules serveur
- `server/Ingredients.luau` : **le seul module qui modifie le panier et le bac**. Il gère la sauvegarde,
  la vérification, le cadeau et `consommer`.
- `server/Recolte.luau` : les points de récolte, la repousse par joueur, le bac, « Rentrer » et la barrière de quartier.
- Production : le « chef d'orchestre » des mélangeurs (règle E).
- Boutons : le `MultiplicateurPrix` (le prix affiché et le prix payé sont le même chiffre).

### Points de récolte : partagés, repousse propre à chaque joueur
- Le serveur garde `prochaine[joueur][point]`. Ce tableau n'est pas sauvegardé : quitter puis revenir fait tout repousser (au plus un tour gagné).
- L'écran cache, **chez lui**, les fruits (`Fruit = true`) et le prompt des points en repousse.

### Canaux

| Canal | Sens | Contenu |
|---|---|---|
| `IngredientsMaj` | serveur → écran | `{ Panier = {Fraise=n}, CapacitePanier, Reserve = {Fraise=n}, CapaciteReserve, Rythmes = { {Nom, Facteur} }, Gain? }` |
| `DemanderIngredients` | écran → serveur | rien |
| `RecolteEtat` | serveur → écran | `{ [IdPoint] = heure de repousse (heure du serveur) }` |
| `Rentrer` | écran → serveur | rien |

- Récolte = `ProximityPrompt`. Dépôt = on marche dans le bac.
- L'écran n'envoie jamais de quantité, de gain, de prix ni de position.

### Vérifications du serveur

- **Récolte** :
  1. `HYBRIDE_ACTIF` est vrai ;
  2. c'est bien un point du monde ;
  3. son île est ouverte pour ce joueur ;
  4. le joueur est vivant et à ≤ 12 studs de la Part `Prompt` ;
  5. le point n'est pas en repousse pour lui ;
  6. au moins 0,25 s depuis sa dernière récolte ;
  7. le panier a de la place.
- **Dépôt** : c'est son bac, il est vivant, son panier n'est pas vide.
- **Rentrer** : au plus 1 fois / 10 s, joueur vivant et à plus de 60 studs de chez lui, puis
  `RequestStreamAroundAsync` et `PivotTo` vers `Apparition`.
- **Demandes truquées testées** (à l'étape 4) :
  - une récolte à 50 studs ;
  - un point en repousse ;
  - 20 demandes / s ;
  - un faux point ;
  - un joueur mort ;
  - le panier plein ;
  - une île fermée ;
  - le bac d'un autre joueur ;
  - « Rentrer » en rafale ;
  - « Rentrer » quand on est mort ;
  - le mode hybride éteint.

### Sauvegarde : version 6

```
Ingredients = { Panier = { Fraise = 12 }, Reserve = { Fraise = 40 }, CadeauRecu = true }
```
- **Migration 5 → 6** : panier et bac vides, `CadeauRecu = false`. Le reste est intact.
- **Cadeau** : 20 fraises dans le bac **une seule fois par compte** (joueurs actuels compris).
- **Vérification au chargement** :
  - clé inconnue → retirée ;
  - quantité qui n'est pas un entier ≥ 0 → retirée ;
  - quantité trop grande → ramenée à la capacité ;
  - `CadeauRecu` qui n'est pas un booléen → `true` (on ne redonne pas le cadeau en cas de doute).
- Les ingrédients sont lus et sauvegardés même si `HYBRIDE_ACTIF` est faux.

### Interface (même thème que l'inventaire ; textes ≥ 13 px, boutons ≥ 44 px)

- **Barre du haut**, sous l'argent :
  - pastille « 🍓 12/100 · Bac 40/200 · gourmand ×2 » ; un appui ouvre une petite bulle avec le texte de la règle E (décision c) ;
  - bouton **« 🏠 Rentrer »**, seulement loin de chez soi ;
  - bouton **« 🎵 »** pour couper ou remettre la musique.
- **« Cueillir »** (téléphone) : en bas à droite, au-dessus du saut, 150 × 64 px de maquette, sans viser. Ordinateur : prompt E.
- **Sur le bac** (dans le monde) : « 🍓 40/200 » et le texte de la règle E.
- **Mots doux** :
  - « Rythme tranquille / gourmand » ;
  - panier plein → « Ton panier déborde de fraises ! Le bac de ton usine les attend 🍓 » ;
  - **jamais** de minuteur de repousse, ni de « dépêche-toi ».

### Musique d'ambiance (emplacement prévu, rien d'importé)
- Un `Sound` nommé **`MusiqueAmbiance`** dans `SoundService`, créé par l'écran.
  - `SoundId` = `Theme.Sons.Musique.Id`, **vide** tant que tu n'as pas fourni le fichier (sous licence libre) : rien ne joue.
  - `Theme.Sons.Musique = { Id = "", Volume = 0.3 }`, en boucle.
- Bouton 🎵 : coupe ou remet la musique. Le choix n'est **pas sauvegardé** (aucune donnée) : il revient à « on » à chaque partie.
- **Sons existants** : tous sont le « ping » fourni avec Roblox Studio (`rbxasset://sounds/electronicpingshort.wav`,
  contenu intégré à Roblox). Les volumes sont réglables dans `Theme.Sons`. **Je n'importe aucun autre son.**

### Réglages (tous dans `Reglages.luau`)

```lua
Reglages.HYBRIDE_ACTIF = false -- false = le jeu d'aujourd'hui, exactement

Reglages.Hybride = {
	-- Règle E : le bac nourrit les mélangeurs dans cet ordre
	Melangeurs = {
		{ Nom = "Melangeur1A", SansFraises = 0.5, AvecFraises = 2 },
		{ Nom = "Melangeur1B", SansFraises = 1, AvecFraises = 2 },
	},
	MultiplicateurPrix = { -- seulement si HYBRIDE_ACTIF ; un achat absent = ×1
		Emballeuse1 = 1.8, Melangeur1B = 1.8, Zone2 = 1.8,
	},
	CapacitePanier = 100, CapaciteReserve = 200, CadeauDepart = 20,
	DelaiEntreRecoltes = 0.25, DistanceMax = 12, PorteePrompt = 8, DureeAppui = 0.25,
	Rentrer = { Fondu = 1, Delai = 10, DistanceMin = 60 },
	Ingredients = { Fraise = { TypeBonbon = "Fraise", Emoji = "🍓" } },
	Points = {
		ArbreFraise   = { Ingredient = "Fraise", GainMin = 5, GainMax = 9, Repousse = 60 },
		BuissonFraise = { Ingredient = "Fraise", GainMin = 2, GainMax = 3, Repousse = 45 },
	},
	Quartiers = { Verger = { Ouvert = true } },
	Bac = { Modele = "BacDepot", Position = Vector3.new(-30, 0, -50) },
	-- Registre des multiplicateurs (à tenir à jour, voir docs/design_hybride.md, section d)
}
```

### Règle de remplacement des modèles

| Quoi | Règle |
|---|---|
| Model | attribut **`Sorte`** = `"ArbreFraise"` ou `"BuissonFraise"` ; posé à la main dans `Monde/Iles/Verger/Recolte` |
| PrimaryPart | Part **`Base`** à plat, non tournée, invisible ; le bas de la Base = le sol |
| `Prompt` | Part invisible à hauteur de poitrine (la distance est mesurée depuis elle) |
| Fruits | pièces avec **`Fruit = true`** |
| Collisions | aucune (CanCollide, CanQuery, CanTouch à false), tout ancré |
| Streaming | `ModelStreamingMode = Atomic` |

---

## f. Impact sur le code existant

- **Inchangé** : tapis, machines de transformation, point de vente, rareté, modèles de bonbons, inventaire, carnet,
  caisse, sorcière, zones 2 et 3.
- **Modifié** :
  - `Production.luau` : le démarrage des mélangeurs (chef d'orchestre de la règle E) ;
  - `Boutons.luau` : le prix × `MultiplicateurPrix`, si hybride ;
  - `Parcelles` : `Ingredients` ;
  - `Sauvegarde` : version 6.
- **`HYBRIDE_ACTIF = false`** : ancienne boucle exacte, anciens prix, rien dans le monde, rien à l'écran.
- `ModeleUsine` n'est pas modifié.

---

## g. Étapes

| # | Étape | État |
|---|---|---|
| 0 | Branche `hybride` depuis `nuit-auto` + plan v3.1 + `tools/exporter_sauvegarde.lua` | **faite** (`bcc82ec`) |
| 1 | Réglages, `Ingredients.luau`, sauvegarde v6, cadeau, vérification | **faite, testée dans `Test_Hybride`, attend « commit »** |
| 2 | Production 50 % / 200 % + règle E + `MultiplicateurPrix` (`Boutons.luau`) | autorisée, après le commit de l'étape 1 |
| 2b | **Tests de faisabilité de l'archipel** (b.1 à b.4 ci-dessous), objets temporaires dans `Workspace/TestHybride` | **pas dans le périmètre autorisé** : à confirmer plus tard |
| 3 | Studio : île, pont, mer, sentier, arbres, buissons, bac. **Ajouts (consigne du 2026-10-04)** : du sable de remontée **à intervalles réguliers le long de tout le pont** (des deux côtés) ; test « tomber du pont, puis remonter seul ou utiliser Rentrer », à plusieurs endroits du pont | **attend ta validation du plan v3** |
| 4 | `Recolte.luau` (points, repousse, bac, Rentrer, barrière) | après 3 |
| 5 | Écran (barre, Cueillir, Rentrer, 🎵, explication de la règle E, tutoriel) | après 4 |
| 6 | Mesures, `CLAUDE.md`, `IDEES.md`, `decor-carte.md` | après 5 |

### Détail des étapes 0, 1 et 2
- **Étape 0** :
  - `git switch -c hybride` depuis `nuit-auto` ;
  - commit (après ton « commit ») : ce plan v3 + tes 2 images de l'archipel.
- **Étape 1** (≈ 1 h 30) :
  - `Reglages` : `HYBRIDE_ACTIF = false` + table `Hybride` ;
  - `server/Ingredients.luau` : seul module qui modifie panier et bac ; `demarrer` avec vérification et cadeau,
    `lire`, `arreter`, `ajouterAuPanier`, `deposer`, `consommer`, envoi à l'écran ;
  - canaux `IngredientsMaj` / `DemanderIngredients` ;
  - `Sauvegarde` : version 6 + migration ;
  - `Parcelles` : branchement.
  - **Tests**, dans `Test_Hybride` seulement :
    - migration 5 → 6 sans perte (argent, achats, inventaire, carnet, pitiés identiques avant / après) ;
    - 6 sauvegardes abîmées nettoyées (clé inconnue, -3, 2,5, "abc", 9 999, `CadeauRecu = "oui"`) ;
    - cadeau donné **une seule fois** sur 2 parties de suite ;
    - rechargement identique.
- **Étape 2** (≈ 1 h 30) :
  - chef d'orchestre des mélangeurs (règle E) dans `Production` ;
  - `MultiplicateurPrix` dans `Boutons`.
  - **Tests** sur une usine de test, pendant 120 s 📏 :
    - HYBRIDE faux → 60 bonbons par mélangeur, anciens prix ;
    - 1A, bac vide → 30 ;
    - 1A, bac plein → 120, et le bac baisse de 120 ;
    - 1A + 1B, bac vide → 30 + 60 ;
    - 1A + 1B, bac à 90 → 1A servi d'abord ;
    - 80 bonbons atteints → aucune fraise consommée ;
    - panneaux des boutons à 1 800 / 6 300 / 18 000 seulement si hybride.

### Garde-fous pour ta vraie sauvegarde (étapes 1 et 2)
- Avant **chaque** lancement de partie, je vérifie par la connexion Studio que `ServerStorage.DataStoreTest = "Test_Hybride"`.
  Après le lancement, je vérifie dans la sortie que le jeu utilise bien `Test_Hybride`.
  **Sans ces deux vérifications, je ne lance pas.**
- Le jeu de Studio sauvegarde à l'arrêt : avec l'attribut, ça va dans `Test_Hybride`, jamais dans `Joueurs_v2`.
- **État que je te laisserai à remettre en ordre** (je te le redirai dans chaque rapport) :
  - l'attribut `DataStoreTest` posé sur `ServerStorage` pendant les tests : **je le retire à la fin** et je vérifie qu'il vaut `nil` ;
  - pour tester avec le mode hybride allumé, je passe `HYBRIDE_ACTIF = true` **dans le fichier, le temps du test**,
    puis je le remets à `false` **avant** le commit (je le vérifierai dans le `git diff`) ;
  - le DataStore `Test_Hybride` gardera des fausses sauvegardes de test (sans effet sur le jeu publié).

### Tests de faisabilité de l'archipel (étape 2b, si tu la confirmes)

| Test | Méthode | Ce que je pourrai mesurer | Limite connue |
|---|---|---|---|
| b.1 Usine tournée de 60° | Dans une partie de test : copie de `ModeleUsine` tournée de 60°, production démarrée, 120 s | Pour chaque bonbon : angle entre sa vitesse et la direction du tapis (cible < 10°) ; nombre de bonbons vendus / tombés / bloqués | — |
| b.2 Avec 1, 3 et 6 joueurs | « Serveur local » de Studio avec N joueurs | Images/s du serveur, bonbons, parcelles toutes posées, aucune erreur | **Je ne sais pas si la connexion Studio peut lancer un serveur local à plusieurs joueurs.** Sinon, tu le lances (Test → Clients et serveurs → 3 puis 6) et je mesure, si la connexion y accède ; je te dirai ce que je n'ai pas pu faire |
| b.3 Le pont chargé avant qu'on l'emprunte | Pont de test de 188 studs créé dans la partie ; rayon de streaming réduit exprès (pour rendre le test difficile) ; personnage déplacé par le script | Côté écran : distance à laquelle chaque morceau du pont existe ; essai en `Persistent` | Rayons réglés par script seulement si Roblox le permet (Studio ne m'a pas laissé les lire) |
| b.4 Le muret ne bloque pas le pont | Île de test + muret + pont ; le personnage marche du pont à l'île | Il arrive sur l'île (oui / non), temps de passage, position finale | — |

**Rendu** : à chaque élément visuel, une capture d'écran. Si je n'y arrive pas, je l'écrirai :
« je n'ai pas vu ce rendu ». Pour l'instant, **je n'ai vu aucun rendu** (rien n'est construit).

---

## h. StreamingEnabled et coût sur téléphone (inchangé depuis la v2, adapté au pont) 🧮

- Activé. Rayons par défaut supposés : 64 studs au minimum, 1 024 visés.
- **Pont, île et fond de la mer en `Persistent`** (toujours chargés) : ≈ 70 pièces, c'est peu. Ainsi on ne
  marche jamais sur un pont pas encore chargé. Le test b.3 dira si c'est nécessaire.
- Points de récolte en `Atomic`. L'écran écoute les arrivées de points (`CollectionService`).
  « Rentrer » charge la parcelle avant de téléporter.
- Coût : **≈ 240 pièces** (+10 %), toutes ancrées, sans ombre. Estimation : +0,1 à 0,3 ms de calcul de l'image.
  La mer est **un seul grand plan** (pas d'eau en Terrain, plus chère).
- Ce qui coûtera le plus : la zone 1 à 200 % (≈ +13 bonbons qui roulent). À mesurer.
- Test sur l'émulateur téléphone : **par toi** (Studio ne me laisse pas le piloter, et il ralentit à 15 images/s en arrière-plan).

---

## i. Risques, et ce que je ne sais pas encore

1. Le **muret** et la **mer** : voir le désaccord 2.
2. Le **mur est** : il faut l'ouvrir (désaccord 1).
3. **Horizon** : l'anneau de falaises cache l'île depuis le hub (falaises de 20 à 28 de haut).
   On ne voit l'île qu'une fois au bord est. C'est contraire à « des îles visibles de loin donnent envie d'explorer » (question k.2).
4. Bouton « Cueillir » sur téléphone (`InputHoldBegin`) jamais vérifié.
5. Serveur local à plusieurs joueurs : je ne sais pas si je peux le piloter (b.2).
6. **Prix ×1,8** : le joueur peu actif devient plus lent qu'avant (désaccord 3).
7. Les multiplicateurs qui s'empilent (section d).
8. Ta vraie sauvegarde passera en version 6 à ta 1re partie normale après la fusion (avec les 20 fraises).
9. **Tout est calculé, rien n'est mesuré.**

---

## j. Critères de réussite

**Ces critères remplacent ceux de la v3 (décisions finales).** Chaque valeur sera marquée 🧮 calculée
ou 📏 mesurée ; « mesurée » n'est jamais écrit sans mesure.

| # | Critère | Valeur aujourd'hui | Comment il sera mesuré (étape) |
|---|---|---|---|
| 1 | `HYBRIDE_ACTIF` faux : jeu **identique** (60 bonbons en 120 s avec un mélangeur, mêmes prix, mêmes sauvegardes) | 🧮 par construction (ancienne boucle et anciens prix gardés) | Usine de test, comptage sur 120 s, panneaux des boutons (étape 2) ; sauvegarde relue (étape 1) |
| 2 | Sans fraises : on progresse toujours, à 50 % du rythme actuel (mélangeur 1) | 🧮 30 bonbons / 120 s | Bac vide, comptage sur 120 s (étape 2) |
| 3 | Apport ≥ 0,33 fraise/s → production ≥ aujourd'hui (avant `MultiplicateurPrix`) | 🧮 1 mélangeur : 0,25 + 0,75 × 0,33 = 0,50 bonbon/s ; 2 mélangeurs (règle E) : 0,75 + 0,75 × 0,33 = 1,00 | Apport simulé de 0,33/s dans l'usine de test (étape 2) |
| 4 | Actif (≥ 1 fraise/s) ≥ 2,5× plus rapide que l'inactif ; peu actif plus rapide que l'inactif ; actif : zone 1 en ≈ 4,5 min (4,3 à 4,8) | 🧮 actif 4,4 à 4,65 min ; inactif 13,4 ; peu actif 7,2 → 2,9 à 3,0× | Calcul refait avec les bonbons/s **mesurés** à l'étape 2 ; partie chronométrée plus tard |
| 5 | Migration 5 → 6 sans perte (argent, achats, inventaire, carnet, pitié, sorcière), cadeau une seule fois, sauvegardes abîmées nettoyées | — | `Test_Hybride` (étape 1) |
| 6 | Aucun bonbon créé ni fraise consommée au-delà de 80 bonbons | 🧮 par construction | Usine de test remplie à 80 (étape 2) |

Plus tard (étapes 3 à 6, pas encore autorisées) :
- 1er point de récolte en moins de 15 s ;
- 1er arbre à ≈ 28 s du hub ;
- une action toutes les 10 à 20 s ;
- 60 images/s sur téléphone.

Les temps ne seront notés qu'en mode debug, donc seulement dans Studio.

**Aucune donnée dans le jeu publié** : ces mesures n'existent que si `ModeDebug.actif` est vrai, c'est-à-dire seulement dans Studio, avec l'attribut coché.

---

## k. Désaccords et questions

> **v3.1 : désaccords 1, 2 et la question k.2 réglés** par les décisions a et b (ouverture de l'est, mer peu
> profonde, 2 falaises voisines rangées). **Désaccord 3** : ×1,8 gardé (décision d). Le critère 3 est mesuré
> **avant** le `MultiplicateurPrix`, ce qui règle la contradiction. Le texte de la v3 est gardé ci-dessous
> pour mémoire.

**Désaccord 1 : « Garde les murs de la carte actuelle tels quels » n'est pas possible à 100 %.**
- Le mur invisible est (X = 264, 80 de haut) et la falaise en (277, 0) ferment tout le côté est :
  sans ouverture, on ne peut pas atteindre le pont.
- Je propose le **minimum** : ranger cette falaise et `MurEst` dans `Decor_Anciens`, et poser 2 morceaux
  de mur identiques avec **14 studs d'ouverture** pour le pont. Les 3 autres murs et les 33 autres falaises ne bougent pas.

**Désaccord 2 : le muret invisible bas ne suffit pas.**
1. **On saute par-dessus** : un personnage Roblox saute à ≈ 7 studs. Un muret « bas » est franchi ; pour bloquer,
   il faut ≥ 8 studs, donc plus vraiment « bas ».
2. **Le pont n'a pas de muret** : on peut sauter du pont dans la mer.
3. **Sous la mer, il n'y a rien** (la Baseplate s'arrête à X = 256) : une chute = mort et réapparition,
   c'est punitif et contraire au ton doux.
4. Un mur invisible fait « vitre » quand on s'y cogne.

**Mon alternative (non construite), qui suit la règle de ta maquette « la mer est peu profonde et ne tue pas »** :
- un **fond de mer solide** à 3,5 studs sous l'eau ;
- des **pentes de sable** (8 coins) autour de l'île et au bout du pont pour remonter ;
- **4 murs invisibles loin au large** (≈ 150 studs autour de l'île) ;
- des **rambardes de bonbon visibles** (basses, décor + collision) le long du pont, pour guider sans enfermer ;
- et toujours le bouton « Rentrer ».

Conséquence : on peut contourner la barrière du pont en marchant dans l'eau, donc **le vrai verrou est le refus
de récolte par le serveur**. C'est déjà prévu ; on pourra ajouter plus tard un « courant » qui ramène doucement au bord.

**Désaccord 3 : avec ×1,8, la promesse « jamais plus lent pour un joueur qui récolte » ne tient que pour celui qui récolte sans arrêt.**
- Peu actif : 7,2 min au lieu de 4,6. P1 : 4,65 min.
- Choix possibles :
  - **(a)** garder ×1,8 et comprendre la promesse comme « un joueur qui fait des tours » ;
  - **(b)** ×1,4 : 🧮 actif ≈ 3,5 min, peu actif ≈ 5,7 min ;
  - **(c)** ×1,1 : la promesse tient pour tous, mais l'actif finit en ≈ 3 min.
- Je mets **×1,8 comme tu l'as demandé** (c'est un seul chiffre dans `Reglages`). Je recommande d'en décider après tes premières parties chronométrées.

**Question k.2 : ouvrir l'horizon ?** Ranger aussi dans `Decor_Anciens` les 2 falaises voisines (Z = ±55,7)
pour qu'on voie l'île depuis le hub ? **Je recommande oui**, mais c'est hors de ce que tu as autorisé.

### Optionnel (seulement quand tout le reste sera testé) : le fraisier doré, décrit, pas construit (v3.1)
- **Mécanique** : en moyenne **toutes les 6 min** (entre 5 et 7, tirage du serveur), un fraisier doré apparaît à
  **un des 6 endroits prévus** sur l'île, **hors du sentier** (derrière les arbres, sur la plage).
  - Il est visible pour tous, et **chaque joueur peut le cueillir une fois**.
  - Il donne **+30 % de chance** (l'attribut `BonusChance` = 0,3, qui existe déjà mais que rien ne donne)
    pendant **2 min**. Pas de minuteur pressant à l'écran : une petite étoile tant que le bonus dure.
  - Il disparaît doucement au bout de 2 min s'il n'est pas cueilli.
  - Chiffres dans `Reglages.Hybride.FraisierDore`.
- **Calcul de l'impact** 🧮 :
  1. Aujourd'hui, la valeur moyenne d'un bonbon due à la rareté est de
     0,6995 × 1 + 0,20 × 2 + 0,07 × 5 + 0,025 × 15 + 0,005 × 50 + 0,0005 × 500 = **×2,324**.
  2. Avec `BonusChance` = 0,3, toutes les chances au-dessus de Commun sont multipliées par 1,3, et Commun baisse
     d'autant : 1 − 0,3005 × 1,3 = 0,609. On obtient 0,609 × 1 + 1,3 × (0,4 + 0,35 + 0,375 + 0,25 + 0,25)
     = 0,609 + 1,3 × 1,625 = **×2,722**. Soit **+17,1 % de revenu pendant le bonus**.
  3. Le bonus dure 2 min sur un cycle moyen de 6 min, donc il est actif 1/3 du temps
     (s'il est trouvé à chaque fois) : 17,1 % × 1/3 = **+5,7 % en moyenne**.
     Avec une apparition toutes les 5 min : 17,1 % × 2/5 = **+6,8 %**. Si le joueur en rate 1 sur 3 : ≈ +3,8 à +4,6 %.
  4. **Fourchette : +5,7 % à +6,8 % pour un joueur qui les trouve tous**, dans la cible de +5 à +8 %.
- **Variance** : la chance d'un Mythique (×500) passe aussi de 0,05 % à 0,065 % pendant le bonus.
  Sur de longues parties, c'est compris dans la moyenne. Sur une seule partie, ça peut donner un gros coup de chance.
- **Mesure** (Studio, mode debug) pour répondre à « sort-il du sentier ? » :
  - distance de chaque joueur au sentier, notée toutes les secondes ;
  - nombre de fraisiers dorés cueillis sur le nombre apparus ;
  - temps entre l'apparition et la cueillette.
