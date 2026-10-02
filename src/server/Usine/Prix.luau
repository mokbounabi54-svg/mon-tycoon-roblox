-- LE prix d'un bonbon. C'est la seule fonction qui calcule un prix de vente :
-- le point de vente (vente automatique) et l'inventaire l'utilisent tous les deux,
-- donc un même bonbon vaut exactement pareil des deux côtés au même moment.
--
--   prix = ValeurDepart du type × multiplicateurs des machines de la zone que le
--          joueur possède × multiplicateur de la rareté × multiplicateur de la mutation
--
-- Les chiffres sont dans ReplicatedStorage/Shared/Reglages (Types, Raretes, Mutations).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local Rarete = require(script.Parent:WaitForChild("Rarete"))

local Prix = {}

-- Renvoie le prix (nombre entier de $) d'un bonbon pour l'usine "usine",
-- ou nil si le type, la rareté ou la mutation est inconnu.
function Prix.calculer(usine, typeBonbon, nomRarete, mutation)
	local infosType = Reglages.Types[typeBonbon]
	local multiplicateurMutation = Reglages.Mutations[mutation or "Normal"]
	if infosType == nil or Rarete.rang(nomRarete) == nil or multiplicateurMutation == nil then
		return nil
	end

	local valeur = infosType.ValeurDepart
	for _, nomMachine in infosType.Machines do
		-- Une machine pas encore achetée n'est pas dans le dossier Achats de l'usine
		local machine = usine.Achats:FindFirstChild(nomMachine) or usine.Machines:FindFirstChild(nomMachine)
		if machine then
			valeur *= machine:GetAttribute("Multiplicateur") or 1
		end
	end
	valeur *= Rarete.infos(nomRarete).Multiplicateur
	valeur *= multiplicateurMutation

	return math.floor(valeur + 0.5) -- arrondi au $ près
end

return Prix
