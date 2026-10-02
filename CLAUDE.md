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
- `Sauvegarde.luau` : DataStore `Joueurs_v1`, format `{ Version = 2, Argent, Achats }`,
  3 essais en cas d'erreur. Si le chargement échoue, le joueur n'est jamais sauvegardé.
  `migrer` convertit les sauvegardes version 1 : les 10 anciennes machines (MachineABonbons…)
  sont remboursées à leur prix. Pour un futur changement de format : augmenter `VERSION`
  et ajouter un cas dans `migrer`.
- `Usine/Production.luau` : fait fonctionner chaque machine d'après son attribut `Role`
  (voir plus bas). Groupes de collision : les bonbons ne touchent ni les autres bonbons ni les
  joueurs. Physique des bonbons calculée par le serveur, 80 bonbons max par usine, 30 s de vie.
- `Usine/Caisse.luau` : la Part `Caisse` garde l'argent en attente dans son attribut `Stock`
  (rempli par les points de vente) ; seul le propriétaire le récupère en marchant dessus.
  L'argent en attente n'est pas sauvegardé.
- `Usine/Boutons.luau` : boutons d'achat ; seul le propriétaire peut acheter.

## Structure de `ServerStorage/ModeleUsine`

Positions relatives au centre de la parcelle ; l'entrée est du côté -Z (`Apparition` en
(0, 3, -55), tournée vers +Z), la `Caisse` en (0, 0.7, -45).

- `Machines/` : machines présentes dès le départ (gratuites).
- `Achats/` : machines à acheter, déjà à leur place ; cachées puis posées à l'achat.
- `Boutons/` : un bouton par achat, **avec exactement le même nom**.

Zone 1 (ligne en X = -40, les bonbons vont de +Z vers -Z, tapis à vitesse 8) :

| Objet | Où | Prix | Effet | Revenu total après |
|---|---|---|---|---|
| Melangeur1A | Machines | gratuit | pâte de 4 $ toutes les 2 s | 2 $/s |
| Tapis1A → Tapis1D | Machines | gratuit | transport | |
| PointDeVente1 | Machines | gratuit | vend dans la caisse | |
| Cuiseur1 | Achats | 60 | valeur ×2 | 4 $/s |
| Mouleur1 | Achats | 250 | valeur ×2, forme cube | 8 $/s |
| Emballeuse1 | Achats | 1 000 | valeur ×2,5, matière Foil | 20 $/s |
| Melangeur1B | Achats | 3 500 | 2e mélangeur | 40 $/s |

Prévu ensuite (plan validé) : zone 2 (X = 0) débloquée pour 10 000 $ et zone 3 (X = 40)
pour 900 000 $, chacune avec mélangeur, cuiseur, mouleur, emballeuse, 2e mélangeur et une
barrière qui disparaît à l'achat. Prix visés : Cuiseur2 25 000, Mouleur2 60 000,
Emballeuse2 150 000, Melangeur2B 400 000, Zone3 900 000, Cuiseur3 2 M, Mouleur3 4,5 M,
Emballeuse3 10 M, Melangeur3B 25 M. Revenus de base : zone 2 = 40 $/s, zone 3 = 800 $/s
(×20 avec toute la chaîne). Durée totale visée ≈ 1 h 35.

## Conventions

- **Un bouton et l'objet qu'il achète portent exactement le même nom** (c'est aussi le nom
  enregistré dans la sauvegarde : ne pas renommer un achat existant).
- Bouton : attribut `Prix` (obligatoire), `Titre`, `Description` (3e ligne du panneau),
  `Requiert` (nom de l'achat à faire avant que le bouton apparaisse).
- **Une machine est un Model ; les scripts ne lisent que ses attributs et quelques pièces
  au nom précis. Tout le reste est décoratif et peut être remplacé librement** :

  | Role | Attributs | Pièce indispensable |
  |---|---|---|
  | `Melangeur` | `ValeurDepart`, `Intervalle` | `Sortie` (la pâte apparaît juste dessous) |
  | `Tapis` | `Vitesse` | `Surface` (avance dans le sens de sa face avant) |
  | `Transformation` | `Etape`, `Multiplicateur`, `CouleurBonbon`, `FormeBonbon` (Boule/Cube/Cylindre), `MatiereBonbon` | `Zone` (boîte invisible, CanTouch) |
  | `PointDeVente` | — | `Zone` |

- Un bonbon est une Part nommée `Bonbon` avec un attribut `Valeur`, rangée dans le dossier
  `Bonbons` de l'usine. Il reçoit un attribut `true` par étape franchie (ex : `Cuisson`) :
  chaque étape ne s'applique qu'une fois.
- Les bonbons en boule roulent sur le tapis et avancent donc un peu moins vite que `Vitesse`.
- Toute la logique de jeu (argent, achats) se fait côté serveur, jamais côté client.
- Tester dans Studio utilise la **vraie** sauvegarde de l'utilisateur : la remettre dans
  son état d'origine après un test.

## Reste à faire

1. **Zones 2 et 3** (voir le plan plus haut), quand l'utilisateur aura testé la zone 1.
2. **Monétisation** : Game Passes et/ou Developer Products (par exemple multiplicateur
   d'argent, achat de monnaie).
