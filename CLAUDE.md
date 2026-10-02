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

## Architecture

- `Leaderstats.server.luau` : crée la valeur `Argent` de chaque joueur.
- `Parcelles.server.luau` : **une parcelle de 120 × 120 par joueur** (6 emplacements, liste
  `EMPLACEMENTS`, espacés de 130). Charge la sauvegarde, copie `ModeleUsine` sur un emplacement
  libre, démarre la caisse, la production et les boutons, fait apparaître le joueur sur
  `Apparition`. Sauvegarde au départ, toutes les 2 minutes et à l'arrêt du serveur (`BindToClose`).
- `Sauvegarde.luau` : DataStore `Joueurs_v2` (`Joueurs_v1` = ancien, abandonné le 2026-10-02, données laissées intactes), format `{ Version = 2, Argent, Achats }`,
  3 essais en cas d'erreur. Si le chargement échoue, le joueur n'est jamais sauvegardé.
  `migrer` convertit les sauvegardes version 1 : les 10 anciennes machines (MachineABonbons…)
  sont remboursées à leur prix. Pour un futur changement de format : augmenter `VERSION`
  et ajouter un cas dans `migrer`.
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
  (`Remotes.obtenir(nom)`). Existant : `Annonce` (serveur → écran : texte, couleur).
- `shared/Reglages.luau` : **le** module de réglages (raretés, pitié, réglages de test).
  Tous les chiffres d'équilibrage vont ici, pas dans le code.
- `client/init.client.luau` : démarre les modules d'interface rangés à côté de lui.
  `client/Annonces.luau` : messages en haut de l'écran (4 s puis fondu).

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
et la durée tombe à ≈ 50 min. L'inventaire (sous-étape B) changera encore ce calcul, car les
bonbons gardés ne sont plus vendus automatiquement. Prix pas encore revus.

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
  passent avant celles des machines ; les machines changent toujours la forme.
- Pas de `Highlight` (Roblox en affiche 31 au maximum à la fois).
- **Pitié** : attribut `CompteurPitie` du joueur = nombre de bonbons de suite sous Épique.
  À 150, le suivant est Épique. Pas encore sauvegardé (prévu en version 3, sous-étape B).
- **Bonus de chance** : attribut `BonusChance` du joueur (0,5 = +50 %), multiplie les chances
  de tout ce qui est au-dessus de Commun. Rien ne le donne encore.
- Son : `rbxasset://sounds/electronicpingshort.wav` (fourni avec Roblox), bouche-trou.
- Testé sur 1 million de tirages : pourcentages conformes, jamais plus de 150 sous Épique.

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
- Un module requis depuis l'outil MCP n'est **pas** le même que celui des scripts du jeu :
  modifier `Reglages` depuis MCP ne change pas l'usine du joueur.

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
  | `Melangeur` | `ValeurDepart`, `Intervalle` | `Sortie` (la pâte apparaît juste dessous) |
  | `Tapis` | `Vitesse` | `Surface` (avance dans le sens de sa face avant) |
  | `Transformation` | `Etape`, `Multiplicateur`, `CouleurBonbon`, `FormeBonbon` (Boule/Cube/Cylindre), `MatiereBonbon` | `Zone` (boîte invisible, CanTouch) |
  | `PointDeVente` | — | `Zone` |

- Un bonbon est une Part nommée `Bonbon` avec les attributs `Valeur` et `Rarete`, rangée dans le dossier
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
- [ ] B. Inventaire : seuil de garde (défaut Peu commun), piles `"Type|Rareté|Mutation"`,
  capacité 50, plein → vendu dans la caisse avec message, interface Vendre / Tout vendre,
  sauvegarde version 3 (+ `CompteurPitie`) avec migration depuis la version 2.
  Type = saveur de la zone (Fraise, Menthe, Or). Prix d'un bonbon gardé calculé à la vente :
  valeur de départ du type × machines possédées dans la zone × rareté × mutation.
- [ ] C. Carnet : combinaisons type + rareté découvertes, grille, compteur, « Nouveau ! ».
- [ ] D. Sorcière : 3 bonbons de même rareté (types mélangés possibles, le résultat prend
  le type de l'un des trois au hasard) → rareté supérieure ou « Bonbon raté » ; pitié après
  5 échecs ; une transformation à la fois ; fumée, son, 3 s, phrases.

Ensuite :
1. **Équilibrage** : revoir les prix avec la rareté (voir plus haut).
2. **Monétisation** : Game Passes et/ou Developer Products (par exemple multiplicateur
   d'argent, achat de monnaie).
