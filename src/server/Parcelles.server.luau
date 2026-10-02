-- Une parcelle par joueur.
--
-- Quand un joueur arrive, on lui donne un emplacement libre et on y pose une
-- copie du modèle d'usine (ServerStorage/ModeleUsine) : son propre collecteur,
-- ses propres boutons et ses propres achats. Le joueur apparaît dans son usine.
-- Quand il part, son usine est détruite et l'emplacement redevient libre.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Usine = script.Parent:WaitForChild("Usine")
local demarrerCollecteur = require(Usine.Collecteur)
local demarrerBoutons = require(Usine.Boutons)
local demarrerMachines = require(Usine.Machines)

local modeleUsine = ServerStorage:WaitForChild("ModeleUsine")
local dossierParcelles = workspace:WaitForChild("Parcelles")

-- Les emplacements des parcelles sur la carte : 3 de chaque côté du point
-- d'apparition. Les parcelles du côté "nord" sont tournées d'un demi-tour
-- pour que leur entrée regarde vers le centre.
local DEMI_TOUR = CFrame.Angles(0, math.pi, 0)
local EMPLACEMENTS = {
	CFrame.new(-70, 0, 50),
	CFrame.new(0, 0, 50),
	CFrame.new(70, 0, 50),
	CFrame.new(-70, 0, -50) * DEMI_TOUR,
	CFrame.new(0, 0, -50) * DEMI_TOUR,
	CFrame.new(70, 0, -50) * DEMI_TOUR,
}

local occupants = {} -- occupants[numéro d'emplacement] = joueur
local usines = {} -- usines[joueur] = son usine

local function trouverEmplacementLibre()
	for numero = 1, #EMPLACEMENTS do
		if occupants[numero] == nil then
			return numero
		end
	end
	return nil
end

local function ajouterPanneauProprietaire(usine, joueur)
	local panneau = Instance.new("BillboardGui")
	panneau.Size = UDim2.fromScale(14, 3)
	panneau.StudsOffset = Vector3.new(0, 6, 0)
	panneau.MaxDistance = 200
	panneau.Parent = usine.Apparition

	local texte = Instance.new("TextLabel")
	texte.Size = UDim2.fromScale(1, 1)
	texte.BackgroundTransparency = 1
	texte.TextScaled = true
	texte.Font = Enum.Font.FredokaOne
	texte.TextColor3 = Color3.fromRGB(255, 180, 220)
	texte.TextStrokeTransparency = 0
	texte.Text = "Usine de " .. joueur.DisplayName
	texte.Parent = panneau
end

-- Place le personnage du joueur à l'entrée de son usine
local function teleporterDansUsine(joueur, personnage)
	local usine = usines[joueur]
	if usine == nil then
		return
	end
	personnage:WaitForChild("HumanoidRootPart")
	-- On attend un instant : Roblox place d'abord le personnage sur le
	-- SpawnLocation, et on le déplace juste après.
	task.wait()
	personnage:PivotTo(usine.Apparition.CFrame)
end

local function quandUnJoueurArrive(joueur)
	local numero = trouverEmplacementLibre()
	if numero == nil then
		warn("Plus de parcelle libre pour " .. joueur.Name)
		return
	end
	occupants[numero] = joueur

	local usine = modeleUsine:Clone()
	usine.Name = "Usine de " .. joueur.Name
	usine:SetAttribute("Proprietaire", joueur.UserId)
	usine.PrimaryPart = usine.Sol -- le sol sert de point de repère pour déplacer l'usine
	usine:PivotTo(EMPLACEMENTS[numero] * CFrame.new(0, usine.Sol.Size.Y / 2, 0))
	usine.Parent = dossierParcelles
	usines[joueur] = usine

	ajouterPanneauProprietaire(usine, joueur)
	demarrerCollecteur(usine, joueur)
	demarrerMachines(usine)
	demarrerBoutons(usine, joueur)

	joueur.CharacterAdded:Connect(function(personnage)
		teleporterDansUsine(joueur, personnage)
	end)
	if joueur.Character then
		task.spawn(teleporterDansUsine, joueur, joueur.Character)
	end
end

local function quandUnJoueurPart(joueur)
	local usine = usines[joueur]
	if usine then
		usine:Destroy() -- détruit aussi ses boutons, machines et bonbons
		usines[joueur] = nil
	end

	for numero, occupant in occupants do
		if occupant == joueur then
			occupants[numero] = nil -- l'emplacement redevient libre
		end
	end
end

Players.PlayerAdded:Connect(quandUnJoueurArrive)
Players.PlayerRemoving:Connect(quandUnJoueurPart)

-- Au cas où un joueur serait déjà là avant que ce script démarre (fréquent en test dans Studio)
for _, joueur in Players:GetPlayers() do
	task.spawn(quandUnJoueurArrive, joueur)
end
