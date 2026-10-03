-- Le panneau de debug, côté écran : SEULEMENT dans Studio.
--
-- Il ne se construit que si :
--   - on est dans Studio (RunService:IsStudio()) ;
--   - le serveur a activé le mode debug (attribut "PanneauDebug" sur ReplicatedStorage,
--     qui contient le nom du DataStore de test).
-- Le panneau n'envoie que des demandes (canal "Debug") ; c'est le serveur qui vérifie
-- et agit. Même si quelqu'un trafiquait cet écran, le serveur du jeu publié n'a pas
-- de canal "Debug" et ignorerait tout.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))

local C = Theme.Couleurs
local COULEUR_DEBUG = Color3.fromHex("FF8A1F")
local LARGEUR = 440
local HAUTEUR_MAX = 460
local HAUTEUR_BOUTON = 44 -- assez grand pour un doigt

-- Une ligne : un titre puis des boutons qui passent à la ligne si besoin
local function ajouterLigne(contenu, ordre, titre, boutons)
	local ligne = Instance.new("Frame")
	ligne.Name = titre
	ligne.BackgroundTransparency = 1
	ligne.Size = UDim2.new(1, 0, 0, 0)
	ligne.AutomaticSize = Enum.AutomaticSize.Y
	ligne.LayoutOrder = ordre
	ligne.Parent = contenu

	local rangement = Instance.new("UIListLayout")
	rangement.SortOrder = Enum.SortOrder.LayoutOrder
	rangement.Padding = UDim.new(0, 6)
	rangement.Parent = ligne

	local etiquette = Theme.texte({ Texte = titre, Taille = 18, Couleur = C.TexteSecondaire, Parent = ligne })
	etiquette.LayoutOrder = 0

	local zoneBoutons = Instance.new("Frame")
	zoneBoutons.BackgroundTransparency = 1
	zoneBoutons.Size = UDim2.new(1, 0, 0, 0)
	zoneBoutons.AutomaticSize = Enum.AutomaticSize.Y
	zoneBoutons.LayoutOrder = 1
	zoneBoutons.Parent = ligne

	local rangementBoutons = Instance.new("UIListLayout")
	rangementBoutons.FillDirection = Enum.FillDirection.Horizontal
	rangementBoutons.Wraps = true -- trop de boutons : ils passent à la ligne
	rangementBoutons.SortOrder = Enum.SortOrder.LayoutOrder
	rangementBoutons.Padding = UDim.new(0, 8)
	rangementBoutons.Parent = zoneBoutons

	for numero, infos in boutons do
		local bouton, support = Theme.bouton({
			Texte = infos.Texte,
			TailleTexte = 17,
			Taille = Vector2.new(infos.Largeur or 120, HAUTEUR_BOUTON),
			Couleur = infos.Couleur or C.Principal,
			CouleurTexte = infos.CouleurTexte,
			Parent = zoneBoutons,
		})
		support.LayoutOrder = numero
		bouton.Activated:Connect(infos.Action)
	end
end

return function()
	if not RunService:IsStudio() then
		return -- jamais dans le jeu publié
	end
	local nomDataStore = ReplicatedStorage:GetAttribute("PanneauDebug")
	if nomDataStore == nil then
		-- Le serveur ne l'a peut-être pas encore posé : on attend un peu (ce module
		-- tourne de son côté, il ne bloque pas le reste de l'interface)
		task.wait(5)
		nomDataStore = ReplicatedStorage:GetAttribute("PanneauDebug")
	end
	if typeof(nomDataStore) ~= "string" then
		return -- mode debug pas activé : pas de panneau
	end
	local canal = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Debug", 10)
	if canal == nil then
		return
	end

	local function demander(action, valeur)
		return function()
			canal:FireServer(action, valeur)
		end
	end

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "PanneauDebug"
	ecran.ResetOnSpawn = false
	ecran.DisplayOrder = 50
	ecran.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Bouton qui ouvre et ferme le panneau, en bas à droite
	local ouvrir = Theme.bouton({
		Nom = "BoutonDebug",
		Texte = "Debug",
		TailleTexte = 18,
		Taille = Vector2.new(100, HAUTEUR_BOUTON),
		Couleur = COULEUR_DEBUG,
		CouleurTexte = C.Texte,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Parent = ecran,
	})

	local panneau, support = Theme.panneau(ecran, UDim2.new(0, LARGEUR, 1, -160), nil, COULEUR_DEBUG, 6)
	support.AnchorPoint = Vector2.new(1, 1)
	support.Position = UDim2.new(1, -16, 1, -80)
	support.Visible = false
	local limite = Instance.new("UISizeConstraint")
	limite.MaxSize = Vector2.new(LARGEUR, HAUTEUR_MAX)
	limite.Parent = support

	Theme.texte({
		Texte = "Panneau de debug (Studio)",
		Taille = 22,
		Position = UDim2.fromOffset(18, 12),
		TailleCadre = UDim2.new(1, -36, 0, 26),
		Parent = panneau,
	})
	Theme.texte({
		Texte = "Sauvegarde : " .. nomDataStore .. " (test)",
		Taille = 15,
		Couleur = C.TexteSecondaire,
		Position = UDim2.fromOffset(18, 40),
		TailleCadre = UDim2.new(1, -36, 0, 18),
		Parent = panneau,
	})

	-- Le contenu défile si l'écran est petit (téléphone)
	local contenu = Instance.new("ScrollingFrame")
	contenu.BackgroundTransparency = 1
	contenu.BorderSizePixel = 0
	contenu.Position = UDim2.fromOffset(18, 66)
	contenu.Size = UDim2.new(1, -30, 1, -78)
	contenu.CanvasSize = UDim2.new()
	contenu.AutomaticCanvasSize = Enum.AutomaticSize.Y
	contenu.ScrollBarThickness = 6
	contenu.ScrollingDirection = Enum.ScrollingDirection.Y
	contenu.Parent = panneau

	local rangement = Instance.new("UIListLayout")
	rangement.SortOrder = Enum.SortOrder.LayoutOrder
	rangement.Padding = UDim.new(0, 12)
	rangement.Parent = contenu

	ajouterLigne(contenu, 1, "Argent", {
		{ Texte = "+1 000 $", Couleur = C.Vendre, Action = demander("Argent", 1000) },
		{ Texte = "+100 000 $", Couleur = C.Vendre, Action = demander("Argent", 100000) },
		{ Texte = "+10 M $", Couleur = C.Vendre, Action = demander("Argent", 10000000) },
	})
	ajouterLigne(contenu, 2, "Débloquer une zone (gratuit)", {
		{ Texte = "Zone 2", Action = demander("Zone", "Zone2") },
		{ Texte = "Zone 3", Action = demander("Zone", "Zone3") },
	})

	local boutonsRarete = {}
	for _, infos in Reglages.Raretes do
		table.insert(boutonsRarete, {
			Texte = infos.Nom,
			Largeur = 124,
			Couleur = Theme.Raretes[infos.Nom],
			CouleurTexte = C.Texte,
			Action = demander("Rarete", infos.Nom),
		})
	end
	ajouterLigne(contenu, 3, "Rareté du prochain bonbon", boutonsRarete)

	ajouterLigne(contenu, 4, "Inventaire", {
		{ Texte = "Remplir", Action = demander("Inventaire", "Remplir") },
		{ Texte = "Vider", Couleur = C.Fermer, Action = demander("Inventaire", "Vider") },
	})
	ajouterLigne(contenu, 5, "Prochaine transformation de la sorcière", {
		{ Texte = "Réussite", Couleur = C.Vendre, Action = demander("Sorciere", "Reussite") },
		{ Texte = "Échec", Couleur = C.Fermer, Action = demander("Sorciere", "Echec") },
	})

	ouvrir.Activated:Connect(function()
		support.Visible = not support.Visible
	end)
end
