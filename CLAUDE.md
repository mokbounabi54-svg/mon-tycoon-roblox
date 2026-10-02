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
- `default.project.json` décrit les objets du Workspace (Baseplate, Collecteur,
  dossiers `Boutons` et `Achats`) et leurs attributs.
- `src/server/` → `ServerScriptService/Server` (scripts serveur)
- `src/client/` → `StarterPlayer/StarterPlayerScripts/Client` (scripts client)
- `src/shared/` → `ReplicatedStorage/Shared` (modules partagés)

## État d'avancement

Déjà fait (scripts dans `src/server/`) :

- `Leaderstats.server.luau` : crée la valeur `Argent` de chaque joueur (affichée en haut à droite).
- `Collecteur.server.luau` : le collecteur accumule de l'argent tout seul et reçoit la
  valeur des bonbons qui le touchent ; un joueur qui marche dessus récupère tout le stock.
- `Boutons.server.luau` : boutons d'achat avec un attribut `Prix` ; l'objet acheté
  apparaît et le bouton disparaît. Le bouton clignote en rouge si le joueur n'a pas assez d'argent.
- `Machines.server.luau` : une fois achetée, une machine (attributs `ValeurBonbon`
  et `Intervalle`) fait tomber des bonbons vers le collecteur.

Une seule machine existe pour l'instant (`MachineABonbons`).

Limite actuelle : il n'y a qu'une seule usine, partagée par tous les joueurs
(un seul collecteur, des achats communs).

## Conventions

- **Un bouton et l'objet qu'il achète portent exactement le même nom.** Le bouton va
  dans `Workspace/Boutons`, l'objet dans `Workspace/Achats`, déjà placé à sa position finale.
- Un bouton doit avoir un attribut `Prix` (nombre).
- Une machine doit avoir un attribut `ValeurBonbon` (nombre), et optionnellement
  `Intervalle` (secondes). Si c'est un Model, elle contient une Part nommée `Sortie`.
- Les bonbons sont des Parts nommées `Bonbon` avec un attribut `Valeur`.
- Toute la logique de jeu (argent, achats) se fait côté serveur, jamais côté client.

## Reste à faire

1. **Parcelles par joueur** : chaque joueur reçoit sa propre usine (collecteur,
   boutons, machines) à son arrivée, et la libère quand il part.
2. **Sauvegarde DataStore** : sauvegarder l'argent et les achats de chaque joueur
   pour les retrouver à la prochaine connexion.
3. **Monétisation** : Game Passes et/ou Developer Products (par exemple multiplicateur
   d'argent, achat de monnaie).
