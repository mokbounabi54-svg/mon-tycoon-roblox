-- Tous les chiffres du jeu qu'on a envie de régler (chances, multiplicateurs...).
-- Modifier ce fichier suffit : les scripts ne contiennent pas ces valeurs.
-- Rangé dans ReplicatedStorage : le serveur ET l'écran du joueur peuvent le lire.
-- Mais seul le serveur décide (tirages, argent) : modifier ce module côté joueur
-- ne permet pas de tricher.

local Reglages = {}

--------------------------------------------------------------------------------
-- RARETÉ DES BONBONS
--------------------------------------------------------------------------------

-- Du plus courant au plus rare. L'ordre compte : il sert à comparer les raretés
-- (pitié, et plus tard seuil de l'inventaire et sorcière).
--   Nom            : nom affiché, et nom enregistré dans l'attribut "Rarete" du bonbon
--   Chance         : en % ; Commun n'en a pas, il prend « le reste » (100 - les autres)
--   Multiplicateur : la valeur du bonbon est multipliée par ce nombre
--   Couleur        : couleur des pièces "Teinte" du bonbon (ancien rendu : remplace
--                    celle des machines). nil = garder la couleur du modèle
--   Matiere        : matière des pièces "Teinte" (nil = garder celle du modèle)
--   Particules     : des étincelles autour du bonbon
--   Son            : joué quand le bonbon apparaît (nil = pas de son)
--   Lumiere        : le bonbon éclaire autour de lui (portée en studs, nil = pas de lumière)
--   MessageProprietaire : message à l'écran du propriétaire de l'usine
--   AnnonceServeur      : message à l'écran de TOUS les joueurs du serveur
--                         ({joueur} est remplacé par le nom du joueur)
Reglages.Raretes = {
	{
		Nom = "Commun",
		Multiplicateur = 1,
	},
	{
		Nom = "Peu commun",
		Chance = 20,
		Multiplicateur = 2,
		Couleur = Color3.fromRGB(90, 220, 110),
	},
	{
		Nom = "Rare",
		Chance = 7,
		Multiplicateur = 5,
		Couleur = Color3.fromRGB(60, 140, 255),
		Matiere = "Glass",
		Particules = true,
	},
	{
		Nom = "Épique",
		Chance = 2.5,
		Multiplicateur = 15,
		Couleur = Color3.fromRGB(170, 80, 255),
		Matiere = "Neon",
		Particules = true,
		Son = "rbxasset://sounds/electronicpingshort.wav",
	},
	{
		Nom = "Légendaire",
		Chance = 0.5,
		Multiplicateur = 50,
		Couleur = Color3.fromRGB(255, 190, 40),
		Matiere = "Neon",
		Particules = true,
		Son = "rbxasset://sounds/electronicpingshort.wav",
		Lumiere = 8,
		MessageProprietaire = "✨ Bonbon LÉGENDAIRE ! (valeur ×50)",
	},
	{
		Nom = "Mythique",
		Chance = 0.05,
		Multiplicateur = 500,
		Couleur = Color3.fromRGB(255, 50, 120),
		Matiere = "Neon",
		Particules = true,
		Son = "rbxasset://sounds/electronicpingshort.wav",
		Lumiere = 8,
		AnnonceServeur = "🌟 {joueur} a obtenu un bonbon MYTHIQUE ! (valeur ×500)",
	},
}

-- Luminosité (Brightness) de la lumière des raretés qui en ont une
Reglages.LuminositeLumiere = 1

-- Pitié : si les "Nombre" derniers bonbons d'un joueur étaient tous en dessous
-- de "Rarete", le suivant est garanti de cette rareté.
-- Le compteur est l'attribut "CompteurPitie" du joueur.
Reglages.Pitie = {
	Rarete = "Épique",
	Nombre = 150,
}

-- Bonus de chance : attribut "BonusChance" du joueur (0 = aucun, 0.5 = +50 %).
-- Il multiplie la chance de toutes les raretés au-dessus de Commun
-- (Commun baisse d'autant). Rien ne le donne encore : à brancher plus tard.

--------------------------------------------------------------------------------
-- TYPES DE BONBONS ET PRIX
--------------------------------------------------------------------------------

-- Un type par zone. Le mélangeur choisit le type avec son attribut "TypeBonbon".
--   ValeurDepart : valeur de la pâte qui sort du mélangeur (avant rareté et machines)
--   Machines     : les machines de la zone qui multiplient la valeur (leur attribut
--                  "Multiplicateur" est lu dans l'usine du joueur, seulement s'il les possède)
--   Couleur      : couleur du bonbon quand il n'a pas encore de modèle (icônes)
--
-- PRIX D'UN BONBON (une seule formule, pour la vente automatique ET l'inventaire) :
--   ValeurDepart × multiplicateurs des machines possédées × rareté × mutation
Reglages.Types = {
	Fraise = {
		ValeurDepart = 4,
		Machines = { "Cuiseur1", "Mouleur1", "Emballeuse1" },
		Couleur = Color3.fromHex("F0476B"),
	},
	Menthe = {
		ValeurDepart = 80,
		Machines = { "Cuiseur2", "Mouleur2", "Emballeuse2" },
		Couleur = Color3.fromHex("2FCFA3"),
	},
	Or = {
		ValeurDepart = 1600,
		Machines = { "Cuiseur3", "Mouleur3", "Emballeuse3" },
		Couleur = Color3.fromHex("FFC21F"),
	},
}

-- Mutations (à venir) : nom -> multiplicateur. "Normal" = pas de mutation.
Reglages.Mutations = {
	Normal = 1,
}

--------------------------------------------------------------------------------
-- INVENTAIRE
--------------------------------------------------------------------------------

Reglages.Inventaire = {
	Capacite = 50, -- nombre total de bonbons qu'on peut garder
	SeuilParDefaut = "Peu commun", -- on garde les bonbons de cette rareté et au-dessus
	ChoixSeuil = { "Commun", "Peu commun", "Rare", "Épique" }, -- boutons « Garder à partir de »
	DelaiMessagePlein = 10, -- secondes minimum entre deux messages « Inventaire plein »
	DelaiEntreDemandes = 0.15, -- secondes minimum entre deux demandes d'un joueur (anti-spam)
}

--------------------------------------------------------------------------------
-- RÉGLAGES DE TEST (ne marchent QUE dans Studio, jamais dans le vrai jeu)
--------------------------------------------------------------------------------

Reglages.Test = {
	-- Mettre un nom de rareté (ex : "Mythique") pour que TOUS les bonbons
	-- sortent avec cette rareté. nil = tirage normal.
	RareteForcee = nil,
}

return Reglages
