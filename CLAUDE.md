# Tycoon d'usine à bonbons (Roblox)

Jeu Roblox de type tycoon : chaque joueur construit sa chaîne de production de bonbons.
Un mélangeur crée de la pâte, des tapis roulants la transportent à travers un cuiseur,
un mouleur et une emballeuse (la valeur augmente à chaque étape), puis un point de vente
vend le bonbon et met l'argent dans la caisse. Le joueur ramasse l'argent de la caisse et
achète de nouvelles machines grâce à des boutons posés au sol.

## L'utilisateur est débutant

- Réponds en français.
- Explique simplement ce que tu fais et pourquoi, sans jargon (ou en expliquant
  chaque terme technique la première fois).
- Avant une modification, dis en une ou deux phrases ce que tu vas changer ;
  après, résume ce qui a changé et comment le tester dans Studio.
- Garde le code lisible pour un débutant : noms de variables en français, commentaires
  qui expliquent le « pourquoi », pas d'astuces compliquées.

## Outils et organisation

- Le projet utilise **Rojo** (installé via `rokit.toml`) : les fichiers de `src/` sont
  synchronisés **vers** Roblox Studio. Ce qui est modifié directement dans Studio
  n'est pas recopié dans les fichiers.
- `src/server/` → `ServerScriptService/Server` (scripts serveur)
- `src/client/` → `StarterPlayer/StarterPlayerScripts/Client` (scripts client)
- `src/shared/` → `ReplicatedStorage/Shared` (modules partagés, ex : `Format.luau`)
- `default.project.json` décrit la Baseplate et le dossier `Workspace/Parcelles`.
- **Les modèles 3D vivent seulement dans Studio** (choix de l'utilisateur) :
  `ServerStorage/ModeleUsine` n'est PAS dans `default.project.json` et Rojo n'y touche pas.
  L'utilisateur les retouche lui-même dans Studio. Pour les modifier, passer par la
  connexion Studio (MCP), jamais par le fichier projet. Git ne garde que les scripts.
- Pareil pour **`ServerStorage/ModelesBonbons`** (les modèles des bonbons) : créés par la
  connexion Studio, ils n'existent que dans Studio (ni dans `default.project.json`, ni dans Git).
- Les maquettes de l'utilisateur sont dans `docs/design/` (types et étapes, raretés, Halloween).

## Architecture

- `Leaderstats.server.luau` : crée la valeur `Argent` de chaque joueur.
- `Parcelles.server.luau` : **une parcelle de 120 × 120 par joueur** (6 emplacements, liste
  `EMPLACEMENTS`, espacés de 130). Charge la sauvegarde, copie `ModeleUsine` sur un emplacement
  libre, démarre la caisse, la production et les boutons, fait apparaître le joueur sur
  `Apparition`. Sauvegarde au départ, toutes les 2 minutes et à l'arrêt du serveur (`BindToClose`).
- `Sauvegarde.luau` : DataStore `Joueurs_v2` (`Joueurs_v1` = ancien, abandonné le 2026-10-02,
  données laissées intactes). Format **version 3** :
  `{ Version = 3, Argent, Achats, Inventaire = { ["Type|Rareté|Mutation"] = quantité },
  SeuilGarde, CompteurPitie }`. 3 essais en cas d'erreur. Si le chargement échoue, le joueur
  n'est jamais sauvegardé. `Sauvegarde.migrer` : version 1 → les 10 anciennes machines
  (MachineABonbons…) sont remboursées ; version 2 → 3 : inventaire vide, seuil par défaut,
  pitié 0 (argent et achats inchangés). Pour un futur format : augmenter `VERSION` et
  ajouter un cas dans `migrer`.
- `Inventaire.luau` (serveur) : **seul** module qui modifie l'inventaire (piles par joueur,
  capacité, seuil, vente). Vérifie chaque demande de l'écran (clé valable, quantité entière
  ≤ possédée, anti-spam 0,15 s) ; renvoie toujours l'état réel. Copie `ModelesBonbons` dans
  `ReplicatedStorage` au démarrage (pour les icônes). `Parcelles` appelle `demarrer` au
  chargement, `lire` pour sauvegarder et `arreter` au départ (après la sauvegarde).
- `Usine/Prix.luau` : **LA** fonction de prix (`Prix.calculer(usine, type, rareté, mutation)`),
  utilisée par le point de vente ET l'inventaire : un bonbon vaut pareil des deux côtés.
- `Usine/Production.luau` : fait fonctionner chaque machine d'après son attribut `Role`
  (voir plus bas). Un Model **sans** `Role` est un groupe : chaque machine qu'il contient
  démarre (c'est le cas des achats `Zone2` et `Zone3`). Groupes de collision : les bonbons ne touchent ni les autres bonbons ni les
  joueurs. Physique des bonbons calculée par le serveur, 80 bonbons max par usine, 30 s de vie.
- `Usine/Caisse.luau` : la Part `Caisse` garde l'argent en attente dans son attribut `Stock`
  (rempli par les points de vente) ; seul le propriétaire le récupère en marchant dessus.
  L'argent en attente n'est pas sauvegardé.
- `Usine/Boutons.luau` : boutons d'achat ; seul le propriétaire peut acheter. À l'achat (et au
  chargement de la sauvegarde), la barrière du même nom dans `Barrieres/` est détruite.
- `Usine/Rarete.luau` : tirage de la rareté de chaque bonbon (appelé par `Production` à la
  sortie du mélangeur), pitié, bonus de chance, apparence (couleur, matière, particules,
  son, lumière) et messages à l'écran.
- `Remotes.luau` : crée les RemoteEvents dans `ReplicatedStorage/Remotes`
  (`Remotes.obtenir(nom)`). Existants : `Annonce` (serveur → écran : texte, couleur),
  `InventaireMaj` (serveur → écran : `{ Piles = { {Cle, Type, Rarete, Mutation, Quantite,
  PrixUnitaire} }, Total, Capacite, Seuil, Vente? }`), et écran → serveur : `DemanderInventaire`,
  `VendreBonbons(cle, quantite)`, `ToutVendre()`, `ChoisirSeuil(nom)`. **L'écran n'envoie
  jamais de prix ni de valeur.**
- `shared/Reglages.luau` : **le** module de réglages (raretés, pitié, types et valeurs de
  départ, mutations, inventaire, réglages de test). Tous les chiffres d'équilibrage vont ici.
- `client/init.client.luau` : démarre les modules d'interface rangés à côté de lui.
  `client/Annonces.luau` : messages en haut de l'écran (4 s puis fondu, à 70 px du haut).
  `client/Argent.luau` : compteur d'argent en haut au centre (lit `leaderstats.Argent`,
  le chiffre défile et la pastille grossit quand on gagne).
  `client/Theme.luau` : **le** style de toutes les interfaces (police FredokaOne, couleurs,
  couleurs de rareté pour l'interface, arrondis, son de vente) et des briques
  (`Theme.bouton` à ombre épaisse, `Theme.panneau`, `Theme.pastille`, `Theme.texte`).
  Les prochains écrans (carnet, sorcière, boutique) doivent s'en servir.
  `client/Inventaire.luau` : l'écran d'inventaire (voir plus bas).

## Structure de `ServerStorage/ModeleUsine`

Positions relatives au centre de la parcelle ; l'entrée est du côté -Z (`Apparition` en
(0, 3, -55), tournée vers +Z), la `Caisse` en (0, 0.7, -45).

- `Machines/` : machines présentes dès le départ (gratuites).
- `Achats/` : machines à acheter, déjà à leur place ; cachées puis posées à l'achat.
- `Boutons/` : un bouton par achat, **avec exactement le même nom**.
- `Barrieres/` : `Zone2` et `Zone3`, 4 murs en ForceField (hauteur 12, CanCollide) autour
  de la zone, avec un panneau « 🔒 Zone N » sur le mur avant. Disparaît avec l'achat du même nom.

Les trois zones sont des lignes parallèles ; les bonbons vont de +Z vers -Z, tapis à vitesse 8,
mélangeur en Z = 50, cuiseur 24, mouleur 2, emballeuse -20, boutons à X = ligne + 9.

Zone 1 (ligne en X = -40, point de vente en Z = -37) :

| Objet | Où | Prix | Effet | Revenu total après |
|---|---|---|---|---|
| Melangeur1A | Machines | gratuit | pâte de 4 $ toutes les 2 s | 2 $/s |
| Tapis1A → Tapis1D | Machines | gratuit | transport | |
| PointDeVente1 | Machines | gratuit | vend dans la caisse | |
| Cuiseur1 | Achats | 60 | valeur ×2 | 4 $/s |
| Mouleur1 | Achats | 250 | valeur ×2, forme cube | 8 $/s |
| Emballeuse1 | Achats | 1 000 | valeur ×2,5, matière Foil | 20 $/s |
| Melangeur1B | Achats | 3 500 | 2e mélangeur | 40 $/s |

Zones 2 (ligne X = 0) et 3 (ligne X = 40) : mêmes machines que la zone 1 (copies), avec un
mélangeur plus cher et un point de vente avancé en Z = -30 (dernier tapis raccourci) pour
laisser l'allée de devant libre. Les barrières couvrent Z de -36 à 59,5 et X de -16 à 16
(zone 2) / de 24 à 59,5 (zone 3). Le bouton `ZoneN` (orange, 5 × 5) est devant la barrière,
en (ligne + 10, 0.3, -41). L'achat `ZoneN` est un Model qui contient `MelangeurNA`,
`TapisNA` → `TapisND` et `PointDeVenteN`.

| Achat | Requiert | Prix | Effet | Revenu total après |
|---|---|---|---|---|
| Zone2 | Melangeur1B | 10 000 | chaîne de base, pâte de 80 $ / 2 s | 80 $/s |
| Cuiseur2 | Zone2 | 25 000 | ×2 | 120 $/s |
| Mouleur2 | Cuiseur2 | 60 000 | ×2 | 200 $/s |
| Emballeuse2 | Mouleur2 | 150 000 | ×2,5 | 440 $/s |
| Melangeur2B | Emballeuse2 | 400 000 | 2e mélangeur | 840 $/s |
| Zone3 | Melangeur2B | 900 000 | chaîne de base, pâte de 1 600 $ / 2 s | 1 640 $/s |
| Cuiseur3 | Zone3 | 800 000 | ×2 | 2 440 $/s |
| Mouleur3 | Cuiseur3 | 1 600 000 | ×2 | 4 040 $/s |
| Emballeuse3 | Mouleur3 | 3 000 000 | ×2,5 | 8 840 $/s |
| Melangeur3B | Emballeuse3 | 6 000 000 | 2e mélangeur | 16 840 $/s |

Durée de jeu calculée avec ces prix (sans temps de marche) : ≈ 1 h 53 (zone 1 ≈ 7 min,
zone 2 + achat de Zone3 ≈ 1 h 03, reste de la zone 3 ≈ 43 min). Les prix de la zone 3 ont
été baissés le 2026-10-02 (avant : 2 M / 4,5 M / 10 M / 25 M, soit ≈ 3 h 30). Avec toute l'usine, environ 50 bonbons
sont en jeu en même temps (limite : 80).

**Attention, ces durées datent d'avant la rareté.** Avec les chances actuelles, un bonbon vaut
en moyenne ×2,32 (pitié non comptée) : tous les revenus du tableau sont à multiplier par ≈ 2,3
et la durée tombe à ≈ 50 min. L'inventaire ne change pas la valeur d'un bonbon (même fonction
de prix), mais un bonbon gardé puis vendu après l'achat d'une machine de sa zone rapporte
plus (le prix suit les machines possédées au moment de la vente). Prix pas encore revus.

## Modèles des bonbons (`ServerStorage/ModelesBonbons`)

Un dossier par type, un Model par étape : `ModelesBonbons/<Type>/<Etape>`, avec
Type = `Fraise`, `Menthe`, `Or` et Etape = `Pate`, `Cuit`, `Moule`, `Emballe`.
**Les 3 types sont faits** (Fraise : 2026-10-02 ; Menthe et Or : mission autonome « nuit-auto »,
pas encore vus par l'utilisateur). Si un modèle manque, le bonbon garde l'**ancien rendu**
(boule que les machines déforment avec `CouleurBonbon`, `FormeBonbon`, `MatiereBonbon`).

- Le mélangeur choisit le type (attribut `TypeBonbon`, ex : `"Fraise"` sur `Melangeur1A`
  et `Melangeur1B`) et copie `<Type>/Pate`. Chaque cuiseur, mouleur et emballeuse a un
  attribut `EtapeBonbon` (`Cuit`, `Moule`, `Emballe`) : le bonbon est **remplacé** par le
  modèle de cette étape, au même endroit et à la même vitesse, et garde tous ses attributs
  (`Valeur`, `Rarete`, étapes franchies...).
- Le bonbon en jeu est le Model renommé `Bonbon` ; ses attributs sont sur le Model. Seul son
  `Corps` touche les zones des machines (`trouverBonbon` dans `Production` remonte au Model).

**Règles d'un modèle de bonbon** (les scripts ne lisent que ça, le reste est libre) :

| Quoi | Règle |
|---|---|
| Model | attributs `Type` et `Etape`, **PrimaryPart = `Corps`** |
| `Corps` | la **seule** pièce CanCollide (et CanTouch), taille 1 × 1 × 1 = taille historique des bonbons (ne pas changer, sinon la physique des tapis change). Ball pour Pate et Cuit (visible), Block invisible pour Moule et Emballe (comme l'ancien cube, pour que le cœur et la papillote ne roulent pas) |
| Autres pièces | CanCollide, CanTouch, CanQuery = false ; Massless = true ; soudées au Corps par un `WeldConstraint` ; **pas ancrées** |
| `Teinte = true` | sur les pièces qui prennent la couleur (et le Neon) de la rareté ; les détails (papier, reflets, pépins) n'en ont pas |
| Limites | 6 pièces maximum Corps compris ; pas de Highlight, lumière ni particules dans le modèle (la rareté les ajoute) |
| Sens | construit avec l'entrée de la parcelle vers -Z : le modèle est tourné comme la parcelle |

Couleurs de la Fraise : corps `#F0476B`, reflets `#FF9DB2`, papier `#FFE3EA`, pépins `#FFE9A8`.
Pate : boule + petit bout de pâte + reflet. Cuit : boule en Plastic (Reflectance 0,1) + reflet.
Moule : cœur à plat (2 disques + un carré tourné de 45°, épaisseur 0,45) + 2 pépins.
Emballe : cylindre couché (1,1 × 0,7) + 2 bouts de papier inclinés à 30° + 2 anneaux.
Testé : 80 bonbons Fraise à l'écran, 60 FPS côté serveur et côté écran, aucun bonbon tombé ni bloqué.

Menthe (corps `#2FCFA3`, reflets `#9BF3DA`, papier `#E4FFF6`) : Pate, Cuit et Emballe comme la
Fraise ; Moule = pastille à plat (disque Ø 1,05 × 0,45) + 3 rayures blanches + reflet.
Or (corps `#FFC21F`, reflets `#FFE585`, papier `#FFF5CC`) : Moule = étoile à plat de 5 branches
(blocs 0,27 × 0,45 × 0,6 partant du centre, toutes `Teinte`), la 1re branche vers -Z.
Testé (3 types, 80 bonbons, mélangeurs accélérés) : 60 FPS serveur, aucun bonbon tombé ni
bloqué, teinte de rareté seulement sur les pièces `Teinte`. FPS écran non mesuré (rendu de
Studio arrêté pendant le test).

## Rareté des bonbons

Tirée **sur le serveur** à la sortie du mélangeur (`Rarete.tirer`), enregistrée dans
l'attribut `Rarete` du bonbon (nom affiché, ex : `"Épique"`). La valeur est multipliée tout
de suite ; les machines multiplient ensuite, donc la rareté compte jusqu'à la vente.

| Rareté | Chance | × | Apparence |
|---|---|---|---|
| Commun | le reste (69,95 %) | 1 | couleurs de la chaîne, comme avant |
| Peu commun | 20 % | 2 | vert |
| Rare | 7 % | 5 | bleu, Glass, particules |
| Épique | 2,5 % | 15 | violet, Neon, particules, son |
| Légendaire | 0,5 % | 50 | or, Neon, particules, son, lumière, message au propriétaire |
| Mythique | 0,05 % | 500 | rose, Neon, particules, son, lumière, annonce à tout le serveur |

- À partir de Peu commun, la couleur (et la matière si la rareté en a une) de la rareté
  s'appliquent aux pièces `Teinte` du modèle (ancien rendu : passent avant celles des
  machines). Particules et lumière (portée 8, luminosité `Reglages.LuminositeLumiere` = 1)
  vont sur le `Corps` ; `Rarete.habiller` les remet à chaque changement de modèle,
  le son et les messages ne sont joués qu'une fois (`Rarete.appliquer`).
- Pas de `Highlight` (Roblox en affiche 31 au maximum à la fois).
- **Pitié** : attribut `CompteurPitie` du joueur = nombre de bonbons de suite sous Épique.
  À 150, le suivant est Épique. Sauvegardé (`CompteurPitie`, version 3).
- **Bonus de chance** : attribut `BonusChance` du joueur (0,5 = +50 %), multiplie les chances
  de tout ce qui est au-dessus de Commun. Rien ne le donne encore.
- Son : `rbxasset://sounds/electronicpingshort.wav` (fourni avec Roblox), bouche-trou.
- Testé sur 1 million de tirages : pourcentages conformes, jamais plus de 150 sous Épique.

## Inventaire

- Au point de vente : rareté ≥ seuil du joueur (`SeuilGarde`, défaut « Peu commun ») et
  place libre → le bonbon va dans l'inventaire ; inventaire plein → vendu dans la caisse
  (message « Inventaire plein » au plus toutes les 10 s) ; sinon vendu comme avant.
- Le prix de vente (automatique ou depuis l'inventaire) vient de `Prix.calculer`, **pas** de
  l'attribut `Valeur` du bonbon (qui n'est plus qu'indicatif) :
  `Reglages.Types[type].ValeurDepart × Multiplicateur des machines de Types[type].Machines
  possédées × rareté × mutation`, arrondi au $. Ex. Fraise Rare : 20 $ sans machine,
  200 $ avec les 3 ; Or Mythique : 800 000 $ → 8 000 000 $.
- Piles `"Type|Rareté|Mutation"` → quantité (mutation : seulement `Normal` pour l'instant).
  Capacité `Reglages.Inventaire.Capacite` = 50 (somme des quantités). Choix du seuil :
  Commun, Peu commun, Rare, Épique (`Reglages.Inventaire.ChoixSeuil`).
- **Écran** (`client/Inventaire.luau`, d'après `docs/design/Inventaire (ordinateur)` et
  `(téléphone, paysage)`) : bouton « Inventaire » à gauche à mi-hauteur + touche I ; la croix
  ou un clic sur le fond ferme. Piles triées par rareté décroissante puis quantité ; une pile
  sélectionnée (bordure violette) s'affiche dans le détail (« Vendre 1 », « Vendre les N »).
  « Tout vendre » demande confirmation s'il y a un Épique ou mieux. Son doux à la vente.
- Mise en page téléphone si `UserInputService.TouchEnabled` (tablette comprise), sinon
  ordinateur. Tailles en px de maquette (1080 × 628 / 700 × 334) + `UIScale`, bornée par
  `EchelleMin` = 0,87 pour garder textes ≥ 13 px et zones cliquables ≥ 44 px. Marge du haut
  = barre Roblox (≥ 58 px). Vérifié par calcul : 667 × 375, 844 × 390, 1024 × 768,
  1280 × 720 sans défaut ; à 1024 × 600 (petit écran d'ordinateur) le panneau mord de
  ≈ 12 px sur la bande du menu Roblox (limite acceptée).
- Icônes : `ViewportFrame` avec le modèle `<Type>/Moule` (copié dans
  `ReplicatedStorage/ModelesBonbons` par le serveur), teinté comme dans l'usine ; boule de
  `Reglages.Types[type].Couleur` si le modèle manque. Une seule caméra partagée ; seules les
  cartes visibles ont un bonbon 3D. `InterfaceInventaire.creer(conteneur, options)` permet
  de construire le panneau dans un cadre de test d'une taille d'écran simulée.

## Carnet de collection

- `server/Carnet.luau` : ensemble de clés `"Type|Rareté"` découvertes par joueur (3 types ×
  6 raretés = 18, d'après `Reglages.OrdreTypes` et `Reglages.Raretes`). Découverte quand un
  bonbon sort d'un mélangeur de l'usine du joueur (`Production.creerBonbon`) ou quand la
  sorcière le fabrique ; message « Nouveau dans le carnet » (canal `Annonce`). Le « Bonbon
  raté » n'y est pas. Canaux : `CarnetMaj` (serveur → écran : `{ Decouverts, Nombre, Total,
  Nouveau? }`), `DemanderCarnet`.
- Sauvegarde **version 4** : champ `Carnet = { ["Fraise|Rare"] = true }`. Migration 3 → 4 :
  le carnet est rempli avec les combinaisons présentes dans l'inventaire (rien de perdu).
- Écran `client/Carnet.luau` (maquette « Carnet de collection ») : grille types × raretés,
  découverts en couleur (bordure = couleur de rareté), sinon silhouette grise + « ? » ; barre
  de progression ; « N / 18 découverts » ; badge « Nouveau ! » jusqu'à la fermeture du carnet ;
  bouton « Carnet » sous « Inventaire » (pastille rose s'il y a du nouveau) + touche C.
  Ordinateur 1080 × 628, téléphone 700 × 336 ; mêmes règles d'échelle que l'inventaire.
- `client/Icones.luau` : icônes 3D communes (caméra partagée, `Icones.creer`,
  `Icones.remplir`, silhouette grise pour le carnet).

## Tester sans abîmer la vraie sauvegarde

- `Reglages.Test.RareteForcee = "Mythique"` : tous les bonbons sortent de cette rareté
  (seulement dans Studio). Remettre `nil` après.
- **Mode test** : l'attribut `TestSansSauvegarde = true` sur `ServerStorage` (seulement dans
  Studio) empêche toute écriture de sauvegarde (la lecture marche). Pour les tests de Claude,
  il est posé **dans le serveur de la partie en cours** (via MCP, juste après le lancement),
  jamais dans le fichier du jeu, pour qu'il ne reste pas activé par erreur.
- Pour tester des machines achetées sans toucher à l'argent du joueur : cloner `ModeleUsine`
  dans le Workspace sur un emplacement libre (sans boutons ni caisse démarrée) et appeler
  `Production` dessus.
- **DataStore de test** : l'attribut texte `DataStoreTest` sur `ServerStorage` (ex :
  `"Test_Inventaire"`) envoie toutes les lectures ET écritures dans ce DataStore-là. Ne marche
  **que dans Studio** (`RunService:IsStudio()`), jamais dans le jeu publié. Pour un test de
  sauvegarde / rechargement / migration : poser l'attribut en mode édition, y écrire une
  fausse sauvegarde, jouer, arrêter, relire, puis **retirer l'attribut** (vérifier qu'il est
  bien `nil` à la fin).
- Pour relire une sauvegarde juste après l'avoir écrite, utiliser `GetAsync` avec
  `DataStoreGetOptions.UseCache = false` : sinon Roblox renvoie une copie en cache vieille de
  quelques secondes (fausse alerte vue pendant les tests de B).
- Un module requis depuis l'outil MCP n'est **pas** le même que celui des scripts du jeu :
  modifier `Reglages` depuis MCP ne change pas l'usine du joueur. Côté écran, on peut
  écouter `InventaireMaj` et envoyer des demandes depuis MCP pour tester le serveur.

## Conventions

- **Un bouton et l'objet qu'il achète portent exactement le même nom** (c'est aussi le nom
  enregistré dans la sauvegarde : ne pas renommer un achat existant).
- Bouton : attribut `Prix` (obligatoire), `Titre`, `Description` (3e ligne du panneau),
  `Requiert` (nom de l'achat à faire avant que le bouton apparaisse).
- Une barrière (dans `Barrieres/`) porte le nom de l'achat qui la fait disparaître.
- **Une machine est un Model ; les scripts ne lisent que ses attributs et quelques pièces
  au nom précis. Tout le reste est décoratif et peut être remplacé librement** :

  | Role | Attributs | Pièce indispensable |
  |---|---|---|
  | `Melangeur` | `TypeBonbon` (Fraise/Menthe/Or, la valeur de départ est dans `Reglages.Types`), `Intervalle` | `Sortie` (la pâte apparaît juste dessous) |
  | `Tapis` | `Vitesse` | `Surface` (avance dans le sens de sa face avant) |
  | `Transformation` | `Etape`, `Multiplicateur`, `CouleurBonbon`, `FormeBonbon` (Boule/Cube/Cylindre), `MatiereBonbon` | `Zone` (boîte invisible, CanTouch) |
  | `PointDeVente` | — | `Zone` |

- Un bonbon est un Model (ou, ancien rendu, une Part) nommé `Bonbon` avec les attributs `Type`, `Rarete` et `Valeur` (indicative : le prix de vente vient de `Prix`), rangé dans le dossier
  `Bonbons` de l'usine. Il reçoit un attribut `true` par étape franchie (ex : `Cuisson`) :
  chaque étape ne s'applique qu'une fois.
- Les bonbons en boule roulent sur le tapis et avancent donc un peu moins vite que `Vitesse`.
- Toute la logique de jeu (argent, achats, tirages) se fait côté serveur, jamais côté client.
  Le client n'envoie que des demandes (RemoteEvents), que le serveur vérifie.
- Rien ne s'achète avec des Robux dans le chantier rareté / inventaire / carnet / sorcière.
- Tester dans Studio utilise la **vraie** sauvegarde de l'utilisateur. **Ne jamais la modifier
  pendant un test** : utiliser le mode test et une usine de test (voir plus haut), ou demander
  avant. L'utilisateur l'a demandé explicitement.

## Reste à faire

Chantier en cours (branche `rarete-inventaire`), en 4 sous-étapes. Après chacune :
test, mise à jour de `CLAUDE.md` et `IDEES.md`, liste de vérifications pour l'utilisateur,
puis **attendre son « commit »** avant la suivante.

- [x] A. Rareté (ci-dessus).
- [x] Modèles de bonbons : Fraise, Menthe et Or (Menthe et Or faits pendant « nuit-auto »,
  à valider visuellement par l'utilisateur).
- [x] B. Inventaire (ci-dessus) — en attente du « commit » de l'utilisateur.
- [ ] C. Carnet : combinaisons type + rareté découvertes, grille, compteur, « Nouveau ! ».
- [ ] D. Sorcière : 3 bonbons de même rareté (types mélangés possibles, le résultat prend
  le type de l'un des trois au hasard) → rareté supérieure ou « Bonbon raté » ; pitié après
  5 échecs ; une transformation à la fois ; fumée, son, 3 s, phrases.

Ensuite :
1. **Équilibrage** : revoir les prix avec la rareté (voir plus haut).
2. **Monétisation** : Game Passes et/ou Developer Products (par exemple multiplicateur
   d'argent, achat de monnaie).
