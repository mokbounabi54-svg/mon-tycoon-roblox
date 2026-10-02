# Tycoon d'usine à bonbons (Roblox)

Jeu Roblox de type tycoon : le joueur construit une usine à bonbons. Des machines
font tomber des bonbons sur un collecteur, le joueur ramasse l'argent du collecteur
et l'utilise pour acheter de nouvelles machines grâce à des boutons posés au sol.

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
  n'est pas recopié dans les fichiers : il faut le reporter à la main dans `src/`
  ou dans `default.project.json`.
- `default.project.json` décrit les objets du jeu : la Baseplate, le dossier
  `Workspace/Parcelles` (vide au départ) et le modèle d'usine `ServerStorage/ModeleUsine`.
- Rojo ne crée pas toujours un **nouveau service** (ex : `ServerStorage`) pendant une
  session déjà connectée : il faut alors reconnecter le plugin Rojo dans Studio.
- `src/server/` → `ServerScriptService/Server` (scripts serveur)
- `src/client/` → `StarterPlayer/StarterPlayerScripts/Client` (scripts client)
- `src/shared/` → `ReplicatedStorage/Shared` (modules partagés)

## État d'avancement

Déjà fait (scripts dans `src/server/`) :

- `Leaderstats.server.luau` : crée la valeur `Argent` de chaque joueur (affichée en haut à droite).
- `Parcelles.server.luau` : **une parcelle par joueur**. À l'arrivée d'un joueur, il copie
  `ServerStorage/ModeleUsine` sur un emplacement libre (6 emplacements, liste `EMPLACEMENTS`),
  la range dans `Workspace/Parcelles`, affiche « Usine de <nom> » et fait apparaître le
  joueur sur la Part `Apparition`. Au départ du joueur, l'usine est détruite et l'emplacement libéré.
- `Usine/` : des ModuleScripts appelés par `Parcelles` pour chaque usine :
  - `Collecteur.luau` : accumule de l'argent tout seul et reçoit la valeur des bonbons ;
    seul le propriétaire récupère le stock en marchant dessus.
  - `Boutons.luau` : boutons d'achat (attribut `Prix`) ; seul le propriétaire peut acheter,
    l'objet apparaît dans son usine et le bouton disparaît. Clignote en rouge si pas assez d'argent.
  - `Machines.luau` : une machine achetée (attributs `ValeurBonbon`, `Intervalle`) fait
    tomber des bonbons, rangés dans l'usine.

- `Sauvegarde.luau` : lit et écrit la sauvegarde d'un joueur dans le DataStore `Joueurs_v1`
  (`{ Argent, Achats }`, avec 3 essais en cas d'erreur). `Parcelles` charge la sauvegarde à
  l'arrivée et sauvegarde au départ, toutes les 2 minutes et à l'arrêt du serveur (`BindToClose`).
  Si le chargement échoue, le joueur joue quand même mais n'est jamais sauvegardé, pour ne
  pas écraser sa vraie sauvegarde. L'argent en attente dans le collecteur n'est pas sauvegardé.
  Pour tester dans Studio, il faut activer « Activer l'accès de Studio aux services API ».

Une seule machine existe pour l'instant (`MachineABonbons`).
Pour modifier l'usine (ajouter une machine, déplacer un objet), on modifie le modèle
`ServerStorage/ModeleUsine` : les positions y sont relatives au centre de la parcelle (0, 0, 0).

## Conventions

- **Un bouton et l'objet qu'il achète portent exactement le même nom.** Le bouton va
  dans `ModeleUsine/Boutons`, l'objet dans `ModeleUsine/Achats`, déjà placé à sa position finale.
- Un bouton doit avoir un attribut `Prix` (nombre).
- Une machine doit avoir un attribut `ValeurBonbon` (nombre), et optionnellement
  `Intervalle` (secondes). Si c'est un Model, elle contient une Part nommée `Sortie`.
- Les bonbons sont des Parts nommées `Bonbon` avec un attribut `Valeur`.
- Toute la logique de jeu (argent, achats) se fait côté serveur, jamais côté client.

## Reste à faire

1. **Monétisation** : Game Passes et/ou Developer Products (par exemple multiplicateur
   d'argent, achat de monnaie).
