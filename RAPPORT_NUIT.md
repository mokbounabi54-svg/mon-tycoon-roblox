# Rapport de la mission autonome « nuit-auto »

Branche : `nuit-auto`, créée depuis `rarete-inventaire` (commit `887a074`). Rien n'a été
fusionné, rien n'a été poussé de force, `main` n'a pas été touchée.

| Phase | État | Commit |
|---|---|---|
| 0. État des lieux | **Fait** (rien à corriger dans le code) | — |
| 1. Modèles Menthe et Or | **Fait** (pas vu à l'écran, voir plus bas) | `69daca4` |
| 2. Carnet de collection | **Fait** | `8283a1c` |
| 3. La sorcière | **Fait** | `9153b9b` |
| 4. Finitions | **Fait** (sons, tutoriel, petit nettoyage) | `0b28cbb` |

**Ta vraie sauvegarde (`Joueurs_v2`) n'a jamais été lue par le jeu ni écrite.** Tous les tests
ont utilisé le DataStore de test `Test_Nuit`, qui ne marche que dans Studio. Je l'ai relue à la
fin : `278 $`, 3 machines, version 2, dernière écriture à 20:42 (avant la mission).
L'attribut `DataStoreTest` est retiré de `ServerStorage`.

**Limite importante pendant toute la mission :** au bout d'un moment, Studio a cessé de
dessiner l'image et de recevoir le clavier et la souris (fenêtre sans doute réduite ou au
second plan). Je n'ai donc **aucune capture d'écran** de Menthe et Or, du carnet ni de la
sorcière. J'ai tout vérifié par calcul et par des tests du serveur, mais **l'aspect visuel est
à contrôler par toi**.

---

## Phase 0 : état des lieux — fait
- La sous-étape B était déjà finie, committée (`887a074`) et testée.
- J'ai relu le serveur (Parcelles, Sauvegarde, Inventaire, Production, Rarete, Prix, Boutons,
  Caisse) et l'écran. Je n'ai pas trouvé de bug évident.
- Deux scripts **`Workspace.Script`** (seulement dans Studio, pas dans Git) affichent
  « Hello world! » à chaque partie, et le module `ReplicatedStorage/Shared/Hello` n'est utilisé
  nulle part. Ta règle interdit de supprimer des objets dans Studio, donc **je n'y ai pas
  touché**. Tu peux les supprimer si tu ne t'en sers pas.

## Phase 1 : modèles Menthe et Or — fait (aspect non vérifié)
- Ajoutés dans `ServerStorage/ModelesBonbons/Menthe` et `/Or`, avec 4 étapes chacun. La Fraise
  n'a pas été modifiée. Mêmes règles que la Fraise : `Corps` de 1 × 1 × 1, 6 pièces au
  maximum, autres pièces sans collision et soudées, `Teinte` sur le corps du bonbon.
- **Menthe** (#2FCFA3) : l'étape Moulé est une pastille à plat avec 3 rayures blanches et un reflet.
- **Or** (#FFC21F) : l'étape Moulé est une étoile à plat. Décision : une vraie étoile à 5
  pointes demande plus de 6 pièces, donc j'ai fait **5 branches rectangulaires** qui partent
  du centre. Elle ressemble plus à un « astérisque » qu'à l'étoile de la maquette.
- Pâte, Cuit et Emballé sont les mêmes formes que la Fraise, avec les couleurs de chaque type.
- Les mélangeurs des zones 2 et 3 avaient déjà `TypeBonbon`, et les machines `EtapeBonbon` :
  aucune modification n'a été nécessaire dans `ModeleUsine`.
- `Reglages.Types` : les couleurs d'icône de Menthe et Or reprennent les hex de la fiche.
  Ce sont de simples couleurs d'affichage, pas des chiffres d'équilibrage.
- Tests : 3 zones avec mélangeurs accélérés jusqu'à 80 bonbons → 60 images/s côté serveur,
  aucun bonbon tombé ni bloqué, toutes les étapes passent, 0 erreur de teinte sur 18
  combinaisons Menthe/Or. **Images/s côté écran non mesurées** (Studio ne dessinait plus).

## Phase 2 : carnet de collection — fait
- Serveur `Carnet.luau` : une découverte est enregistrée quand un bonbon sort d'un mélangeur
  de ton usine, ou quand la sorcière fabrique un bonbon. Message « Nouveau dans le carnet ».
- Sauvegarde **version 4** (`Carnet = { ["Fraise|Rare"] = true }`). Décision : la migration
  3 → 4 remplit le carnet avec ce que contient déjà l'inventaire, pour ne rien perdre.
- Écran `client/Carnet.luau`, d'après la maquette :
  - grille 3 × 6 : bonbons découverts en couleur, les autres en silhouette grise avec « ? » ;
  - barre de progression et compteur « N / 18 découverts » ;
  - badge « Nouveau ! » ;
  - bouton « Carnet » sous « Inventaire », avec une pastille rose quand il y a du nouveau, et touche C.
- Décisions :
  - le badge « Nouveau ! » reste jusqu'à la **fermeture** du carnet ; il n'est pas sauvegardé ;
  - les cases inconnues ont une bordure claire pleine, car Roblox ne sait pas faire de
    pointillés sans images.
- Nouveau module `client/Icones.luau` : les icônes 3D, partagées par l'inventaire, le carnet
  et la sorcière.
- Tests :
  - la migration 3 → 4 inscrit bien les combinaisons de l'inventaire ;
  - les découvertes se font en jeu, et la sauvegarde puis le rechargement sont identiques ;
  - mise en page mesurée sur 5 écrans : textes ≥ 13,4 px, boutons ≥ 45 px.
- Non vérifié : la touche C en vrai (Studio ne recevait plus le clavier, même I ne marchait
  plus). Elle est branchée comme la touche I, qui avait été vérifiée hier.

## Phase 3 : la sorcière — fait
- Modèle **`ServerStorage/PNJ/Sorciere`** en formes simples : robe, tête, chapeau, chaudron
  et potion Neon. Il est copié dans chaque usine à (-15, 0, -52), près de l'entrée, tourné
  vers la caisse. `ProximityPrompt` « Parler » (touche E). Seul le propriétaire peut lui parler.
- Règles (`Reglages.Sorciere`) :
  - taux de réussite 80 / 60 / 40 / 25 / 10 %, comme demandé ;
  - pitié après 5 échecs de suite au même palier ;
  - une transformation à la fois ;
  - pas de Mythique ni de bonbon raté en entrée.
- Décisions :
  1. **Le retrait des 3 bonbons, le tirage et l'ajout du résultat se font tout de suite,
     d'un seul bloc ; seule la révélation attend 3 s.** Si le joueur quitte pendant la fumée,
     sa sauvegarde est donc déjà juste et rien n'est perdu. La fiche disait « attend 3 s puis
     tire » ; pour le joueur, le résultat est le même.
  2. Le « Bonbon raté » est une pile `"Raté|Commun|Normal"` qui vaut **10 $** (`ValeurRate`).
     Il ne compte pas dans le carnet.
  3. « Chance garantie dans N essais », avec N = 6 − échecs. Après 5 échecs, l'écran affiche
     « Réussite garantie cette fois ! ».
  4. Le palier de pitié est la rareté **donnée** (par exemple « Rare » pour Rare → Épique).
  5. Il faut être à 25 studs maximum du chaudron (anti-triche).
  6. Choix des bonbons : un clic sur un emplacement vide ouvre une liste des piles possibles
     (même rareté que les bonbons déjà posés) ; un clic sur un emplacement rempli le vide.
     Les maquettes ne montraient pas cette étape.
  7. L'icône à côté de la bulle est l'emoji 🧙, pas un dessin de chapeau. La version
     « sorcière » de l'emoji est faite de plusieurs symboles et risquait de s'afficher en
     deux morceaux.
- Sauvegarde **version 5** (`PitieSorciere = { ["Rare"] = 2 }`), migration 4 → 5 vers `{}`.
- Tests :
  - transformation valable : réponse en 3,1 s, inventaire juste ;
  - 2e demande pendant la fumée refusée ;
  - 7 demandes truquées refusées (raretés mélangées, bonbons non possédés, Mythique,
    4 bonbons, bonbons ratés, texte, 2 bonbons) ;
  - pitié vérifiée : après 5 échecs, la réussite suivante est garantie ;
  - une réussite inscrit bien le bonbon dans le carnet ;
  - la sauvegarde version 5 et le rechargement sont justes ;
  - 5 écrans mesurés, fenêtre de choix ouverte : textes ≥ 13,5 px, boutons ≥ 45 px, toutes
    les phrases tiennent dans la bulle.
- Non vérifié : un vrai appui sur la `ProximityPrompt` (j'ai ouvert l'écran en simulant le
  message du serveur), la fumée et le son, et les clics réels sur l'écran.

## Phase 4 : finitions — fait
- Les messages Légendaire, Mythique et « Nouveau dans le carnet » jouent un **son court et
  discret**. C'est le « ping » de Roblox à faible volume, avec 3 hauteurs différentes, réglé
  dans `Theme.Sons`.
- **Bug corrigé** : sur un petit téléphone, un message long réduisait automatiquement sa police
  et pouvait passer sous 13 px. Désormais : taille fixe (26 px, ou 18 px sur téléphone),
  retour à la ligne, et 4 messages au maximum à la fois.
- **Tutoriel** (`client/Tutoriel.luau`) : 4 bulles à 3 s, 30 s, 60 s et 95 s, seulement pour
  un nouveau joueur (0 $ et aucune machine). Boutons « OK » et « Passer ».
  `Reglages.Tutoriel.Actif = false` le coupe complètement. Décision : le fait d'avoir passé
  le tutoriel n'est pas sauvegardé, puisqu'il ne s'affiche qu'à un joueur sans argent ni machine.
- Nettoyage : code mort retiré de l'écran d'inventaire, et l'ordre des types vient
  maintenant de `Reglages.OrdreTypes`.

---

## Bugs connus et limites
- **Petit écran d'ordinateur (1024 × 600)** : les panneaux (inventaire, carnet, sorcière)
  mordent d'environ 12 px sur la bande du menu Roblox en haut. C'est voulu, pour garder les
  textes à 13 px ou plus.
- L'étoile de l'Or est approximative (voir phase 1).
- Le son de la fumée de la sorcière et les sons des messages sont des bouche-trous
  (le même « ping » de Roblox).
- Les bonbons gardés dans l'inventaire sont mis à jour à chaque bonbon gardé : si
  l'inventaire est ouvert pendant que l'usine tourne vite, les cartes se reconstruisent souvent.
- L'équilibrage n'a pas été touché. La sorcière et les Mythiques (8 M$ pour un Or Mythique)
  restent à équilibrer avec toi.

## Objets ajoutés dans Studio (pas dans Git)
- `ServerStorage/ModelesBonbons/Menthe` (Pate, Cuit, Moule, Emballe)
- `ServerStorage/ModelesBonbons/Or` (Pate, Cuit, Moule, Emballe)
- `ServerStorage/PNJ` (nouveau dossier) → `Sorciere`
- Rien d'autre : l'aperçu temporaire dans le Workspace a été supprimé, et les attributs de
  test sont retirés. `ModeleUsine` n'a pas été modifié pendant la mission.
- Le DataStore de test **`Test_Nuit`** (chez Roblox, utilisable seulement dans Studio)
  contient une fausse sauvegarde de test. Elle est sans effet sur le jeu publié.

**→ Enregistre le jeu dans Studio (Ctrl+S)**, sinon ces objets seront perdus.

## Ce que tu dois tester à la main
1. **Enregistre le jeu dans Studio (Ctrl+S)**, puis lance une partie normale. La sortie doit
   montrer la conversion de ta sauvegarde (« version 3 », « version 4 », « version 5 ») puis
   « chargée : 278 $, 3 achat(s) ». C'est normal : ta vraie sauvegarde passe en version 5
   à ce moment-là.
2. **Menthe et Or** :
   - achète la zone 2 ou triche un peu avec le mode test (`TestSansSauvegarde` coché sur
     `ServerStorage`, puis décoche-le après) ;
   - regarde la pastille rayée et l'étoile, et dis-moi si elles te plaisent ;
   - vérifie que les bonbons restent sur les tapis.
3. **Carnet** :
   - bouton « Carnet » et touche **C** ;
   - les découverts sont en couleur, les autres en gris avec « ? » ;
   - la barre et le compteur avancent ;
   - le badge « Nouveau ! » et la pastille rose du bouton apparaissent ;
   - quitte et reviens : le carnet est gardé.
4. **Sorcière** :
   - va vers l'entrée et appuie sur **E** près du chaudron ;
   - remplis les 3 emplacements, puis « Muter » ;
   - tu dois voir la fumée verte et entendre le son pendant 3 s, puis la phrase et le résultat ;
   - essaie un mélange de raretés : il doit être refusé ;
   - vérifie l'inventaire après (3 bonbons en moins, 1 en plus).
5. **Tutoriel** : avec un compte neuf, ou dans le DataStore de test avec une sauvegarde vide,
   les 4 bulles doivent apparaître ; « Passer » doit les arrêter.
6. **Sons** : vérifie qu'ils restent discrets (Légendaire, Mythique, carnet, vente).
7. **Émulateur de Studio** (Test → Device), **en paysage** : un petit téléphone (par exemple
   iPhone SE) et une tablette. Ouvre l'inventaire, le carnet et la sorcière : rien ne doit
   déborder, les boutons doivent être faciles à toucher, et le bouton Inventaire, le bouton
   Carnet et la bulle du tutoriel ne doivent pas gêner le joystick ni le bouton de saut.
8. Dis-moi tout ce qui ne te plaît pas : je corrige.
