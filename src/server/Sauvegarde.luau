-- Lecture et écriture des sauvegardes des joueurs dans un DataStore.
--
-- Un DataStore est une sorte de grand tableau rangé chez Roblox, qui garde
-- les données même quand le serveur s'éteint. Chaque joueur a sa propre case,
-- repérée par une "clé" construite avec son UserId.
--
-- Une sauvegarde ressemble à ça :
--   { Argent = 120, Achats = { "MachineABonbons" } }
--
-- Parler au DataStore peut échouer (problème réseau, trop de demandes...).
-- On utilise donc pcall pour attraper l'erreur au lieu de planter, et on
-- réessaie plusieurs fois avant d'abandonner.

local DataStoreService = game:GetService("DataStoreService")

local NOM_DATASTORE = "Joueurs_v1" -- changer ce nom repart de sauvegardes vides
local NOMBRE_ESSAIS = 3
local ATTENTE_ENTRE_ESSAIS = 2 -- secondes

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

-- Charge la sauvegarde d'un joueur.
-- Renvoie : réussi, puis les données ({ Argent, Achats }).
-- Un nouveau joueur (pas encore de sauvegarde) reçoit des données vides : c'est une réussite.
-- Si ça échoue, il ne faudra PAS sauvegarder ce joueur, sinon on écraserait
-- sa vraie sauvegarde avec une partie recommencée à zéro.
function Sauvegarde.charger(userId)
	if dataStore == nil then
		return false, nil
	end

	local reussi, donnees = essayerPlusieursFois("Chargement de " .. userId, function()
		return dataStore:GetAsync(cle(userId))
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
	return true, donnees
end

-- Enregistre les données d'un joueur. Renvoie true si ça a marché.
function Sauvegarde.enregistrer(userId, donnees)
	if dataStore == nil then
		return false
	end

	local reussi = essayerPlusieursFois("Sauvegarde de " .. userId, function()
		dataStore:SetAsync(cle(userId), donnees, { userId })
	end)
	return reussi
end

return Sauvegarde
