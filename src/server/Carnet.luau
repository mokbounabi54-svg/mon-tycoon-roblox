-- Le carnet de collection : chaque combinaison type + rareté obtenue au moins une fois.
--
-- Une combinaison est repérée par une clé "Type|Rareté" (ex : "Fraise|Rare").
-- Le carnet d'un joueur est un ensemble de clés : { ["Fraise|Rare"] = true, ... }
-- Il est sauvegardé tel quel (champ Carnet, version 4 de la sauvegarde).
--
-- Une combinaison est découverte quand un bonbon de cette rareté sort d'un mélangeur
-- de l'usine du joueur (module Production), ou quand la sorcière la fabrique.
-- Le « Bonbon raté » de la sorcière n'est pas dans le carnet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local majCarnet = Remotes.obtenir("CarnetMaj") -- serveur -> écran : le carnet à jour
local demanderCarnet = Remotes.obtenir("DemanderCarnet") -- écran -> serveur
local annonce = Remotes.obtenir("Annonce")

-- Toutes les clés possibles (3 types × 6 raretés = 18 aujourd'hui)
local clesPossibles = {}
local nombreTotal = 0
for _, typeBonbon in Reglages.OrdreTypes do
	for _, infos in Reglages.Raretes do
		clesPossibles[typeBonbon .. "|" .. infos.Nom] = true
		nombreTotal += 1
	end
end

local etats = {} -- etats[joueur] = { ["Fraise|Rare"] = true, ... }

local Carnet = {}

function Carnet.cle(typeBonbon, nomRarete)
	return tostring(typeBonbon) .. "|" .. tostring(nomRarete)
end

function Carnet.estValide(cle)
	return clesPossibles[cle] == true
end

local function compter(decouverts)
	local n = 0
	for _ in decouverts do
		n += 1
	end
	return n
end

local function envoyer(joueur, nouvelleCle)
	local decouverts = etats[joueur]
	if decouverts == nil then
		return
	end
	majCarnet:FireClient(joueur, {
		Decouverts = table.clone(decouverts),
		Nombre = compter(decouverts),
		Total = nombreTotal,
		Nouveau = nouvelleCle, -- la clé qui vient d'être découverte (nil sinon)
	})
end

-- Prépare le carnet d'un joueur qui arrive (donnees.Carnet de sa sauvegarde)
function Carnet.demarrer(joueur, donnees)
	local decouverts = {}
	if typeof(donnees.Carnet) == "table" then
		for cle, valeur in donnees.Carnet do
			if valeur == true and Carnet.estValide(cle) then
				decouverts[cle] = true
			end
		end
	end
	etats[joueur] = decouverts
	envoyer(joueur)
end

-- À appeler APRÈS avoir lu la sauvegarde
function Carnet.arreter(joueur)
	etats[joueur] = nil
end

-- Ce qu'il faut sauvegarder : { ["Fraise|Rare"] = true, ... }
function Carnet.lire(joueur)
	local decouverts = etats[joueur]
	return decouverts and table.clone(decouverts)
end

-- Note une combinaison obtenue. Si elle est nouvelle : message « Nouveau ! » et mise à jour
-- de l'écran. Renvoie true si c'était une nouvelle découverte.
function Carnet.decouvrir(joueur, typeBonbon, nomRarete)
	local decouverts = joueur and etats[joueur]
	local cle = Carnet.cle(typeBonbon, nomRarete)
	if decouverts == nil or not Carnet.estValide(cle) or decouverts[cle] then
		return false
	end
	decouverts[cle] = true
	annonce:FireClient(joueur, "Nouveau dans le carnet : " .. typeBonbon .. " " .. nomRarete .. " !", Color3.fromHex("FF3EA5"), "Nouveau")
	envoyer(joueur, cle)
	return true
end

demanderCarnet.OnServerEvent:Connect(function(joueur)
	envoyer(joueur)
end)

return Carnet
