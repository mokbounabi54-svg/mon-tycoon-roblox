-- Une parcelle par joueur, avec sauvegarde.
--
-- Quand un joueur arrive, on charge sa sauvegarde (argent et machines achetées),
-- puis on lui donne un emplacement libre et on y pose une copie du modèle d'usine
-- (ServerStorage/ModeleUsine) : son propre collecteur, ses propres boutons et ses
-- propres achats. Le joueur apparaît dans son usine.
--
-- On sauvegarde :
--   - quand le joueur part (puis son usine est détruite et l'emplacement libéré),
--   - toutes les quelques minutes, au cas où le serveur planterait,
--   - quand le serveur s'arrête.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Sauvegarde = require(script.Parent:WaitForChild("Sauvegarde"))
local Usine = script.Parent:WaitForChild("Usine")
local demarrerCollecteur = require(Usine.Collecteur)
local demarrerBoutons = require(Usine.Boutons)
local demarrerMachines = require(Usine.Machines)

local modeleUsine = ServerStorage:WaitForChild("ModeleUsine")
local dossierParcelles = workspace:WaitForChild("Parcelles")

local INTERVALLE_SAUVEGARDE_AUTO = 120 -- secondes (2 minutes)

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
local peutSauvegarder = {} -- peutSauvegarder[joueur] = true si sa sauvegarde a bien été chargée
local sauvegardesEnCours = 0 -- nombre de sauvegardes pas encore terminées
local serveurEnArret = false

local function trouverEmplacementLibre()
	for numero = 1, #EMPLACEMENTS do
		if occupants[numero] == nil then
			return numero
		end
	end
	return nil
end

-- Rassemble ce qu'il faut sauvegarder pour un joueur : son argent et les noms
-- des objets présents dans le dossier Achats de son usine.
-- Renvoie nil si quelque chose manque (on ne sauvegarde pas plutôt que
-- d'enregistrer des données fausses).
local function lireDonnees(joueur, usine)
	local leaderstats = joueur:FindFirstChild("leaderstats")
	local argent = leaderstats and leaderstats:FindFirstChild("Argent")
	if argent == nil then
		return nil
	end

	local achats = {}
	for _, objet in usine.Achats:GetChildren() do
		table.insert(achats, objet.Name)
	end

	return { Argent = argent.Value, Achats = achats }
end

-- Envoie les données au DataStore et affiche le résultat dans la sortie
local function enregistrer(joueur, donnees)
	sauvegardesEnCours += 1
	local reussi = Sauvegarde.enregistrer(joueur.UserId, donnees)
	sauvegardesEnCours -= 1

	if reussi then
		print("Sauvegarde de " .. joueur.Name .. " : " .. donnees.Argent .. " $, " .. #donnees.Achats .. " achat(s)")
	else
		warn("Sauvegarde de " .. joueur.Name .. " impossible, ses derniers progrès sont perdus")
	end
end

-- Sauvegarde un joueur qui est encore là, sans bloquer le reste du script
local function sauvegarderJoueur(joueur)
	local usine = usines[joueur]
	if usine == nil or not peutSauvegarder[joueur] then
		return
	end
	local donnees = lireDonnees(joueur, usine)
	if donnees then
		task.spawn(enregistrer, joueur, donnees)
	end
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
	-- Le chargement peut prendre un peu de temps (on attend la réponse de Roblox)
	local reussi, donnees = Sauvegarde.charger(joueur.UserId)
	if joueur.Parent == nil then
		return -- le joueur est parti pendant le chargement
	end

	if reussi then
		print("Sauvegarde de " .. joueur.Name .. " chargée : " .. donnees.Argent .. " $, " .. #donnees.Achats .. " achat(s)")
	else
		-- On le laisse jouer, mais sans jamais sauvegarder : sinon sa vraie
		-- sauvegarde serait écrasée par cette partie recommencée à zéro.
		warn("Impossible de charger la sauvegarde de " .. joueur.Name .. " : cette partie ne sera pas sauvegardée")
		donnees = { Argent = 0, Achats = {} }
	end

	local numero = trouverEmplacementLibre()
	if numero == nil then
		warn("Plus de parcelle libre pour " .. joueur.Name)
		return
	end
	occupants[numero] = joueur

	-- Le script Leaderstats crée la valeur Argent ; on y met l'argent sauvegardé
	local argent = joueur:WaitForChild("leaderstats"):WaitForChild("Argent")
	argent.Value = donnees.Argent

	local usine = modeleUsine:Clone()
	usine.Name = "Usine de " .. joueur.Name
	usine:SetAttribute("Proprietaire", joueur.UserId)
	usine.PrimaryPart = usine.Sol -- le sol sert de point de repère pour déplacer l'usine
	usine:PivotTo(EMPLACEMENTS[numero] * CFrame.new(0, usine.Sol.Size.Y / 2, 0))
	usine.Parent = dossierParcelles
	usines[joueur] = usine
	peutSauvegarder[joueur] = reussi

	ajouterPanneauProprietaire(usine, joueur)
	demarrerCollecteur(usine, joueur)
	demarrerMachines(usine)
	demarrerBoutons(usine, joueur, donnees.Achats)

	joueur.CharacterAdded:Connect(function(personnage)
		teleporterDansUsine(joueur, personnage)
	end)
	if joueur.Character then
		task.spawn(teleporterDansUsine, joueur, joueur.Character)
	end
end

local function quandUnJoueurPart(joueur)
	-- Si le serveur s'arrête, c'est la fonction d'arrêt (plus bas) qui sauvegarde
	if not serveurEnArret then
		sauvegarderJoueur(joueur) -- lit les données tout de suite, avant de détruire l'usine
	end

	local usine = usines[joueur]
	if usine then
		usine:Destroy() -- détruit aussi ses boutons, machines et bonbons
	end
	usines[joueur] = nil
	peutSauvegarder[joueur] = nil

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

-- Sauvegarde automatique de tous les joueurs, toutes les quelques minutes
task.spawn(function()
	while true do
		task.wait(INTERVALLE_SAUVEGARDE_AUTO)
		for joueur in usines do
			sauvegarderJoueur(joueur)
		end
	end
end)

-- Quand le serveur s'arrête (mise à jour du jeu, dernier joueur parti, fin du
-- test dans Studio), Roblox appelle cette fonction et attend qu'elle se termine
-- (30 secondes au maximum) avant d'éteindre le serveur.
game:BindToClose(function()
	serveurEnArret = true
	for joueur in usines do
		sauvegarderJoueur(joueur)
	end
	-- On attend que toutes les sauvegardes (y compris celles des joueurs
	-- partis juste avant) soient terminées
	while sauvegardesEnCours > 0 do
		task.wait()
	end
end)
