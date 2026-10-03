# Décor de la carte : sauvegarde du plan

Le décor n'existe **que dans Studio** (`Workspace/Decor`, et ses modèles de base dans
`ServerStorage/ModelesDecor`). Ni Rojo ni Git ne le gardent : ce fichier permet de le
reconstruire à l'identique si la place est perdue. Construit le 2026-10-03 d'après
`docs/design/Plan de la carte`, `Vue d'ambiance` et `Palette et ambiance`.

## Repères

- Centre de la carte = centre du hub = (0, 0, 0). Le dessus de l'herbe est à Y = 0,05.
- Parcelles (120 × 120), **mêmes valeurs que `EMPLACEMENTS` dans `Parcelles.server.luau`** :
  1 = (-140, 0, 115), 2 = (0, 0, 115), 3 = (140, 0, 115) ; 4, 5, 6 = mêmes X en Z = -115,
  tournées d'un demi-tour. Les entrées (côté -Z de chaque parcelle) regardent le hub ;
  elles sont en Z = ±55.
- Intérieur de la carte : X de -262 à 262, Z de -195 à 195.
- Départ (le `SpawnLocation`, déplacé depuis (0, 0,5, 0)) : (-235, 0,66, 0).

## Couleurs (palette de la maquette)

Herbe `#8FE04F` · falaise violette `#7B4FC9` · falaise rose `#D96FA8` · caramel `#E5B084`
(bord de la place `#C98F5E`) · chocolat `#6B3F2A` · lilas `#D9B3FF` · barbe à papa `#FFB3DA`
· lampadaires `#FFE27A` (Neon) · disque du Départ `#FF3EA5`.

## Règles respectées

Toutes les pièces sont ancrées, en SmoothPlastic, sans ombre portée (`CastShadow = false`),
avec CanCollide, CanQuery et CanTouch à false. **Exceptions** : `SolHerbe` et les 4 murs
invisibles, qui gardent leur collision. Un script de contrôle a vérifié les 345 pièces
(0 faute).

## Les 4 zones (+ fontaine importée et statue)

### 1. `1_SolEtBordure` (107 pièces)
- `SolHerbe` : 524 × 1 × 390, centre (0, -0,45, 0), collision active.
- `Murs/` : `MurNord`, `MurSud`, `MurEst`, `MurOuest`, invisibles, hauteur 80, épaisseur 4,
  juste au bord de l'intérieur de la carte (Z = ±197, X = ±264).
- `Falaises/` : 34 copies des modèles `FalaiseHaute` (28 de haut) et `FalaiseBasse` (20),
  en alternance. Modèle : `Corps` violet 60 × h × 20, `Bande` rose devant (vers l'intérieur),
  `Dessus` en herbe. Le point de référence est au bas du bloc. Positions (bas du bloc) :
  - nord (Z ≈ 210, tournées de 0°) et sud (Z ≈ -210, 180°) : 10 chacune, de X = -258,3 à
    258,3, tous les 57,4 ;
  - est (X ≈ 277, 90°) et ouest (X ≈ -277, -90°) : 7 chacune, de Z = -167,1 à 167,1,
    tous les 55,7 ;
  - une sur trois est reculée de 3 studs (bord moins droit).

### 2. `2_Hub` (19 pièces + la fontaine importée)
- `Place/` : `Bord` (disque Ø 76, dessus à 0,13) et `Place` (Ø 70, dessus à 0,16).
- `Fontaine` (au centre, remplacée le 2026-10-03) : la fontaine de chocolat **importée par
  l'utilisateur** (`assets/modeles/fontaine/chocolate-fountain.glb`). Import d'origine intact
  (gris, non ancré) : `ServerStorage/Imports/FontaineChocolat`.
  - 121 MeshParts, **9 608 triangles** (dont 6 048 pour les 36 boules de gouttes
    `dripbulb`), 4 vasques (`basin`, `tier1` à `tier3`) + petit socle au sommet.
  - **Échelle 9** (`Fontaine:ScaleTo(9)`) : 49,5 × 29,2 × 42,9 studs (base hexagonale),
    pivot sous la base, posé en (0, 0,16, 0). L'ancienne faisait 26 de large.
  - Couleurs remises d'après les matériaux du .glb (perdues à l'import) : lavande `#B79AE8`,
    violet `#8A5FD6`, chocolat `#6B3A22` (Reflectance 0,08), caramel `#9A5F3E` ; SmoothPlastic.
  - Collision seulement sur `step_1`, `step_2`, `basin_floor`, `basin_wall_outer`,
    `basin_rim` (CollisionFidelity par défaut : le creux du bassin est « plein »). Tout le
    reste : CanCollide, CanQuery, CanTouch false. Tout ancré.
  - Ancienne fontaine en formes simples : `ServerStorage/Decor_Anciens/Fontaine`.
- `Chemins/` (largeur 10, caramel) :
  - `VersParcelle_0_±1` : tout droit de Z = ±30 à ±58 (parcelles du milieu) ;
  - `VersParcelle_±140_±1_A` : de (±25, ±15) jusqu'au coude (±140, ±33) ;
  - `..._B` : du coude jusqu'à (±140, ±58) ;
  - `Coude_...` : un disque Ø 10 à chaque coude ;
  - `VersDepart` : de X = -30 à X = -235 en Z = 0.
  Les hauteurs des dessus (0,10 / 0,12 / 0,14 / 0,16) sont décalées exprès, pour éviter
  le scintillement entre surfaces superposées.
- `Depart/` : `Anneau` blanc Ø 20 et `Disque` rose Ø 17 sous le `SpawnLocation`.

### 3. `3_Decor` (170 pièces), copies de 4 modèles de base
| Modèle (`ServerStorage/ModelesDecor`) | Pièces | Copies |
|---|---|---|
| `Sucette` (bâton, disque rouge `#FF4F6D`, 2 raies blanches), ≈ 15,5 de haut | 4 | 12 |
| `ArbreBarbeAPapa` (tronc + 3 cubes rose et lilas), ≈ 13 de haut | 4 | 17 |
| `Champignon` (pied blanc, chapeau violet `#A855F7`) | 2 | 15 |
| `Lampadaire` (poteau rose, boule Neon, **sans** vraie lumière) | 2 | 12 |

Positions (point de référence au sol, rotation autour de la verticale, échelle) :

| Modèle | Position | Échelle |
|---|---|---|
| Sucette | (-235, 16) 0° et (-235, -16) 180° (encadrent le Départ) | 1,6 |
| Sucette | (±210, ±185) et (±70, ±185), côté nord 0°, côté sud 180° (derrière les parcelles) | 0,9 à 1,1 |
| Sucette | (240, ±30) 90° | 1,3 |
| ArbreBarbeAPapa | (±70, ±64) et (±70, ±168) (entre les parcelles, côté hub et côté fond) | 0,9 à 1,1 |
| ArbreBarbeAPapa | (-230, ±42), (230, 0), (225, ±45), (-245, ±120), (245, ±110) | 0,9 à 1,1 |
| Champignon | 3 groupes de 3 autour de (-95, ±46), (95, ±46) et (204, 20) | 0,8 à 1,4 |
| Lampadaire | (-75 / -120 / -165 / -205, ±9) le long du chemin du Départ | 1 |
| Lampadaire | (±29, ±29) autour de la place | 1 |

Les angles exacts des copies tournées au hasard ne comptent pas (tirage `Random.new(7)`).

### 4. `4_EnveloppeParcelles` (42 pièces)
6 copies du modèle `EnveloppeParcelle` (nommées `Parcelle1` à `Parcelle6`), posées
exactement sur les 6 `EMPLACEMENTS`. Le modèle a son centre au milieu de la parcelle :
- bordure rose de 0,8 de haut et 1,5 d'épaisseur, à 60,75 du centre (juste autour du sol
  de 120 × 120) ;
- ouverture de 24 studs à l'entrée (`BordAvantGauche`, `BordAvantDroit`) ;
- `Poteau` et `Panneau` « Parcelle N » (SurfaceGui, FredokaOne) en (20, -64) dans le repère
  de la parcelle : dehors, à droite de l'entrée, tourné vers le hub.

### `Statue` (21 pièces, ajoutée le 2026-10-03)
Statue de l'avatar de l'utilisateur, **dans le coin sud-ouest, en (-235, 0,05, -172), tournée
vers le centre du hub**. Choisi parce que le `SpawnLocation` regarde vers -Z : à
l'apparition, le joueur la voit droit devant, à 172 studs (au coin nord-est, elle était à
485 studs et cachée par les parcelles). Faite à partir du modèle « Statue » du Workspace ;
**la copie d'origine intacte (avec Humanoid) est dans `ServerStorage/Statue`** et sert à la
refaire. Un doublon (statue + piédestal) fait pendant le travail est rangé dans
`ServerStorage/Decor_Anciens` (`StatueDoublon`, `PiedestalDoublon`).
- `Piedestal` (seule partie avec collision ; la plaque n'en a pas) : `Socle` violet
  10 × 1,2 × 10, `Colonne` lilas 7,5 × 5 × 7,5, `Dessus` violet 9 × 1 × 9, posé sur l'herbe,
  dessus à Y = 7,25 ; `Plaque` dorée `#FFC21F` 5,4 × 1,8 sur la face avant (vers le hub),
  texte « Le Grand Confiseur » (SurfaceGui, FredokaOne, `#6B3F2A`).
- `Statue` : 17 MeshParts (corps R15, chapeau `CircleAccessory`, sourcils `Brows`),
  échelle 3 (17,5 studs de haut), Marble `#EEE8E1` partout, sans texture, ancrées, sans
  collision. Pivot sous les pieds, au centre du dessus du piédestal. Retirés : Humanoid
  (avec Animator, animations, description), script `Animate`, articulations et contraintes,
  `Shirt`, `Pants`, `BodyColors`, la veste en couches `Accessory (Business Suit)`,
  `SurfaceAppearance`, textures, valeurs d'échelle d'avatar. Gardés (invisibles) : attaches,
  `WrapLayer`/`WrapTarget` (forme des sourcils).

## Désactiver ou supprimer

- Cacher tout le décor : déplacer `Workspace/Decor` dans `ServerStorage` (ou le supprimer).
  Les parcelles marchent sans lui. Attention : sans `SolHerbe` et les murs, on peut de
  nouveau sortir de la carte par la Baseplate.
- Si on change `EMPLACEMENTS`, il faut déplacer `4_EnveloppeParcelles`, les chemins et les
  arbres entre les parcelles.
