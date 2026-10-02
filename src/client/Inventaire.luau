-- L'écran d'inventaire (d'après docs/design/Inventaire (ordinateur) et (téléphone, paysage)).
--
-- L'écran ne fait QU'afficher ce que le serveur envoie et transmettre des demandes
-- (vendre, tout vendre, changer le seuil). Il n'envoie jamais de prix : c'est le
-- serveur qui calcule et vérifie tout (voir src/server/Inventaire.luau).
--
-- Deux mises en page : ordinateur (cartes en grille + détail) et téléphone en paysage
-- (cartes horizontales, détail compact), choisie avec UserInputService.TouchEnabled.
-- Toutes les tailles ci-dessous sont en pixels « de maquette » ; un UIScale agrandit ou
-- réduit le panneau selon l'écran, sans descendre sous EchelleMin (pour garder des
-- textes d'au moins 13 px et des zones cliquables d'au moins 44 px).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Reglages = require(Shared:WaitForChild("Reglages"))
local Format = require(Shared:WaitForChild("Format"))

local C = Theme.Couleurs

local MISES_EN_PAGE = {
	Ordinateur = {
		Largeur = 1080,
		Hauteur = 628,
		Marge = 32,
		MargeEcran = 20, -- espace minimum autour du panneau
		EchelleMin = 0.87, -- 15 px × 0.87 = 13 px ; 52 px × 0.87 = 45 px
		EchelleMax = 1.6,
		TitreY = 22,
		TailleTitre = 40,
		TailleCompteur = 22,
		Fermer = 52,
		Grille = { X = 32, Y = 100, Largeur = 708, Hauteur = 372, Colonnes = 4, CarteL = 160, CarteH = 175, Ecart = 16 },
		Carte = { Horizontale = false, Icone = 84, TailleNom = 20, TailleRarete = 15, Pastille = 12, TailleBadge = 16 },
		Detail = {
			X = 748, Y = 100, Largeur = 300, Hauteur = 418,
			Icone = 140, TailleNom = 30, TailleRarete = 21, TaillePrix = 18,
			BoutonL = 260, BoutonH = 52, TailleBouton = 22,
		},
		Bas = {
			Y = 536, Hauteur = 58, Libelle = "Garder à partir de", TailleLibelle = 18,
			PastilleH = 52, TaillePastille = 17, Remplissage = 18, Ecart = 10,
			ToutVendreL = 170, ToutVendreH = 52, TailleToutVendre = 22,
		},
		Confirmation = { Largeur = 460, Hauteur = 230, TailleTexte = 22, BoutonL = 190, BoutonH = 52 },
		Bouton = { Largeur = 160, Hauteur = 52, TailleTexte = 22 }, -- bouton « Inventaire » à l'écran
	},
	Telephone = {
		Largeur = 700,
		Hauteur = 334,
		Marge = 16,
		MargeEcran = 8,
		EchelleMin = 0.87,
		EchelleMax = 1.5,
		TitreY = 10,
		TailleTitre = 26,
		TailleCompteur = 18,
		Fermer = 52,
		-- 3 rangées visibles : 4 (marge) + 3 × 64 + 2 × 9 + 4 (contour) = 218
		Grille = { X = 16, Y = 58, Largeur = 484, Hauteur = 218, Colonnes = 3, CarteL = 150, CarteH = 64, Ecart = 9 },
		Carte = { Horizontale = true, Icone = 46, TailleNom = 16, TailleRarete = 15, Pastille = 10, TailleBadge = 15 },
		Detail = {
			X = 508, Y = 62, Largeur = 176, Hauteur = 210,
			Icone = 52, TailleNom = 18, TailleRarete = 15, TaillePrix = 15,
			BoutonL = 160, BoutonH = 52, TailleBouton = 18,
		},
		Bas = {
			Y = 278, Hauteur = 56, Libelle = "Garder dès", TailleLibelle = 15,
			PastilleH = 52, TaillePastille = 15, Remplissage = 11, Ecart = 6,
			ToutVendreL = 140, ToutVendreH = 52, TailleToutVendre = 18,
		},
		Confirmation = { Largeur = 400, Hauteur = 200, TailleTexte = 18, BoutonL = 170, BoutonH = 52 },
		Bouton = { Largeur = 140, Hauteur = 52, TailleTexte = 18 },
	},
}

local EPAISSEUR_OMBRE_PANNEAU = 10
local DELAI_MAX_ATTENTE = 1 -- s : si le serveur ne répond pas, on réactive les boutons
local MARGE_HAUT_MIN = 58 -- px laissés en haut pour le menu Roblox (hauteur de sa barre)

-- Rang de chaque rareté (1 = Commun) et ses réglages, d'après Reglages
local rangs, infosRarete = {}, {}
for rang, infos in Reglages.Raretes do
	rangs[infos.Nom] = rang
	infosRarete[infos.Nom] = infos
end
local ordreTypes = { Fraise = 1, Menthe = 2, Or = 3 }

--------------------------------------------------------------------------------
-- ICÔNES 3D (ViewportFrame) : le modèle « Moule » du type, aux couleurs de la rareté
--------------------------------------------------------------------------------

-- Une seule caméra partagée par toutes les icônes : chaque icône a sa propre copie
-- du bonbon, posée au même endroit (l'origine), donc la même vue convient à toutes.
local cameraIcones = Instance.new("Camera")
cameraIcones.FieldOfView = 30
cameraIcones.CFrame = CFrame.lookAt(Vector3.new(0, 1.9, -2.7), Vector3.new(0, -0.2, 0))

local function copierBonbonPourIcone(typeBonbon, nomRarete)
	local dossier = ReplicatedStorage:FindFirstChild("ModelesBonbons")
	local dossierType = dossier and dossier:FindFirstChild(typeBonbon)
	local source = dossierType and dossierType:FindFirstChild("Moule")

	local modele
	if source then
		modele = source:Clone()
	else
		-- Pas encore de modèle pour ce type : une boule de sa couleur
		modele = Instance.new("Model")
		local boule = Instance.new("Part")
		boule.Shape = Enum.PartType.Ball
		boule.Size = Vector3.one
		boule.Material = Enum.Material.SmoothPlastic
		local infosType = Reglages.Types[typeBonbon]
		boule.Color = infosType and infosType.Couleur or Color3.new(1, 1, 1)
		boule:SetAttribute("Teinte", true)
		boule.Parent = modele
	end

	-- Couleur et matière de la rareté sur les pièces Teinte, comme dans l'usine
	local infos = infosRarete[nomRarete]
	local matiere = infos and infos.Matiere and Enum.Material[infos.Matiere]
	for _, piece in modele:GetDescendants() do
		if piece:IsA("BasePart") and piece:GetAttribute("Teinte") then
			if infos and infos.Couleur then
				piece.Color = infos.Couleur
			end
			if matiere then
				piece.Material = matiere
			end
		end
	end
	modele:PivotTo(CFrame.new())
	return modele
end

local function creerIcone(parent, typeBonbon, nomRarete, taille, position)
	local vue = Instance.new("ViewportFrame")
	vue.Name = "Icone"
	vue.BackgroundTransparency = 1
	vue.Size = UDim2.fromOffset(taille, taille)
	vue.Position = position
	vue.CurrentCamera = cameraIcones
	vue.Ambient = Color3.fromRGB(190, 180, 200)
	vue.LightColor = Color3.new(1, 1, 1)
	vue.LightDirection = Vector3.new(-0.5, -1, 0.6)
	vue:SetAttribute("Type", typeBonbon)
	vue:SetAttribute("Rarete", nomRarete)
	vue.Parent = parent
	return vue
end

-- Met (ou retire) le bonbon dans une icône. On ne garde des bonbons 3D que dans
-- les icônes visibles, pour rester léger.
local function remplirIcone(vue, visible)
	local dejaRemplie = vue:FindFirstChildOfClass("Model") ~= nil
	if visible and not dejaRemplie then
		copierBonbonPourIcone(vue:GetAttribute("Type"), vue:GetAttribute("Rarete")).Parent = vue
	elseif not visible and dejaRemplie then
		vue:FindFirstChildOfClass("Model"):Destroy()
	end
end

--------------------------------------------------------------------------------
-- PETITES AIDES
--------------------------------------------------------------------------------

local function largeurTexte(texte, taille)
	return TextService:GetTextSize(texte, taille, Theme.Police, Vector2.new(2000, 200)).X
end

-- « ● Rare » : pastille + nom de rareté (+ suite éventuelle), alignés horizontalement
local function ligneRarete(parent, nomRarete, suite, tailleTexte, diametre, couleurTexte, centre)
	local ligne = Instance.new("Frame")
	ligne.Name = "LigneRarete"
	ligne.BackgroundTransparency = 1
	ligne.Size = UDim2.new(1, 0, 0, tailleTexte + 6)
	ligne.Parent = parent

	local rangement = Instance.new("UIListLayout")
	rangement.FillDirection = Enum.FillDirection.Horizontal
	rangement.VerticalAlignment = Enum.VerticalAlignment.Center
	rangement.HorizontalAlignment = if centre then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left
	rangement.Padding = UDim.new(0, 6)
	rangement.Parent = ligne

	Theme.pastille(ligne, nomRarete, diametre)
	local texte = Theme.texte({
		Texte = nomRarete .. (suite or ""),
		Taille = tailleTexte,
		Couleur = couleurTexte or C.TexteSecondaire,
		Parent = ligne,
	})
	texte.AutomaticSize = Enum.AutomaticSize.X
	texte.Size = UDim2.fromOffset(0, tailleTexte + 4)
	return ligne
end

local function trierPiles(piles)
	local triees = table.clone(piles)
	table.sort(triees, function(a, b)
		local ra, rb = rangs[a.Rarete] or 0, rangs[b.Rarete] or 0
		if ra ~= rb then
			return ra > rb -- rareté décroissante
		end
		if a.Quantite ~= b.Quantite then
			return a.Quantite > b.Quantite -- puis quantité décroissante
		end
		local ta, tb = ordreTypes[a.Type] or 99, ordreTypes[b.Type] or 99
		if ta ~= tb then
			return ta < tb
		end
		return a.Cle < b.Cle
	end)
	return triees
end

--------------------------------------------------------------------------------
-- LE PANNEAU
--------------------------------------------------------------------------------

local InterfaceInventaire = {}

-- Crée le panneau d'inventaire dans "conteneur" (un ScreenGui, ou un Frame pour les tests).
-- options :
--   Telephone (bool)       : mise en page téléphone
--   TailleEcran (Vector2)  : taille d'écran à simuler (tests) ; sinon celle du conteneur
--   MargeHaut (nombre)     : place laissée en haut pour le menu Roblox
--   Vendre(cle, quantite), ToutVendre(), ChoisirSeuil(nom) : demandes au serveur
-- Renvoie un objet avec : afficher(donnees), ouvrir(), fermer(), basculer(), estOuvert(),
-- adapter(), et les éléments (panneau, support...) pour les tests.
function InterfaceInventaire.creer(conteneur, options)
	local mise = if options.Telephone then MISES_EN_PAGE.Telephone else MISES_EN_PAGE.Ordinateur
	local interface = { mise = mise }
	local donnees = nil -- dernier inventaire reçu du serveur
	local selection = nil -- clé de la pile sélectionnée
	local ouvert = false
	local enAttente = false -- une demande est partie, on attend la réponse du serveur

	-- Fond assombri : un clic dessus ferme le panneau
	local voile = Instance.new("TextButton")
	voile.Name = "Voile"
	voile.Text = ""
	voile.AutoButtonColor = false
	voile.BackgroundColor3 = C.Voile
	voile.BackgroundTransparency = 0.45
	voile.BorderSizePixel = 0
	voile.Size = UDim2.fromScale(1, 1)
	voile.Visible = false
	voile.ZIndex = 1
	voile.Parent = conteneur

	local panneau, support = Theme.panneau(conteneur, UDim2.fromOffset(mise.Largeur, mise.Hauteur), C.Panneau, C.OmbrePanneau, EPAISSEUR_OMBRE_PANNEAU)
	support.Name = "PanneauInventaire"
	support.AnchorPoint = Vector2.new(0.5, 0.5)
	support.Visible = false
	support.ZIndex = 2
	panneau.Active = true -- un clic sur le panneau ne doit pas atteindre le voile (qui fermerait)
	local echelle = Instance.new("UIScale")
	echelle.Parent = support
	interface.voile, interface.support, interface.panneau, interface.echelle = voile, support, panneau, echelle

	-- Titre et compteur
	local titre = Instance.new("Frame")
	titre.Name = "Titre"
	titre.BackgroundTransparency = 1
	titre.Position = UDim2.fromOffset(mise.Marge, mise.TitreY)
	titre.Size = UDim2.fromOffset(mise.Largeur / 2, mise.TailleTitre + 8)
	titre.Parent = panneau
	local rangementTitre = Instance.new("UIListLayout")
	rangementTitre.FillDirection = Enum.FillDirection.Horizontal
	rangementTitre.VerticalAlignment = Enum.VerticalAlignment.Bottom
	rangementTitre.Padding = UDim.new(0, 14)
	rangementTitre.SortOrder = Enum.SortOrder.LayoutOrder
	rangementTitre.Parent = titre
	local texteTitre = Theme.texte({ Texte = "Inventaire", Taille = mise.TailleTitre, Parent = titre })
	texteTitre.AutomaticSize = Enum.AutomaticSize.X
	texteTitre.Size = UDim2.fromOffset(0, mise.TailleTitre + 4)
	texteTitre.LayoutOrder = 1
	local compteur = Theme.texte({ Texte = "0 / 0", Taille = mise.TailleCompteur, Couleur = C.TexteSecondaire, Parent = titre })
	compteur.Name = "Compteur"
	compteur.LayoutOrder = 2
	compteur.AutomaticSize = Enum.AutomaticSize.X
	compteur.Size = UDim2.fromOffset(0, mise.TailleCompteur + 6)
	interface.compteur = compteur

	-- Bouton fermer (rond rose)
	local fermer = Theme.bouton({
		Nom = "Fermer",
		Texte = "×",
		TailleTexte = math.floor(mise.Fermer * 0.7),
		Couleur = C.Fermer,
		Taille = Vector2.new(mise.Fermer, mise.Fermer),
		EpaisseurOmbre = 4,
		Position = UDim2.fromOffset(mise.Largeur - mise.Marge - mise.Fermer, mise.TitreY - 4),
		Parent = panneau,
	})
	interface.boutonFermer = fermer

	-- Grille des piles (défile si elle est trop longue)
	local g = mise.Grille
	local grille = Instance.new("ScrollingFrame")
	grille.Name = "Grille"
	grille.BackgroundTransparency = 1
	grille.BorderSizePixel = 0
	grille.Position = UDim2.fromOffset(g.X, g.Y)
	grille.Size = UDim2.fromOffset(g.Largeur, g.Hauteur)
	grille.ScrollingDirection = Enum.ScrollingDirection.Y
	grille.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grille.CanvasSize = UDim2.new()
	grille.ScrollBarThickness = 6
	grille.ScrollBarImageColor3 = C.OmbrePanneau
	grille.Parent = panneau
	local marges = Instance.new("UIPadding")
	marges.PaddingTop = UDim.new(0, 4)
	marges.PaddingLeft = UDim.new(0, 4)
	marges.PaddingBottom = UDim.new(0, 4)
	marges.Parent = grille
	local grilleRangement = Instance.new("UIGridLayout")
	grilleRangement.CellSize = UDim2.fromOffset(g.CarteL, g.CarteH)
	grilleRangement.CellPadding = UDim2.fromOffset(g.Ecart, g.Ecart)
	grilleRangement.SortOrder = Enum.SortOrder.LayoutOrder
	grilleRangement.Parent = grille
	interface.grille = grille

	local messageVide = Theme.texte({
		Texte = "",
		Taille = mise.Carte.TailleNom,
		Couleur = C.TexteSecondaire,
		Alignement = Enum.TextXAlignment.Center,
		TailleCadre = UDim2.fromOffset(g.Largeur, g.Hauteur),
		Position = UDim2.fromOffset(g.X, g.Y),
		Parent = panneau,
	})
	messageVide.Name = "MessageVide"
	messageVide.TextWrapped = true

	-- Panneau de détail (à droite)
	local d = mise.Detail
	local detail = Instance.new("Frame")
	detail.Name = "Detail"
	detail.BackgroundColor3 = C.FondZone
	detail.BorderSizePixel = 0
	detail.Position = UDim2.fromOffset(d.X, d.Y)
	detail.Size = UDim2.fromOffset(d.Largeur, d.Hauteur)
	Theme.arrondir(detail, Theme.ArrondiCarte + 4)
	detail.Parent = panneau
	interface.detail = detail

	local infosDetail = Instance.new("Frame") -- icône + textes, refait à chaque sélection
	infosDetail.Name = "Infos"
	infosDetail.BackgroundTransparency = 1
	infosDetail.Size = UDim2.fromScale(1, 1)
	infosDetail.Parent = detail

	local boutonsY = if options.Telephone then 92 else 280
	local vendre1, supportVendre1 = Theme.bouton({
		Nom = "Vendre1",
		Texte = "Vendre 1",
		TailleTexte = d.TailleBouton,
		Couleur = C.Vendre,
		Taille = Vector2.new(d.BoutonL, d.BoutonH),
		Position = UDim2.fromOffset((d.Largeur - d.BoutonL) / 2, boutonsY),
		Parent = detail,
	})
	local vendreTout, supportVendreTout = Theme.bouton({
		Nom = "VendreLesN",
		Texte = "Vendre les 2",
		TailleTexte = d.TailleBouton,
		Couleur = C.Vendre,
		Taille = Vector2.new(d.BoutonL, d.BoutonH),
		Position = UDim2.fromOffset((d.Largeur - d.BoutonL) / 2, boutonsY + d.BoutonH + Theme.EpaisseurOmbre + 2),
		Parent = detail,
	})
	interface.boutonVendre1, interface.boutonVendreLesN = vendre1, vendreTout

	-- Barre du bas : « Garder à partir de » + choix du seuil, et « Tout vendre »
	local b = mise.Bas
	local libelle = Theme.texte({ Texte = b.Libelle, Taille = b.TailleLibelle, Parent = panneau })
	libelle.Name = "LibelleSeuil"
	libelle.Size = UDim2.fromOffset(largeurTexte(b.Libelle, b.TailleLibelle) + 4, b.Hauteur)
	libelle.Position = UDim2.fromOffset(mise.Marge, b.Y)

	local pastillesSeuil = {}
	local x = mise.Marge + libelle.Size.X.Offset + b.Ecart + 4
	for _, nom in Reglages.Inventaire.ChoixSeuil do
		local largeur = math.max(largeurTexte(nom, b.TaillePastille) + 2 * b.Remplissage, b.PastilleH)
		local choix = Instance.new("TextButton")
		choix.Name = "Seuil_" .. nom
		choix.AutoButtonColor = false
		choix.Font = Theme.Police
		choix.Text = nom
		choix.TextSize = b.TaillePastille
		choix.Size = UDim2.fromOffset(largeur, b.PastilleH)
		choix.Position = UDim2.fromOffset(x, b.Y + (b.Hauteur - b.PastilleH) / 2)
		Theme.arrondir(choix, math.floor(b.PastilleH / 2))
		local trait = Theme.bordure(choix, Color3.fromHex("E0D3F3"), 2)
		choix.Parent = panneau
		pastillesSeuil[nom] = { bouton = choix, trait = trait }
		x += largeur + b.Ecart
	end
	interface.pastillesSeuil = pastillesSeuil

	local toutVendre = Theme.bouton({
		Nom = "ToutVendre",
		Texte = "Tout vendre",
		TailleTexte = b.TailleToutVendre,
		Couleur = C.ToutVendre,
		CouleurTexte = C.TexteToutVendre,
		Taille = Vector2.new(b.ToutVendreL, b.ToutVendreH),
		Position = UDim2.fromOffset(mise.Largeur - mise.Marge - b.ToutVendreL, b.Y + (b.Hauteur - b.ToutVendreH - Theme.EpaisseurOmbre) / 2),
		Parent = panneau,
	})
	interface.boutonToutVendre = toutVendre

	-- Fenêtre de confirmation (avant de tout vendre s'il y a des bonbons Épiques ou mieux)
	local cf = mise.Confirmation
	local voileConfirmation = Instance.new("TextButton")
	voileConfirmation.Name = "Confirmation"
	voileConfirmation.Text = ""
	voileConfirmation.AutoButtonColor = false
	voileConfirmation.BackgroundColor3 = C.Voile
	voileConfirmation.BackgroundTransparency = 0.5
	voileConfirmation.Size = UDim2.fromScale(1, 1)
	voileConfirmation.Visible = false
	voileConfirmation.ZIndex = 20
	Theme.arrondir(voileConfirmation)
	voileConfirmation.Parent = panneau
	local boite = Theme.panneau(voileConfirmation, UDim2.fromOffset(cf.Largeur, cf.Hauteur), C.Panneau, C.OmbrePanneau, 8)
	boite.Active = true
	boite.Parent.AnchorPoint = Vector2.new(0.5, 0.5)
	boite.Parent.Position = UDim2.fromScale(0.5, 0.5)
	local question = Theme.texte({
		Texte = "Tu as des bonbons Épiques ou mieux.\nTout vendre quand même ?",
		Taille = cf.TailleTexte,
		Alignement = Enum.TextXAlignment.Center,
		TailleCadre = UDim2.new(1, -32, 0, cf.Hauteur - cf.BoutonH - 50),
		Position = UDim2.fromOffset(16, 14),
		Parent = boite,
	})
	question.TextWrapped = true
	local annuler = Theme.bouton({
		Nom = "Annuler",
		Texte = "Annuler",
		TailleTexte = cf.TailleTexte,
		Couleur = C.FondZone,
		CouleurTexte = C.Texte,
		CouleurOmbre = C.OmbrePanneau,
		Taille = Vector2.new(cf.BoutonL, cf.BoutonH),
		Position = UDim2.new(0.5, -cf.BoutonL - 8, 1, -cf.BoutonH - 24),
		Parent = boite,
	})
	local confirmer = Theme.bouton({
		Nom = "Confirmer",
		Texte = "Tout vendre",
		TailleTexte = cf.TailleTexte,
		Couleur = C.ToutVendre,
		CouleurTexte = C.TexteToutVendre,
		Taille = Vector2.new(cf.BoutonL, cf.BoutonH),
		Position = UDim2.new(0.5, 8, 1, -cf.BoutonH - 24),
		Parent = boite,
	})
	interface.confirmation, interface.boutonConfirmer, interface.boutonAnnuler = voileConfirmation, confirmer, annuler

	----------------------------------------------------------------------------
	-- Mise à jour de l'affichage
	----------------------------------------------------------------------------

	local function pileSelectionnee()
		if donnees == nil then
			return nil
		end
		for _, pile in donnees.Piles do
			if pile.Cle == selection then
				return pile
			end
		end
		return nil
	end

	-- Ne remplit que les icônes des cartes visibles dans la grille
	local function rafraichirIcones()
		local haut = grille.AbsolutePosition.Y
		local bas = haut + grille.AbsoluteSize.Y
		for _, carte in grille:GetChildren() do
			local vue = carte:IsA("GuiButton") and carte:FindFirstChild("Icone")
			if vue then
				local visible = ouvert and carte.AbsolutePosition.Y + carte.AbsoluteSize.Y > haut and carte.AbsolutePosition.Y < bas
				remplirIcone(vue, visible)
			end
		end
	end
	grille:GetPropertyChangedSignal("CanvasPosition"):Connect(rafraichirIcones)

	local function majBoutonsAttente()
		local actif = not enAttente
		for _, bouton in { vendre1, vendreTout, toutVendre, confirmer } do
			bouton.Active = actif
			bouton.AutoButtonColor = false
			bouton.BackgroundTransparency = if actif then 0 else 0.35
		end
	end

	local function attendreServeur()
		enAttente = true
		majBoutonsAttente()
		local jeton = {}
		interface.jetonAttente = jeton
		task.delay(DELAI_MAX_ATTENTE, function()
			if interface.jetonAttente == jeton and enAttente then
				enAttente = false
				majBoutonsAttente()
			end
		end)
	end

	local majDetail -- déclarée plus bas

	local function creerCarte(pile, ordre)
		local c = mise.Carte
		local carte = Instance.new("TextButton")
		carte.Name = pile.Cle
		carte.Text = ""
		carte.AutoButtonColor = false
		carte.BackgroundColor3 = C.Panneau
		carte.LayoutOrder = ordre
		Theme.arrondir(carte, if c.Horizontale then 18 else Theme.ArrondiCarte)
		local choisie = pile.Cle == selection
		Theme.bordure(carte, if choisie then C.Principal else C.BordureCarte, if choisie then 4 else 3)

		if c.Horizontale then
			-- Téléphone : icône à gauche, textes à droite
			creerIcone(carte, pile.Type, pile.Rarete, c.Icone, UDim2.fromOffset(6, (g.CarteH - c.Icone) / 2))
			local nom = Theme.texte({ Texte = pile.Type, Taille = c.TailleNom, Parent = carte, Position = UDim2.fromOffset(c.Icone + 12, 6) })
			nom.Size = UDim2.fromOffset(g.CarteL - c.Icone - 16, c.TailleNom + 4)
			Theme.pastille(carte, pile.Rarete, c.Pastille).Position = UDim2.fromOffset(c.Icone + 12, 30 + (c.TailleRarete - c.Pastille) / 2 + 2)
			local rarete = Theme.texte({
				Texte = pile.Rarete,
				Taille = c.TailleRarete,
				Couleur = C.TexteSecondaire,
				Parent = carte,
				Position = UDim2.fromOffset(c.Icone + 12 + c.Pastille + 4, 28),
				TailleCadre = UDim2.fromOffset(g.CarteL - (c.Icone + 12 + c.Pastille + 4) - 4, g.CarteH - 30),
			})
			rarete.Name = "Rarete"
			rarete.TextWrapped = true
			rarete.TextYAlignment = Enum.TextYAlignment.Top
		else
			-- Ordinateur : icône en haut, nom, puis rareté
			creerIcone(carte, pile.Type, pile.Rarete, c.Icone, UDim2.fromOffset((g.CarteL - c.Icone) / 2, 18))
			local nom = Theme.texte({
				Texte = pile.Type,
				Taille = c.TailleNom,
				Parent = carte,
				Alignement = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 108),
			})
			nom.Size = UDim2.new(1, 0, 0, c.TailleNom + 4)
			ligneRarete(carte, pile.Rarete, nil, c.TailleRarete, c.Pastille, nil, true).Position = UDim2.fromOffset(0, 136)
		end

		-- Pastille sombre de quantité (« ×14 ») en haut à droite
		local badge = Theme.texte({
			Texte = "×" .. pile.Quantite,
			Taille = c.TailleBadge,
			Couleur = C.TexteClair,
			Alignement = Enum.TextXAlignment.Center,
			Parent = carte,
		})
		badge.Name = "Badge"
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = C.Badge
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -6, 0, 6)
		badge.Size = UDim2.fromOffset(largeurTexte(badge.Text, c.TailleBadge) + 16, c.TailleBadge + 8)
		badge.ZIndex = 3
		Theme.arrondir(badge, 12)

		carte.Activated:Connect(function()
			selection = pile.Cle
			interface.afficher(donnees)
		end)
		carte.Parent = grille
	end

	function majDetail()
		infosDetail:ClearAllChildren()
		local pile = pileSelectionnee()
		supportVendre1.Visible = pile ~= nil
		supportVendreTout.Visible = pile ~= nil and pile.Quantite > 1
		if pile == nil then
			local vide = Theme.texte({
				Texte = "Choisis un bonbon",
				Taille = d.TaillePrix,
				Couleur = C.TexteSecondaire,
				Alignement = Enum.TextXAlignment.Center,
				TailleCadre = UDim2.fromScale(1, 1),
				Parent = infosDetail,
			})
			vide.TextWrapped = true
			return
		end

		local prixTexte = if pile.PrixUnitaire then Format.nombre(pile.PrixUnitaire) .. " $ l'unité" else "?"
		local suite = " · ×" .. pile.Quantite
		if options.Telephone then
			-- Compact : icône à gauche, nom et rareté à droite, prix dessous
			creerIcone(infosDetail, pile.Type, pile.Rarete, d.Icone, UDim2.fromOffset(8, 8))
			remplirIcone(infosDetail.Icone, ouvert)
			local nom = Theme.texte({ Texte = pile.Type, Taille = d.TailleNom, Parent = infosDetail, Position = UDim2.fromOffset(d.Icone + 14, 10) })
			nom.Size = UDim2.fromOffset(d.Largeur - d.Icone - 20, d.TailleNom + 4)
			local rarete = Theme.texte({
				Texte = pile.Rarete .. suite,
				Taille = d.TailleRarete,
				Parent = infosDetail,
				Position = UDim2.fromOffset(d.Icone + 14, 36),
				TailleCadre = UDim2.fromOffset(d.Largeur - d.Icone - 20, d.TailleRarete + 4),
			})
			rarete.Name = "Rarete"
			local prix = Theme.texte({
				Texte = prixTexte,
				Taille = d.TaillePrix,
				Couleur = C.TexteSecondaire,
				Parent = infosDetail,
				Position = UDim2.fromOffset(8, 64),
				TailleCadre = UDim2.fromOffset(d.Largeur - 16, d.TaillePrix + 4),
			})
			prix.Name = "Prix"
		else
			creerIcone(infosDetail, pile.Type, pile.Rarete, d.Icone, UDim2.fromOffset((d.Largeur - d.Icone) / 2, 14))
			remplirIcone(infosDetail.Icone, ouvert)
			local nom = Theme.texte({
				Texte = pile.Type,
				Taille = d.TailleNom,
				Alignement = Enum.TextXAlignment.Center,
				Parent = infosDetail,
				Position = UDim2.fromOffset(0, 164),
			})
			nom.Size = UDim2.new(1, 0, 0, d.TailleNom + 4)
			ligneRarete(infosDetail, pile.Rarete, suite, d.TailleRarete, 16, C.Texte, true).Position = UDim2.fromOffset(0, 204)
			local prix = Theme.texte({
				Texte = prixTexte,
				Taille = d.TaillePrix,
				Couleur = C.TexteSecondaire,
				Alignement = Enum.TextXAlignment.Center,
				Parent = infosDetail,
				Position = UDim2.fromOffset(0, 238),
			})
			prix.Name = "Prix"
			prix.Size = UDim2.new(1, 0, 0, d.TaillePrix + 4)
		end
		vendreTout.Text = "Vendre les " .. pile.Quantite
	end

	-- Affiche l'inventaire envoyé par le serveur
	function interface.afficher(nouvellesDonnees)
		donnees = nouvellesDonnees
		enAttente = false
		majBoutonsAttente()
		if donnees == nil then
			return
		end

		compteur.Text = donnees.Total .. " / " .. donnees.Capacite

		-- La sélection reste sur la même pile ; si elle n'existe plus, on prend la première
		local piles = trierPiles(donnees.Piles)
		if pileSelectionnee() == nil then
			selection = if piles[1] then piles[1].Cle else nil
		end

		for _, enfant in grille:GetChildren() do
			if enfant:IsA("GuiButton") then
				enfant:Destroy()
			end
		end
		for ordre, pile in piles do
			creerCarte(pile, ordre)
		end
		messageVide.Visible = #piles == 0
		messageVide.Text = "Ton inventaire est vide.\nLes bonbons « " .. donnees.Seuil .. " » et mieux arrivent ici."

		for nom, choix in pastillesSeuil do
			local actif = nom == donnees.Seuil
			choix.bouton.BackgroundColor3 = if actif then C.Principal else C.Panneau
			choix.bouton.TextColor3 = if actif then C.TexteClair else C.Texte
			choix.trait.Enabled = not actif
		end

		majDetail()
		task.defer(rafraichirIcones) -- après que la grille a placé les cartes
	end

	----------------------------------------------------------------------------
	-- Taille à l'écran, ouverture, fermeture
	----------------------------------------------------------------------------

	function interface.adapter()
		local tailleEcran = options.TailleEcran or conteneur.AbsoluteSize
		local margeHaut = options.MargeHaut
		if typeof(margeHaut) == "function" then
			margeHaut = margeHaut()
		end
		margeHaut = margeHaut or 0
		local largeurDispo = tailleEcran.X - 2 * mise.MargeEcran
		local hauteurDispo = tailleEcran.Y - margeHaut - mise.MargeEcran
		local facteur = math.min(largeurDispo / mise.Largeur, hauteurDispo / (mise.Hauteur + EPAISSEUR_OMBRE_PANNEAU))
		echelle.Scale = math.clamp(facteur, mise.EchelleMin, mise.EchelleMax)
		-- Centré dans la place libre sous le menu Roblox
		support.Position = UDim2.new(0.5, 0, 0, margeHaut + hauteurDispo / 2)
	end

	function interface.ouvrir()
		ouvert = true
		voile.Visible = true
		support.Visible = true
		voileConfirmation.Visible = false
		interface.adapter()
		interface.afficher(donnees)
	end

	function interface.fermer()
		ouvert = false
		voile.Visible = false
		support.Visible = false
		rafraichirIcones() -- vide les icônes 3D
		if infosDetail:FindFirstChild("Icone") then
			remplirIcone(infosDetail.Icone, false)
		end
	end

	function interface.basculer()
		if ouvert then
			interface.fermer()
		else
			interface.ouvrir()
		end
	end

	function interface.estOuvert()
		return ouvert
	end

	----------------------------------------------------------------------------
	-- Boutons : on n'envoie que des DEMANDES au serveur
	----------------------------------------------------------------------------

	voile.Activated:Connect(interface.fermer)
	fermer.Activated:Connect(interface.fermer)

	vendre1.Activated:Connect(function()
		local pile = pileSelectionnee()
		if pile and not enAttente then
			attendreServeur()
			options.Vendre(pile.Cle, 1)
		end
	end)
	vendreTout.Activated:Connect(function()
		local pile = pileSelectionnee()
		if pile and not enAttente then
			attendreServeur()
			options.Vendre(pile.Cle, pile.Quantite)
		end
	end)

	local function envoyerToutVendre()
		voileConfirmation.Visible = false
		if not enAttente then
			attendreServeur()
			options.ToutVendre()
		end
	end
	toutVendre.Activated:Connect(function()
		if donnees == nil or #donnees.Piles == 0 or enAttente then
			return
		end
		-- Confirmation s'il y a au moins un bonbon Épique ou mieux
		for _, pile in donnees.Piles do
			if (rangs[pile.Rarete] or 0) >= rangs["Épique"] then
				voileConfirmation.Visible = true
				return
			end
		end
		envoyerToutVendre()
	end)
	confirmer.Activated:Connect(envoyerToutVendre)
	annuler.Activated:Connect(function()
		voileConfirmation.Visible = false
	end)
	voileConfirmation.Activated:Connect(function()
		voileConfirmation.Visible = false
	end)

	for nom, choix in pastillesSeuil do
		choix.bouton.Activated:Connect(function()
			if donnees and donnees.Seuil ~= nom then
				options.ChoisirSeuil(nom)
			end
		end)
	end

	return interface
end

--------------------------------------------------------------------------------
-- DÉMARRAGE DANS LE JEU
--------------------------------------------------------------------------------

function InterfaceInventaire.demarrer()
	local joueur = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local majInventaire = remotes:WaitForChild("InventaireMaj")
	local demanderInventaire = remotes:WaitForChild("DemanderInventaire")
	local vendreBonbons = remotes:WaitForChild("VendreBonbons")
	local toutVendre = remotes:WaitForChild("ToutVendre")
	local choisirSeuil = remotes:WaitForChild("ChoisirSeuil")

	local telephone = UserInputService.TouchEnabled
	local mise = if telephone then MISES_EN_PAGE.Telephone else MISES_EN_PAGE.Ordinateur

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "Inventaire"
	ecran.ResetOnSpawn = false
	ecran.IgnoreGuiInset = true -- le voile couvre tout l'écran ; on gère nous-mêmes la marge du haut
	ecran.DisplayOrder = 10
	ecran.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ecran.Parent = joueur:WaitForChild("PlayerGui")
	cameraIcones.Parent = ecran

	local interface = InterfaceInventaire.creer(ecran, {
		Telephone = telephone,
		-- Place laissée en haut pour la barre et le menu Roblox (recalculée à chaque
		-- ouverture : la barre n'a pas toujours sa taille finale au démarrage)
		MargeHaut = function()
			return math.max(GuiService:GetGuiInset().Y, MARGE_HAUT_MIN)
		end,
		Vendre = function(cle, quantite)
			vendreBonbons:FireServer(cle, quantite)
		end,
		ToutVendre = function()
			toutVendre:FireServer()
		end,
		ChoisirSeuil = function(nom)
			choisirSeuil:FireServer(nom)
		end,
	})

	-- Bouton « Inventaire » sur le côté gauche, à mi-hauteur : loin du menu Roblox
	-- (en haut à gauche), du joystick et du bouton de saut (en bas) sur téléphone.
	local bouton = Theme.bouton({
		Nom = "BoutonInventaire",
		Texte = "Inventaire",
		TailleTexte = mise.Bouton.TailleTexte,
		Couleur = C.Principal,
		Taille = Vector2.new(mise.Bouton.Largeur, mise.Bouton.Hauteur),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Parent = ecran,
	})
	bouton.Activated:Connect(interface.basculer)

	-- Touche I sur ordinateur (sauf quand on écrit dans le chat)
	UserInputService.InputBegan:Connect(function(entree, dejaUtilisee)
		if not dejaUtilisee and entree.KeyCode == Enum.KeyCode.I then
			interface.basculer()
		end
	end)

	-- Le panneau suit la taille de l'écran (rotation, fenêtre redimensionnée)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if interface.estOuvert() then
			interface.adapter()
		end
	end)

	-- Son doux quand une vente rapporte de l'argent
	local sonVente = Instance.new("Sound")
	sonVente.SoundId = Theme.Sons.Vente.Id
	sonVente.Volume = Theme.Sons.Vente.Volume
	sonVente.PlaybackSpeed = Theme.Sons.Vente.Vitesse
	sonVente.Parent = ecran

	majInventaire.OnClientEvent:Connect(function(donnees)
		interface.afficher(donnees)
		if typeof(donnees.Vente) == "number" and donnees.Vente > 0 then
			sonVente:Play()
		end
	end)
	demanderInventaire:FireServer()
end

return InterfaceInventaire
