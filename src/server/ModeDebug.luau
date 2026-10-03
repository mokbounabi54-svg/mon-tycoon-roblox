-- Le mode debug : décide UNE SEULE FOIS, au démarrage du serveur, si le panneau
-- de debug existe pendant cette partie.
--
-- Il est actif seulement si LES DEUX conditions sont vraies :
--   1. RunService:IsStudio() : on joue dans Roblox Studio. Dans le jeu publié,
--      Roblox renvoie toujours false : le mode debug ne peut donc PAS s'y activer,
--      même si l'attribut ci-dessous est resté dans le fichier du jeu.
--   2. ServerStorage a l'attribut "PanneauDebug" à true (on le coche dans Studio,
--      en mode édition, avant de lancer la partie).
--
-- Quand il est actif, TOUTES les sauvegardes (lecture et écriture) vont dans un
-- DataStore de test : celui de l'attribut "DataStoreTest" s'il y en a un, sinon
-- "Test_Debug". Jamais dans le vrai DataStore des joueurs.
--
-- La décision est prise une fois pour toutes : cocher ou décocher l'attribut
-- pendant la partie ne change rien (sinon un joueur chargé depuis la vraie
-- sauvegarde pourrait recevoir de l'argent de debug, ou l'inverse).

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DATASTORE_PAR_DEFAUT = "Test_Debug"
-- Les vrais DataStores des joueurs (l'actuel et l'ancien) : interdits en mode debug
local DATASTORES_INTERDITS = { "Joueurs_v2", "Joueurs_v1" }

local ModeDebug = {
	actif = false,
	nomDataStore = nil, -- le DataStore de test utilisé quand le mode est actif
}

if RunService:IsStudio() and ServerStorage:GetAttribute("PanneauDebug") == true then
	local nom = ServerStorage:GetAttribute("DataStoreTest")
	if typeof(nom) ~= "string" or nom == "" then
		nom = DATASTORE_PAR_DEFAUT
	end
	if table.find(DATASTORES_INTERDITS, nom) then
		-- Quelqu'un a mis le nom du vrai DataStore dans DataStoreTest : on refuse tout
		warn("Mode debug REFUSÉ : DataStoreTest = '" .. nom .. "' est le vrai DataStore des joueurs")
	else
		ModeDebug.actif = true
		ModeDebug.nomDataStore = nom
		warn("Mode debug actif : les sauvegardes vont dans le DataStore de test '" .. nom .. "'")
	end
end

-- Pour une vérification de dernière minute (voir Sauvegarde) : ce nom est-il un vrai DataStore ?
function ModeDebug.estInterdit(nomDataStore)
	return table.find(DATASTORES_INTERDITS, nomDataStore) ~= nil
end

return ModeDebug
