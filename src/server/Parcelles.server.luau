-- Une parcelle par joueur, avec sauvegarde.
--
-- Quand un joueur arrive, on charge sa sauvegarde (argent et machines achetées),
-- puis on lui donne un emplacement libre et on y pose une copie du modèle d'usine
-- (ServerStorage/ModeleUsine) : sa propre chaîne de production, sa caisse, ses boutons et ses
-- propres achats. Le joueur apparaît dans son usine.
--
-- On sauvegarde :
--   - quand le joueur part (puis son usine est détruite et l'emplacement libéré),
--   - toutes les quelques minutes, au cas où le serveur planterait,
--   - quand le serveur s'arrête.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Sauvegarde = require(script.Parent:WaitForChild("Sauvegarde"))
local Inventaire = require(script.Parent:WaitForChild("Inventaire"))
local Carnet = require(script.Parent:WaitForChild("Carnet"))
local Sorciere = require(script.Parent:WaitForChild("Sorciere"))
local PanneauDebug = require(script.Parent:WaitForChild("PanneauDebug")) -- seulement dans Studio
local Usine = script.Parent:WaitForChild("Usine")
local demarrerCaisse = require(Usine.Caisse)
local demarrerBoutons = require(Usine.Boutons)
local demarrerProduction = require(Usine.Production)

local modeleUsine = ServerStorage:WaitForChild("ModeleUsine")
local dossierParcelles = workspace:WaitForChild("Parcelles")

local INTERVALLE_SAUVEGARDE_AUTO = 120 -- secondes (2 minutes)

-- Les emplacements des parcelles (120 × 120) sur la carte : 2 rangées de 3, de part et
-- d'autre de l'allée centrale (le hub avec la fontaine est au centre, en 0, 0, 0).
-- Les parcelles du côté "nord" sont tournées d'un demi-tour pour que leur entrée
-- regarde vers le hub. 140 entre deux parcelles voisines (20 studs pour le décor) ;
-- rangées à Z = ±115 (allée de 110 studs). Le décor de Workspace/Decor est placé
-- d'après ces positions : si on les change, il faut déplacer le décor aussi
-- (voir docs/decor-carte.md).
local DEMI_TOUR = CFrame.Angles(0, math.pi, 0)
local EMPLACEMENTS = {
	CFrame.new(-140, 0, 115),
	CFrame.new(0, 0, 115),
	CFrame.new(140, 0, 115),
	CFrame.new(-140, 0, -115) * DEMI_TOUR,
	CFrame.new(0, 0, -115) * DEMI_TOUR,
	CFrame.new(140, 0, -115) * DEMI_TOUR,
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

-- Rassemble ce qu'il faut sauvegarder pour un joueur : son argent, les noms
-- des objets présents dans le dossier Achats de son usine, son inventaire,
-- son seuil de garde et son compteur de pitié.
-- Renvoie nil si quelque chose manque (on ne sauvegarde pas plutôt que
-- d'enregistrer des données fausses).
local function lireDonnees(joueur, usine)
	local leaderstats = joueur:FindFirstChild("leaderstats")
	local argent = leaderstats and leaderstats:FindFirstChild("Argent")
	local inventaire = Inventaire.lire(joueur)
	local carnet = Carnet.lire(joueur)
	local pitieSorciere = Sorciere.lire(joueur)
	if argent == nil or inventaire == nil or carnet == nil or pitieSorciere == nil then
		return nil
	end

	local achats = {}
	for _, objet in usine.Achats:GetChildren() do
		table.insert(achats, objet.Name)
	end

	return {
		Argent = argent.Value,
		Achats = achats,
		Inventaire = inventaire.Inventaire,
		SeuilGarde = inventaire.SeuilGarde,
		CompteurPitie = joueur:GetAttribute("CompteurPitie") or 0,
		Carnet = carnet,
		PitieSorciere = pitieSorciere,
	}
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
	if Sauvegarde.modeTest() then
		print("Mode test : la sauvegarde de " .. joueur.Name .. " n'est pas écrite")
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
		donnees = { Argent = 0, Achats = {}, Inventaire = {}, CompteurPitie = 0, Carnet = {}, PitieSorciere = {} }
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
	joueur:SetAttribute("CompteurPitie", donnees.CompteurPitie) -- pitié de la rareté (module Rarete)
	-- Nouveau joueur (ni argent ni machine) : l'écran lui montre le petit tutoriel
	joueur:SetAttribute("NouveauJoueur", reussi and donnees.Argent == 0 and #donnees.Achats == 0)

	local usine = modeleUsine:Clone()
	usine.Name = "Usine de " .. joueur.Name
	usine:SetAttribute("Proprietaire", joueur.UserId)
	usine.PrimaryPart = usine.Sol -- le sol sert de point de repère pour déplacer l'usine
	usine:PivotTo(EMPLACEMENTS[numero] * CFrame.new(0, usine.Sol.Size.Y / 2, 0))
	usine.Parent = dossierParcelles
	usines[joueur] = usine
	peutSauvegarder[joueur] = reussi

	ajouterPanneauProprietaire(usine, joueur)
	Inventaire.demarrer(joueur, usine, donnees) -- avant la production : le point de vente s'en sert
	Carnet.demarrer(joueur, donnees) -- avant la production : les mélangeurs s'en servent
	Sorciere.demarrer(joueur, usine, donnees) -- pose la sorcière près de l'entrée
	demarrerCaisse(usine, joueur)
	demarrerProduction(usine) -- avant les boutons, pour démarrer aussi les achats restaurés
	local acheterSansPayer = demarrerBoutons(usine, joueur, donnees.Achats)
	PanneauDebug.brancher(joueur, acheterSansPayer) -- ne fait rien hors de Studio

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
	Inventaire.arreter(joueur) -- après la sauvegarde, qui a lu l'inventaire
	Carnet.arreter(joueur)
	Sorciere.arreter(joueur)

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
