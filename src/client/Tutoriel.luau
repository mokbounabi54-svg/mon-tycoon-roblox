-- Petit tutoriel : quelques bulles de texte pendant les 2 premières minutes,
-- seulement pour un nouveau joueur (attribut "NouveauJoueur" posé par le serveur).
-- Bouton « OK » pour fermer une bulle, « Passer » pour ne plus en voir.
-- Textes, délais et interrupteur : Reglages.Tutoriel.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))

local C = Theme.Couleurs
local ATTENTE_MAX_ATTRIBUT = 15 -- secondes pour que le serveur ait chargé la sauvegarde

return function()
	local reglages = Reglages.Tutoriel
	if not reglages.Actif then
		return
	end
	local joueur = Players.LocalPlayer

	-- On attend de savoir si c'est un nouveau joueur (le serveur charge d'abord la sauvegarde)
	local debut = os.clock()
	while joueur:GetAttribute("NouveauJoueur") == nil and os.clock() - debut < ATTENTE_MAX_ATTRIBUT do
		task.wait(0.5)
	end
	if joueur:GetAttribute("NouveauJoueur") ~= true then
		return
	end

	local telephone = UserInputService.TouchEnabled
	local largeur = if telephone then 440 else 560
	local tailleTexte = if telephone then 16 else 20

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "Tutoriel"
	ecran.ResetOnSpawn = false
	ecran.DisplayOrder = 5 -- sous les panneaux (inventaire, carnet, sorcière)
	ecran.Parent = joueur:WaitForChild("PlayerGui")

	-- La bulle : en bas au centre (loin du joystick et du bouton de saut sur téléphone)
	-- Hauteur fixe : place pour 4 lignes de texte + les boutons
	local hauteur = 14 + 4 * (tailleTexte + 4) + 10 + 58 + 14
	local bulle, support = Theme.panneau(ecran, UDim2.fromOffset(largeur, hauteur), C.Panneau, C.OmbrePanneau, 6)
	support.Name = "Bulle"
	support.AnchorPoint = Vector2.new(0.5, 1)
	support.Position = UDim2.new(0.5, 0, 1, -24)
	support.Visible = false
	local marges = Instance.new("UIPadding")
	marges.PaddingTop = UDim.new(0, 14)
	marges.PaddingBottom = UDim.new(0, 14)
	marges.PaddingLeft = UDim.new(0, 18)
	marges.PaddingRight = UDim.new(0, 18)
	marges.Parent = bulle
	local rangement = Instance.new("UIListLayout")
	rangement.Padding = UDim.new(0, 10)
	rangement.SortOrder = Enum.SortOrder.LayoutOrder
	rangement.Parent = bulle

	local texte = Theme.texte({ Texte = "", Taille = tailleTexte, Parent = bulle })
	texte.Name = "Texte"
	texte.TextWrapped = true
	texte.TextYAlignment = Enum.TextYAlignment.Top
	texte.Size = UDim2.new(1, 0, 0, 4 * (tailleTexte + 4))
	texte.LayoutOrder = 1

	local ligneBoutons = Instance.new("Frame")
	ligneBoutons.Name = "Boutons"
	ligneBoutons.BackgroundTransparency = 1
	ligneBoutons.Size = UDim2.new(1, 0, 0, 58)
	ligneBoutons.LayoutOrder = 2
	ligneBoutons.Parent = bulle
	local passer = Theme.bouton({
		Nom = "Passer",
		Texte = "Passer",
		TailleTexte = tailleTexte,
		Couleur = C.FondZone,
		CouleurTexte = C.TexteSecondaire,
		CouleurOmbre = C.OmbrePanneau,
		Taille = Vector2.new(130, 52),
		Parent = ligneBoutons,
	})
	local ok = Theme.bouton({
		Nom = "OK",
		Texte = "OK !",
		TailleTexte = tailleTexte,
		Couleur = C.Principal,
		Taille = Vector2.new(110, 52),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = ligneBoutons,
	})

	local arrete = false
	local numeroAffiche = 0
	ok.Activated:Connect(function()
		support.Visible = false
	end)
	passer.Activated:Connect(function()
		arrete = true -- plus aucune bulle
		ecran:Destroy()
	end)

	local depart = os.clock()
	for numero, etape in reglages.Bulles do
		local attente = etape.Delai - (os.clock() - depart)
		if attente > 0 then
			task.wait(attente)
		end
		if arrete then
			return
		end
		numeroAffiche = numero
		texte.Text = etape.Texte
		support.Visible = true
		task.delay(reglages.DureeBulle, function()
			if numeroAffiche == numero and not arrete then
				support.Visible = false
			end
		end)
	end
end
