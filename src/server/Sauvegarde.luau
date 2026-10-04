-- Lecture et écriture des sauvegardes des joueurs dans un DataStore.
--
-- Un DataStore est une sorte de grand tableau rangé chez Roblox, qui garde
-- les données même quand le serveur s'éteint. Chaque joueur a sa propre case,
-- repérée par une "clé" construite avec son UserId.
--
-- Une sauvegarde ressemble à ça (version 6) :
--   {
--     Version = 6, Argent = 120, Achats = { "Cuiseur1", "Mouleur1" },
--     Inventaire = { ["Fraise|Rare|Normal"] = 4 },   -- les piles de bonbons gardés
--     SeuilGarde = "Peu commun",                     -- garder à partir de cette rareté
--     CompteurPitie = 37,                            -- bonbons de suite sous Épique
--     Carnet = { ["Fraise|Rare"] = true },           -- version 4 : combinaisons découvertes
--     PitieSorciere = { ["Rare"] = 2 },              -- version 5 : échecs de suite par palier
--     Ingredients = {                                -- version 6 : mode hybride
--       Panier = { Fraise = 12 },                    --   ce que le joueur porte
--       Reserve = { Fraise = 40 },                   --   le bac de son usine
--       CadeauRecu = true,                           --   cadeau de départ déjà donné ?
--     },
--   }
--
-- "Version" indique le format de la sauvegarde. Quand le jeu change beaucoup,
-- on augmente VERSION et on convertit les anciennes sauvegardes (voir migrer).
--
-- Parler au DataStore peut échouer (problème réseau, trop de demandes...).
-- On utilise donc pcall pour attraper l'erreur au lieu de planter, et on
-- réessaie plusieurs fois avant d'abandonner.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local ModeDebug = require(script.Parent:WaitForChild("ModeDebug"))

local NOM_DATASTORE = "Joueurs_v2" -- changer ce nom repart de sauvegardes vides
local NOMBRE_ESSAIS = 3
local ATTENTE_ENTRE_ESSAIS = 2 -- secondes

local VERSION = 6

-- Version 1 : les 10 anciennes machines à bonbons, avec leur prix.
-- Elles n'existent plus : on rembourse leur prix au joueur.
local ANCIENNES_MACHINES = {
	MachineABonbons = 50,
	MachineASucettes = 150,
	MachineAGuimauves = 400,
	MachineACaramels = 1000,
	MachineAChocolats = 2500,
	MachineAReglisse = 6000,
	MachineADragees = 15000,
	MachineANougats = 40000,
	MachineAMacarons = 100000,
	MachineArcEnCiel = 250000,
}

local Sauvegarde = {}

-- GetDataStore échoue si l'accès aux API n'est pas activé dans Studio :
-- on le prévient tout de suite dans la sortie au lieu de planter le script.
local okDataStore, dataStore = pcall(function()
	return DataStoreService:GetDataStore(NOM_DATASTORE)
end)
if not okDataStore then
	warn("DataStore indisponible, les sauvegardes sont désactivées : " .. tostring(dataStore))
	dataStore = nil
end

local function cle(userId)
	return "joueur_" .. userId
end

-- DataStore de test (SEULEMENT dans Studio, jamais dans le jeu publié) :
-- si ServerStorage a un attribut texte "DataStoreTest" (ex : "Test_Joueurs"),
-- toutes les lectures et écritures vont dans ce DataStore-là au lieu du vrai.
-- On peut ainsi tester sauvegarde, rechargement et migration sans toucher aux vraies parties.
-- Dans le jeu publié, RunService:IsStudio() vaut false : l'attribut est ignoré.
-- En mode debug (voir ModeDebug), c'est TOUJOURS le DataStore de test.
--
-- La décision est dans une petite fonction à part, qui reçoit « est-on dans Studio ? »
-- en paramètre : on peut ainsi vérifier par un test que, HORS de Studio, l'attribut est
-- ignoré (dans Studio, RunService:IsStudio() répond toujours true).
-- Renvoie le nom du DataStore à utiliser (nil = aucun) et true si c'est un DataStore de test.
function Sauvegarde.choisirNom(estStudio, nomTest, debugActif, nomDebug)
	if debugActif then
		nomTest = nomDebug
	end
	if estStudio and typeof(nomTest) == "string" and nomTest ~= "" then
		return nomTest, true
	end
	if debugActif then
		return nil, false -- ne devrait jamais arriver : en mode debug, on ne touche pas au vrai DataStore
	end
	return NOM_DATASTORE, false
end

-- Vrai si l'attribut DataStoreTest doit être signalé comme IGNORÉ (jeu publié, attribut posé).
-- Fonction pure, comme choisirNom, pour pouvoir la tester avec un faux « pas dans Studio ».
function Sauvegarde.attributIgnore(estStudio, nomTest)
	return not estStudio and nomTest ~= nil
end

local avertissementDonne = false -- le warn n'est affiché qu'une fois par serveur

-- Renvoie le DataStore et son nom.
local function choisirDataStore()
	local estStudio = RunService:IsStudio()
	local nomTest = ServerStorage:GetAttribute("DataStoreTest")
	if Sauvegarde.attributIgnore(estStudio, nomTest) and not avertissementDonne then
		avertissementDonne = true
		warn("L'attribut DataStoreTest ('" .. tostring(nomTest) .. "') est posé sur ServerStorage, mais il est IGNORÉ hors de Studio : le vrai DataStore est utilisé. Retire-le du jeu.")
	end
	local nom, estTest = Sauvegarde.choisirNom(estStudio, nomTest, ModeDebug.actif, ModeDebug.nomDataStore)
	if nom == nil then
		return nil, nil
	end
	if not estTest then
		return dataStore, NOM_DATASTORE
	end
	local ok, storeTest = pcall(function()
		return DataStoreService:GetDataStore(nom)
	end)
	if ok then
		return storeTest, nom
	end
	warn("DataStore de test '" .. nom .. "' indisponible : " .. tostring(storeTest))
	return nil, nil
end

-- Appelle "action" jusqu'à NOMBRE_ESSAIS fois, tant qu'elle échoue.
-- Renvoie : réussi (true/false), puis le résultat ou le message d'erreur.
local function essayerPlusieursFois(description, action)
	local reussi, resultat
	for essai = 1, NOMBRE_ESSAIS do
		reussi, resultat = pcall(action)
		if reussi then
			return true, resultat
		end
		warn(description .. " : essai " .. essai .. "/" .. NOMBRE_ESSAIS .. " raté (" .. tostring(resultat) .. ")")
		if essai < NOMBRE_ESSAIS then
			task.wait(ATTENTE_ENTRE_ESSAIS)
		end
	end
	return false, resultat
end

-- Convertit une sauvegarde d'une ancienne version au format actuel
-- (rangée dans Sauvegarde pour pouvoir aussi la tester toute seule)
function Sauvegarde.migrer(userId, donnees)
	local version = if typeof(donnees.Version) == "number" then donnees.Version else 1
	if version < 2 then
		local achatsGardes = {}
		local rembourse = 0
		for _, nom in donnees.Achats do
			local prix = ANCIENNES_MACHINES[nom]
			if prix then
				rembourse += prix
			else
				table.insert(achatsGardes, nom)
			end
		end
		donnees.Achats = achatsGardes
		donnees.Argent += rembourse
		if rembourse > 0 then
			print("Sauvegarde de " .. userId .. " convertie : " .. rembourse .. " $ remboursés pour les anciennes machines")
		end
	end
	if version < 3 then
		-- Version 3 : inventaire, seuil de garde et compteur de pitié. On part de
		-- valeurs vides ; l'argent et les achats ne changent pas.
		donnees.Inventaire = {}
		donnees.SeuilGarde = Reglages.Inventaire.SeuilParDefaut
		donnees.CompteurPitie = 0
		print("Sauvegarde de " .. userId .. " convertie en version 3 (inventaire vide)")
	end
	if version < 4 then
		-- Version 4 : carnet de collection. Pour ne rien perdre, on y met déjà les
		-- combinaisons type + rareté présentes dans l'inventaire.
		local carnet = {}
		if typeof(donnees.Inventaire) == "table" then
			for cle in donnees.Inventaire do
				local morceaux = string.split(tostring(cle), "|")
				if #morceaux == 3 then
					carnet[morceaux[1] .. "|" .. morceaux[2]] = true
				end
			end
		end
		donnees.Carnet = carnet
		print("Sauvegarde de " .. userId .. " convertie en version 4 (carnet de collection)")
	end
	if version < 5 then
		-- Version 5 : compteurs de pitié de la sorcière (aucun échec au départ)
		donnees.PitieSorciere = {}
		print("Sauvegarde de " .. userId .. " convertie en version 5 (sorcière)")
	end
	if version < 6 then
		-- Version 6 : ingrédients du mode hybride. Panier et bac vides ; le cadeau de
		-- départ n'a pas encore été donné (il le sera une fois, quand le mode est actif).
		donnees.Ingredients = { Panier = {}, Reserve = {}, CadeauRecu = false }
		print("Sauvegarde de " .. userId .. " convertie en version 6 (ingrédients)")
	end
	donnees.Version = VERSION
end

-- Charge la sauvegarde d'un joueur.
-- Renvoie : réussi, puis les données (voir le format en haut du fichier).
-- Un nouveau joueur (pas encore de sauvegarde) reçoit des données vides : c'est une réussite.
-- Si ça échoue, il ne faudra PAS sauvegarder ce joueur, sinon on écraserait
-- sa vraie sauvegarde avec une partie recommencée à zéro.
function Sauvegarde.charger(userId)
	local store, nomStore = choisirDataStore()
	if store == nil then
		return false, nil
	end
	-- Dit dans la sortie quel DataStore est utilisé (vérification avant chaque test dans Studio)
	print("Chargement de " .. userId .. " depuis le DataStore '" .. nomStore .. "'")

	local reussi, donnees = essayerPlusieursFois("Chargement de " .. userId, function()
		return store:GetAsync(cle(userId))
	end)
	if not reussi then
		return false, nil
	end

	-- On vérifie le contenu, au cas où la sauvegarde serait abîmée ou d'un ancien format
	if typeof(donnees) ~= "table" then
		donnees = {}
	end
	if typeof(donnees.Argent) ~= "number" then
		donnees.Argent = 0
	end
	if typeof(donnees.Achats) ~= "table" then
		donnees.Achats = {}
	end
	Sauvegarde.migrer(userId, donnees)

	-- Les champs de la version 3 (le détail de chaque pile est vérifié par Inventaire)
	if typeof(donnees.Inventaire) ~= "table" then
		donnees.Inventaire = {}
	end
	if typeof(donnees.SeuilGarde) ~= "string" then
		donnees.SeuilGarde = Reglages.Inventaire.SeuilParDefaut
	end
	if typeof(donnees.CompteurPitie) ~= "number" or donnees.CompteurPitie < 0 then
		donnees.CompteurPitie = 0
	end
	-- Version 4 (le détail des clés est vérifié par Carnet)
	if typeof(donnees.Carnet) ~= "table" then
		donnees.Carnet = {}
	end
	-- Version 5 (le détail est vérifié par Sorciere)
	if typeof(donnees.PitieSorciere) ~= "table" then
		donnees.PitieSorciere = {}
	end
	-- Version 6 : le détail (ingrédients connus, quantités, cadeau) est vérifié par Ingredients
	return true, donnees
end

-- Mode test (seulement dans Studio) : si ServerStorage a l'attribut
-- "TestSansSauvegarde" à true, les sauvegardes sont lues mais jamais écrites.
-- Pratique pour tester avec de l'argent ou des achats sans abîmer sa vraie partie.
function Sauvegarde.modeTest()
	return RunService:IsStudio() and ServerStorage:GetAttribute("TestSansSauvegarde") == true
end

-- Enregistre les données d'un joueur. Renvoie true si ça a marché.
function Sauvegarde.enregistrer(userId, donnees)
	local store, nomStore = choisirDataStore()
	if store == nil or Sauvegarde.modeTest() then
		return false
	end
	-- Dernier verrou : en mode debug, jamais d'écriture dans un vrai DataStore des joueurs
	if ModeDebug.actif and (nomStore == NOM_DATASTORE or ModeDebug.estInterdit(nomStore)) then
		warn("Mode debug : écriture dans '" .. tostring(nomStore) .. "' refusée")
		return false
	end

	donnees.Version = VERSION
	local reussi = essayerPlusieursFois("Sauvegarde de " .. userId, function()
		store:SetAsync(cle(userId), donnees, { userId })
	end)
	return reussi
end

return Sauvegarde
