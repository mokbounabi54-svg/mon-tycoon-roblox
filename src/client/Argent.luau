-- Le compteur d'argent en haut au centre de l'écran (loin du menu Roblox, en haut à gauche).
-- Il lit simplement leaderstats.Argent (rempli par le serveur) et s'anime quand
-- l'argent augmente : le chiffre défile et la pastille grossit un instant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local C = Theme.Couleurs
local DUREE_DEFILEMENT = 0.4 -- secondes pour que le chiffre atteigne sa nouvelle valeur

return function()
	local joueur = Players.LocalPlayer
	local argent = joueur:WaitForChild("leaderstats"):WaitForChild("Argent")

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "Argent"
	ecran.ResetOnSpawn = false
	ecran.Parent = joueur:WaitForChild("PlayerGui")

	-- Pastille blanche avec une ombre, qui s'élargit selon le nombre
	local support = Instance.new("Frame")
	support.Name = "Compteur"
	support.BackgroundTransparency = 1
	support.AnchorPoint = Vector2.new(0.5, 0)
	support.Position = UDim2.new(0.5, 0, 0, 6)
	support.Size = UDim2.fromOffset(0, 50)
	support.AutomaticSize = Enum.AutomaticSize.X
	support.Parent = ecran
	local grossir = Instance.new("UIScale")
	grossir.Parent = support

	local ombre = Instance.new("Frame")
	ombre.Name = "Ombre"
	ombre.BackgroundColor3 = C.OmbrePanneau
	ombre.BorderSizePixel = 0
	ombre.Position = UDim2.fromOffset(0, 5)
	ombre.Size = UDim2.new(1, 0, 0, 44)
	Theme.arrondir(ombre, 22)
	ombre.Parent = support

	local pastille = Theme.texte({
		Texte = "",
		Taille = 26,
		Alignement = Enum.TextXAlignment.Center,
		Parent = support,
	})
	pastille.Name = "Montant"
	pastille.BackgroundTransparency = 0
	pastille.BackgroundColor3 = C.Panneau
	pastille.AutomaticSize = Enum.AutomaticSize.X
	pastille.Size = UDim2.fromOffset(140, 44)
	Theme.arrondir(pastille, 22)
	local marges = Instance.new("UIPadding")
	marges.PaddingLeft = UDim.new(0, 20)
	marges.PaddingRight = UDim.new(0, 20)
	marges.Parent = pastille

	-- Le nombre affiché défile en douceur vers la vraie valeur
	local affiche = Instance.new("NumberValue")
	affiche.Value = argent.Value
	local function ecrire()
		pastille.Text = "💰 " .. Format.nombre(affiche.Value) .. " $"
	end
	affiche.Changed:Connect(ecrire)
	ecrire()

	local defilement
	argent.Changed:Connect(function(nouveau)
		if defilement then
			defilement:Cancel()
		end
		defilement = TweenService:Create(affiche, TweenInfo.new(DUREE_DEFILEMENT, Enum.EasingStyle.Quad), { Value = nouveau })
		defilement:Play()

		if nouveau > affiche.Value then
			-- Petit « pop » quand on gagne de l'argent
			grossir.Scale = 1.12
			TweenService:Create(grossir, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end)
end
