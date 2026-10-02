-- Crée le tableau des scores (en haut à droite de l'écran) pour chaque joueur
-- avec une valeur "Argent" qui commence à 0.

local Players = game:GetService("Players")

local ARGENT_DE_DEPART = 0

local function quandUnJoueurArrive(joueur)
	-- Roblox affiche automatiquement un dossier nommé exactement "leaderstats"
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = joueur

	local argent = Instance.new("IntValue")
	argent.Name = "Argent"
	argent.Value = ARGENT_DE_DEPART
	argent.Parent = leaderstats
end

Players.PlayerAdded:Connect(quandUnJoueurArrive)

-- Au cas où un joueur serait déjà là avant que ce script démarre (fréquent en test dans Studio)
for _, joueur in Players:GetPlayers() do
	quandUnJoueurArrive(joueur)
end
