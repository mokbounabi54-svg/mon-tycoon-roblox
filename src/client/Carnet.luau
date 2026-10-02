-- L'écran du carnet de collection (d'après docs/design/Carnet de collection (ordinateur)).
--
-- Une grille : une ligne par type (Fraise, Menthe, Or), une colonne par rareté.
-- Combinaison découverte : le bonbon en couleur, bordure de la couleur de la rareté.
-- Pas encore découverte : silhouette grise avec « ? ».
-- Badge « Nouveau ! » sur les combinaisons découvertes depuis la dernière ouverture.
--
-- Comme l'inventaire, l'écran ne fait qu'afficher ce que le serveur envoie (CarnetMaj).
-- Mise en page ordinateur ou téléphone en paysage (UserInputService.TouchEnabled),
-- tailles en pixels de maquette + UIScale borné (textes ≥ 13 px, boutons ≥ 44 px).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Icones = require(script.Parent:WaitForChild("Icones"))
local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))

local C = Theme.Couleurs
local EPAISSEUR_OMBRE_PANNEAU = 10
local MARGE_HAUT_MIN = 58 -- px laissés en haut pour le menu Roblox
local COULEUR_NOUVEAU = Theme.Raretes["Mythique"]
local FOND_INCONNU = Color3.fromHex("EFE7F8")
local BORDURE_INCONNUE = Color3.fromHex("DCCFEA")

local MISES_EN_PAGE = {
	Ordinateur = {
		Largeur = 1080, Hauteur = 628, Marge = 32, MargeEcran = 20,
		EchelleMin = 0.87, EchelleMax = 1.6,
		TitreY = 22, TailleTitre = 40, TailleCompteur = 22, Fermer = 52,
		BarreY = 96, BarreH = 16,
		EnteteY = 124, TailleEntete = 17,
		LigneY = 156, Etiquette = 130, CaseL = 135, CaseH = 136, Ecart = 12, EcartLignes = 12,
		TailleType = 26, Icone = 84, TailleQuestion = 30, TailleNouveau = 15,
		Bouton = { Largeur = 160, Hauteur = 52, TailleTexte = 22 },
	},
	Telephone = {
		Largeur = 700, Hauteur = 336, Marge = 16, MargeEcran = 8,
		EchelleMin = 0.87, EchelleMax = 1.5,
		TitreY = 10, TailleTitre = 26, TailleCompteur = 18, Fermer = 52,
		BarreY = 66, BarreH = 12,
		EnteteY = 82, TailleEntete = 15,
		LigneY = 104, Etiquette = 92, CaseL = 88, CaseH = 70, Ecart = 8, EcartLignes = 6,
		TailleType = 18, Icone = 50, TailleQuestion = 22, TailleNouveau = 15,
		Bouton = { Largeur = 140, Hauteur = 52, TailleTexte = 18 },
	},
}

local InterfaceCarnet = {}

-- Crée le panneau dans "conteneur" (ScreenGui, ou Frame pour les tests).
-- options : Telephone, TailleEcran (tests), MargeHaut (nombre ou fonction)
function InterfaceCarnet.creer(conteneur, options)
	local mise = if options.Telephone then MISES_EN_PAGE.Telephone else MISES_EN_PAGE.Ordinateur
	local interface = { mise = mise }
	local donnees = nil
	local nouveaux = {} -- clés découvertes depuis la dernière ouverture (badge « Nouveau ! »)
	local ouvert = false

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
	support.Name = "PanneauCarnet"
	support.AnchorPoint = Vector2.new(0.5, 0.5)
	support.Visible = false
	support.ZIndex = 2
	panneau.Active = true -- un clic sur le panneau ne doit pas atteindre le voile
	local echelle = Instance.new("UIScale")
	echelle.Parent = support
	interface.voile, interface.support, interface.panneau, interface.echelle = voile, support, panneau, echelle

	-- Titre + compteur « N / 18 découverts »
	local titre = Instance.new("Frame")
	titre.Name = "Titre"
	titre.BackgroundTransparency = 1
	titre.Position = UDim2.fromOffset(mise.Marge, mise.TitreY)
	titre.Size = UDim2.fromOffset(mise.Largeur * 0.8, mise.TailleTitre + 8)
	titre.Parent = panneau
	local rangement = Instance.new("UIListLayout")
	rangement.FillDirection = Enum.FillDirection.Horizontal
	rangement.VerticalAlignment = Enum.VerticalAlignment.Bottom
	rangement.SortOrder = Enum.SortOrder.LayoutOrder
	rangement.Padding = UDim.new(0, 14)
	rangement.Parent = titre
	local texteTitre = Theme.texte({ Texte = "Carnet de collection", Taille = mise.TailleTitre, Parent = titre })
	texteTitre.AutomaticSize = Enum.AutomaticSize.X
	texteTitre.Size = UDim2.fromOffset(0, mise.TailleTitre + 4)
	texteTitre.LayoutOrder = 1
	local compteur = Theme.texte({ Texte = "", Taille = mise.TailleCompteur, Couleur = C.TexteSecondaire, Parent = titre })
	compteur.Name = "Compteur"
	compteur.AutomaticSize = Enum.AutomaticSize.X
	compteur.Size = UDim2.fromOffset(0, mise.TailleCompteur + 6)
	compteur.LayoutOrder = 2
	interface.compteur = compteur

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

	-- Barre de progression
	local barre = Instance.new("Frame")
	barre.Name = "Barre"
	barre.BackgroundColor3 = C.BordureCarte
	barre.BorderSizePixel = 0
	barre.Position = UDim2.fromOffset(mise.Marge, mise.BarreY)
	barre.Size = UDim2.fromOffset(mise.Largeur - 2 * mise.Marge, mise.BarreH)
	Theme.arrondir(barre, mise.BarreH / 2)
	barre.Parent = panneau
	local remplissage = Instance.new("Frame")
	remplissage.Name = "Remplissage"
	remplissage.BackgroundColor3 = C.Principal
	remplissage.BorderSizePixel = 0
	remplissage.Size = UDim2.fromScale(0, 1)
	Theme.arrondir(remplissage, mise.BarreH / 2)
	remplissage.Parent = barre
	interface.remplissage = remplissage

	-- En-têtes des colonnes (raretés)
	local xCase = mise.Marge + mise.Etiquette + mise.Ecart
	for colonne, infos in Reglages.Raretes do
		local entete = Theme.texte({
			Texte = infos.Nom,
			Taille = mise.TailleEntete,
			Alignement = Enum.TextXAlignment.Center,
			Parent = panneau,
			Position = UDim2.fromOffset(xCase + (colonne - 1) * (mise.CaseL + mise.Ecart), mise.EnteteY),
			TailleCadre = UDim2.fromOffset(mise.CaseL, mise.TailleEntete + 6),
		})
		entete.Name = "Entete_" .. infos.Nom
	end

	-- Une ligne par type : étiquette colorée + une case par rareté
	local cases = {} -- cases[clé] = { cadre, trait, icone, question, badge }
	for ligne, typeBonbon in Reglages.OrdreTypes do
		local y = mise.LigneY + (ligne - 1) * (mise.CaseH + mise.EcartLignes)
		local couleurType = Reglages.Types[typeBonbon].Couleur
		local etiquette = Theme.panneau(panneau, UDim2.fromOffset(mise.Etiquette, mise.CaseH - 6), couleurType, Theme.assombrir(couleurType, 0.18), 6)
		etiquette.Parent.Name = "Type_" .. typeBonbon
		etiquette.Parent.Position = UDim2.fromOffset(mise.Marge, y)
		Theme.texte({
			Texte = typeBonbon,
			Taille = mise.TailleType,
			Alignement = Enum.TextXAlignment.Center,
			TailleCadre = UDim2.fromScale(1, 1),
			Parent = etiquette,
		})

		for colonne, infos in Reglages.Raretes do
			local cle = typeBonbon .. "|" .. infos.Nom
			local cadre = Instance.new("Frame")
			cadre.Name = cle
			cadre.BorderSizePixel = 0
			cadre.Position = UDim2.fromOffset(xCase + (colonne - 1) * (mise.CaseL + mise.Ecart), y)
			cadre.Size = UDim2.fromOffset(mise.CaseL, mise.CaseH)
			Theme.arrondir(cadre, Theme.ArrondiCarte - 4)
			local trait = Theme.bordure(cadre, BORDURE_INCONNUE, 3)
			cadre.Parent = panneau

			local question = Theme.texte({
				Texte = "?",
				Taille = mise.TailleQuestion,
				Couleur = C.TexteSecondaire,
				Alignement = Enum.TextXAlignment.Center,
				TailleCadre = UDim2.fromScale(1, 1),
				Parent = cadre,
			})
			question.Name = "Question"
			question.ZIndex = 3

			local badge = Theme.texte({
				Texte = "Nouveau !",
				Taille = mise.TailleNouveau,
				Couleur = C.TexteClair,
				Alignement = Enum.TextXAlignment.Center,
				Parent = cadre,
			})
			badge.Name = "Nouveau"
			badge.BackgroundTransparency = 0
			badge.BackgroundColor3 = COULEUR_NOUVEAU
			badge.AnchorPoint = Vector2.new(1, 0.5)
			badge.Position = UDim2.new(1, 2, 0, 2)
			badge.AutomaticSize = Enum.AutomaticSize.X
			badge.Size = UDim2.fromOffset(0, mise.TailleNouveau + 8)
			badge.ZIndex = 4
			badge.Visible = false
			Theme.arrondir(badge, 12)
			local margesBadge = Instance.new("UIPadding")
			margesBadge.PaddingLeft = UDim.new(0, 8)
			margesBadge.PaddingRight = UDim.new(0, 8)
			margesBadge.Parent = badge

			cases[cle] = { cadre = cadre, trait = trait, question = question, badge = badge, type = typeBonbon, rarete = infos.Nom }
		end
	end
	interface.cases = cases

	-- (Re)fait l'icône d'une case : en couleur si découverte, silhouette sinon
	local function majCase(case, decouvert)
		case.cadre.BackgroundColor3 = if decouvert then C.FondZone else FOND_INCONNU
		case.trait.Color = if decouvert then (Theme.Raretes[case.rarete] or BORDURE_INCONNUE) else BORDURE_INCONNUE
		case.trait.Thickness = if decouvert then 3 else 2
		case.question.Visible = not decouvert
		case.badge.Visible = decouvert and nouveaux[case.cadre.Name] == true
		local ancienne = case.cadre:FindFirstChild("Icone")
		if ancienne == nil or ancienne:GetAttribute("Silhouette") ~= not decouvert then
			if ancienne then
				ancienne:Destroy()
			end
			local icone = Icones.creer(case.cadre, case.type, case.rarete, mise.Icone, UDim2.new(0.5, -mise.Icone / 2, 0.5, -mise.Icone / 2), not decouvert)
			icone.ZIndex = 2
		end
		Icones.remplir(case.cadre.Icone, ouvert)
	end

	function interface.afficher(nouvellesDonnees)
		donnees = nouvellesDonnees
		if donnees == nil then
			return
		end
		if donnees.Nouveau then
			nouveaux[donnees.Nouveau] = true
		end
		compteur.Text = donnees.Nombre .. " / " .. donnees.Total .. " découverts"
		remplissage.Size = UDim2.fromScale(if donnees.Total > 0 then donnees.Nombre / donnees.Total else 0, 1)
		for cle, case in cases do
			majCase(case, donnees.Decouverts[cle] == true)
		end
	end

	-- Y a-t-il des découvertes pas encore vues ? (pastille sur le bouton « Carnet »)
	function interface.aDesNouveautes()
		return next(nouveaux) ~= nil
	end

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
		support.Position = UDim2.new(0.5, 0, 0, margeHaut + hauteurDispo / 2)
	end

	function interface.ouvrir()
		ouvert = true
		voile.Visible = true
		support.Visible = true
		interface.adapter()
		interface.afficher(donnees)
	end

	function interface.fermer()
		ouvert = false
		voile.Visible = false
		support.Visible = false
		table.clear(nouveaux) -- vus : les badges « Nouveau ! » disparaissent
		for _, case in cases do
			local icone = case.cadre:FindFirstChild("Icone")
			if icone then
				Icones.remplir(icone, false)
			end
			case.badge.Visible = false
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

	voile.Activated:Connect(interface.fermer)
	fermer.Activated:Connect(interface.fermer)

	return interface
end

function InterfaceCarnet.demarrer()
	local joueur = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local majCarnet = remotes:WaitForChild("CarnetMaj")
	local demanderCarnet = remotes:WaitForChild("DemanderCarnet")

	local telephone = UserInputService.TouchEnabled
	local mise = if telephone then MISES_EN_PAGE.Telephone else MISES_EN_PAGE.Ordinateur

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "Carnet"
	ecran.ResetOnSpawn = false
	ecran.IgnoreGuiInset = true
	ecran.DisplayOrder = 11
	ecran.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ecran.Parent = joueur:WaitForChild("PlayerGui")

	local interface = InterfaceCarnet.creer(ecran, {
		Telephone = telephone,
		MargeHaut = function()
			return math.max(GuiService:GetGuiInset().Y, MARGE_HAUT_MIN)
		end,
	})

	-- Bouton « Carnet » juste sous le bouton « Inventaire » (côté gauche, mi-hauteur)
	local bouton, supportBouton = Theme.bouton({
		Nom = "BoutonCarnet",
		Texte = "Carnet",
		TailleTexte = mise.Bouton.TailleTexte,
		Couleur = C.Principal,
		Taille = Vector2.new(mise.Bouton.Largeur, mise.Bouton.Hauteur),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, mise.Bouton.Hauteur + 16),
		Parent = ecran,
	})
	-- Petite pastille rose quand il y a une nouveauté pas encore vue
	local pastille = Instance.new("Frame")
	pastille.Name = "PastilleNouveau"
	pastille.BackgroundColor3 = COULEUR_NOUVEAU
	pastille.Size = UDim2.fromOffset(18, 18)
	pastille.Position = UDim2.new(1, -12, 0, -6)
	pastille.Visible = false
	Theme.arrondir(pastille, 9)
	Theme.bordure(pastille, C.Panneau, 2)
	pastille.Parent = supportBouton

	local function basculer()
		interface.basculer()
		pastille.Visible = interface.aDesNouveautes() and not interface.estOuvert()
	end
	bouton.Activated:Connect(basculer)
	interface.voile.Activated:Connect(function()
		pastille.Visible = false
	end)

	-- Touche C sur ordinateur (sauf quand on écrit dans le chat)
	UserInputService.InputBegan:Connect(function(entree, dejaUtilisee)
		if not dejaUtilisee and entree.KeyCode == Enum.KeyCode.C then
			basculer()
		end
	end)

	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if interface.estOuvert() then
			interface.adapter()
		end
	end)

	majCarnet.OnClientEvent:Connect(function(donnees)
		interface.afficher(donnees)
		if donnees.Nouveau and not interface.estOuvert() then
			pastille.Visible = true
		end
	end)
	demanderCarnet:FireServer()
end

return InterfaceCarnet
