-- CONTRÔLER L'ÎLE DU VERGER (LECTURE SEULE) — à lancer dans Studio, en mode édition.
-- Vérifie ce que tools/construire_verger.lua a construit : ancrage, collisions, modèles de
-- récolte, pentes de sable, nombre de pièces. N'écrit et ne modifie rien.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local fautes = {}
local function faute(texte)
	table.insert(fautes, texte)
end

-- Pièces qui DOIVENT avoir une collision (sols et murs) ; toutes les autres n'en ont pas
local function estSolOuMur(p)
	local n = p.Name
	return n == "Planche" or n == "FondDeSable" or n == "Herbe" or n == "Plage" or string.sub(n, 1, 5) == "Pente"
		or string.sub(n, 1, 6) == "MurEst" or string.sub(n, 1, 8) == "MurLarge"
end

local monde = workspace:FindFirstChild("Monde")
if monde == nil then
	return "Workspace/Monde introuvable : lancer tools/construire_verger.lua"
end

local nbPieces, nbCollision = 0, 0
for _, p in monde:GetDescendants() do
	if p:IsA("BasePart") then
		nbPieces += 1
		if not p.Anchored then
			faute(p:GetFullName() .. " n'est pas ancrée")
		end
		if estSolOuMur(p) then
			nbCollision += 1
			if not p.CanCollide then
				faute(p:GetFullName() .. " devrait avoir une collision")
			end
		elseif p.CanCollide or p.CanQuery or p.CanTouch then
			faute(p:GetFullName() .. " devrait être sans collision (CanCollide, CanQuery, CanTouch à false)")
		end
	end
end

-- Les points de récolte
local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local sortes = Reglages.Hybride and Reglages.Hybride.Points or {}
local compte = {}
local recolte = monde.Iles.Verger:FindFirstChild("Recolte")
for _, point in (recolte and recolte:GetChildren() or {}) do
	local sorte = point:GetAttribute("Sorte")
	compte[sorte or "?"] = (compte[sorte or "?"] or 0) + 1
	if Reglages.Hybride and Reglages.Hybride.Points and sortes[sorte] == nil then
		faute(point.Name .. " : Sorte '" .. tostring(sorte) .. "' inconnue de Reglages.Hybride.Points")
	end
	local b = point.PrimaryPart
	if b == nil or b.Name ~= "Base" then
		faute(point.Name .. " : PrimaryPart doit être la Part Base")
	elseif b.CFrame.UpVector.Y < 0.999 then
		faute(point.Name .. " : la Base est penchée")
	end
	if point:FindFirstChild("Prompt") == nil then
		faute(point.Name .. " : pas de Part Prompt")
	end
	local fruits = 0
	for _, p in point:GetDescendants() do
		if p:GetAttribute("Fruit") then
			fruits += 1
		end
	end
	if fruits == 0 then
		faute(point.Name .. " : aucun fruit (attribut Fruit)")
	end
end

-- Les pentes : le haut doit être contre le bord (pont ou île), le bas sur le fond de la mer
local pentesOk, pentesTotal = 0, 0
for _, p in monde:GetDescendants() do
	if p:IsA("WedgePart") then
		pentesTotal += 1
		local haut = p.CFrame * Vector3.new(0, p.Size.Y / 2, p.Size.Z / 2 - 0.2) -- arête haute (face arrière)
		local bas = p.CFrame * Vector3.new(0, -p.Size.Y / 2, -p.Size.Z / 2 + 0.2) -- arête basse (face avant)
		local versExterieur = (bas - haut) * Vector3.new(1, 0, 1)
		local centreIle = Vector3.new(530, 0, 0)
		local horsDuPont = math.abs(bas.Z + 15) > math.abs(haut.Z + 15)
		local horsDeLIle = (bas - centreIle).Magnitude > (haut - centreIle).Magnitude
		if haut.Y > bas.Y and versExterieur.Magnitude > 1 and (horsDuPont or horsDeLIle) then
			pentesOk += 1
		else
			faute(p:GetFullName() .. " : pente dans le mauvais sens")
		end
	end
end

-- Modèles de récolte et ce qui a été rangé
local modeles = ServerStorage:FindFirstChild("ModelesRecolte")
local anciens = ServerStorage:FindFirstChild("Decor_Anciens")
local ranges = {}
for _, nom in { "MurEst", "Falaise_277_0", "Falaise_277_-56", "Falaise_280_56" } do
	table.insert(ranges, nom .. (if anciens and anciens:FindFirstChild(nom) then " ✓" else " MANQUANT"))
end

local lignes = {
	"Pièces dans Workspace/Monde : " .. nbPieces .. " (dont " .. nbCollision .. " sols et murs avec collision)",
	"Points de récolte : " .. (compte.ArbreFraise or 0) .. " arbres, " .. (compte.BuissonFraise or 0) .. " buissons",
	"Pentes dans le bon sens : " .. pentesOk .. " / " .. pentesTotal,
	"ModelesRecolte : " .. (modeles and #modeles:GetChildren() or 0) .. " modèles",
	"Rangés dans Decor_Anciens : " .. table.concat(ranges, ", "),
	"Fautes : " .. #fautes,
}
for _, f in fautes do
	table.insert(lignes, "  - " .. f)
end
return table.concat(lignes, "\n")
