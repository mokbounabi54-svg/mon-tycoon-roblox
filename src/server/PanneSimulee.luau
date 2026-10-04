-- Pannes simulées, pour TESTER ce qui se passe quand quelque chose échoue
-- (DataStore en panne, module qui plante...). Ne marche QUE dans Studio.
--
-- Utilisation (dans Studio) : poser sur ServerStorage l'attribut texte "SimulerPanne" :
--   "Chargement"  : la lecture de la sauvegarde échoue (les 3 essais)
--   "Sauvegarde"  : l'écriture de la sauvegarde échoue (les 3 essais)
--   "Ingredients" : le démarrage des ingrédients d'un joueur plante
-- L'attribut est relu à chaque fois : on peut le poser ou le retirer pendant une partie.
-- Dans le jeu publié, RunService:IsStudio() vaut false : aucune panne n'est jamais simulée.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local PanneSimulee = {}

-- Fonction pure (testable avec un faux « pas dans Studio ») :
-- vrai si la panne "nom" doit être simulée
function PanneSimulee.estActive(estStudio, valeurAttribut, nom)
	return estStudio == true and valeurAttribut == nom
end

-- À appeler juste avant l'action à faire échouer : lève une erreur si la panne est demandée
function PanneSimulee.verifier(nom)
	if PanneSimulee.estActive(RunService:IsStudio(), ServerStorage:GetAttribute("SimulerPanne"), nom) then
		error("Panne simulée (" .. nom .. ")", 2)
	end
end

return PanneSimulee
