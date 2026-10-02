-- L'écran de la sorcière (d'après docs/design/Sorcière (ordinateur) et (téléphone, paysage)).
--
-- Il s'ouvre quand le joueur parle à SA sorcière (ProximityPrompt -> le serveur envoie
-- SorciereOuvrir). Le joueur remplit 3 emplacements avec des bonbons de son inventaire
-- (même rareté), puis appuie sur « Muter ». L'écran envoie seulement la liste des 3 piles
-- choisies (SorciereMuter) : le serveur vérifie tout, tire au sort et répond
-- (SorciereResultat) après la fumée.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Theme = require(script.Parent:WaitForChild("Theme"))
local Icones = require(script.Parent:WaitForChild("Icones"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Reglages = require(Shared:WaitForChild("Reglages"))

local C = Theme.Couleurs
local REGLAGES = Reglages.Sorciere
local EPAISSEUR_OMBRE_PANNEAU = 10
local MARGE_HAUT_MIN = 58
local BORDURE_CASE = Color3.fromHex("DCCFEA")

local rangs = {}
for rang, infos in Reglages.Raretes do
	rangs[infos.Nom] = rang
end

local MISES_EN_PAGE = {
	Ordinateur = {
		Largeur = 1080, Hauteur = 628, Marge = 32, MargeEcran = 20, EchelleMin = 0.87, EchelleMax = 1.6,
		TitreY = 22, TailleTitre = 40, Fermer = 52,
		Chapeau = { X = 32, Y = 104, Taille = 84 },
		Bulle = { X = 148, Y = 116, Largeur = 900, Hauteur = 60, Texte = 20 },
		Case = 110, CasesX = { 117, 247, 377 }, CasesY = 300, Fleche1X = 505, Fleche2X = 785, TailleFleche = 44,
		Chaudron = { X = 590, Y = 270, Largeur = 150, Hauteur = 150 },
		Resultat = { X = 848, Y = 293, Taille = 122 },
		Info = { Y = 516, Texte = 22, BarreY = 550, BarreL = 520, BarreH = 14, PetitY = 574, PetitTexte = 16 },
		Muter = { Largeur = 220, Hauteur = 58, Texte = 26, Y = 518 },
		Choix = { Largeur = 760, Hauteur = 440, Colonnes = 4, CarteL = 166, CarteH = 64, TailleTexte = 16 },
		Bouton = { Largeur = 160, Hauteur = 52, TailleTexte = 22 },
	},
	Telephone = {
		Largeur = 700, Hauteur = 334, Marge = 16, MargeEcran = 8, EchelleMin = 0.87, EchelleMax = 1.5,
		TitreY = 10, TailleTitre = 26, Fermer = 52,
		Chapeau = { X = 16, Y = 64, Taille = 46 },
		Bulle = { X = 70, Y = 66, Largeur = 614, Hauteur = 44, Texte = 15 },
		Case = 72, CasesX = { 86, 166, 246 }, CasesY = 134, Fleche1X = 326, Fleche2X = 486, TailleFleche = 30,
		Chaudron = { X = 372, Y = 120, Largeur = 100, Hauteur = 100 },
		Resultat = { X = 532, Y = 128, Taille = 84 },
		Info = { Y = 242, Texte = 16, BarreY = 268, BarreL = 340, BarreH = 12, PetitY = 286, PetitTexte = 15 },
		Muter = { Largeur = 170, Hauteur = 52, Texte = 20, Y = 252 },
		Choix = { Largeur = 640, Hauteur = 300, Colonnes = 3, CarteL = 190, CarteH = 64, TailleTexte = 15 },
		Bouton = { Largeur = 140, Hauteur = 52, TailleTexte = 18 },
	},
}

local InterfaceSorciere = {}

-- options : Telephone, TailleEcran (tests), MargeHaut, Muter(cles)
function InterfaceSorciere.creer(conteneur, options)
	local mise = if options.Telephone then MISES_EN_PAGE.Telephone else MISES_EN_PAGE.Ordinateur
	local interface = { mise = mise }
	local inventaire = nil -- dernier inventaire reçu (InventaireMaj)
	local pitie = {} -- échecs de suite par rareté donnée (envoyé par le serveur)
	local choisis = { nil, nil, nil } -- clés des piles choisies pour les 3 emplacements
	local ouvert, enCours = false, false

	local voile = Instance.new("TextButton")
	voile.Name = "Voile"
	voile.Text = ""
	voile.AutoButtonColor = false
	voile.BackgroundColor3 = C.Voile
	voile.BackgroundTransparency = 0.45
	voile.BorderSizePixel = 0
	voile.Size = UDim2.fromScale(1, 1)
	voile.Visible = false
	voile.Parent = conteneur

	local panneau, support = Theme.panneau(conteneur, UDim2.fromOffset(mise.Largeur, mise.Hauteur), C.Panneau, C.OmbrePanneau, EPAISSEUR_OMBRE_PANNEAU)
	support.Name = "PanneauSorciere"
	support.AnchorPoint = Vector2.new(0.5, 0.5)
	support.Visible = false
	support.ZIndex = 2
	panneau.Active = true
	local echelle = Instance.new("UIScale")
	echelle.Parent = support
	interface.voile, interface.support, interface.panneau, interface.echelle = voile, support, panneau, echelle

	local titre = Theme.texte({ Texte = "La sorcière", Taille = mise.TailleTitre, Parent = panneau, Position = UDim2.fromOffset(mise.Marge, mise.TitreY) })
	titre.Size = UDim2.fromOffset(mise.Largeur / 2, mise.TailleTitre + 8)
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

	-- Le chapeau de la sorcière + sa bulle de paroles
	local chapeau = Theme.texte({
		Texte = "🧙",
		Taille = mise.Chapeau.Taille,
		Alignement = Enum.TextXAlignment.Center,
		Parent = panneau,
		Position = UDim2.fromOffset(mise.Chapeau.X, mise.Chapeau.Y),
		TailleCadre = UDim2.fromOffset(mise.Chapeau.Taille + 8, mise.Chapeau.Taille + 8),
	})
	chapeau.Name = "Chapeau"
	local bulle = Instance.new("Frame")
	bulle.Name = "Bulle"
	bulle.BackgroundColor3 = C.FondZone
	bulle.BorderSizePixel = 0
	bulle.Position = UDim2.fromOffset(mise.Bulle.X, mise.Bulle.Y)
	bulle.Size = UDim2.fromOffset(mise.Bulle.Largeur, mise.Bulle.Hauteur)
	Theme.arrondir(bulle, mise.Bulle.Hauteur / 2)
	bulle.Parent = panneau
	local parole = Theme.texte({
		Texte = if options.Telephone then REGLAGES.Phrases.AccueilCourt else REGLAGES.Phrases.Accueil,
		Taille = mise.Bulle.Texte,
		Parent = bulle,
		Position = UDim2.fromOffset(20, 0),
		TailleCadre = UDim2.new(1, -40, 1, 0),
	})
	parole.Name = "Parole"
	parole.TextWrapped = true
	interface.parole = parole

	-- Les 3 emplacements (cliquables)
	local cases = {}
	for i = 1, 3 do
		local case = Instance.new("TextButton")
		case.Name = "Case" .. i
		case.Text = ""
		case.AutoButtonColor = false
		case.BackgroundColor3 = C.FondZone
		case.Position = UDim2.fromOffset(mise.CasesX[i], mise.CasesY)
		case.Size = UDim2.fromOffset(mise.Case, mise.Case)
		Theme.arrondir(case, math.floor(mise.Case * 0.2))
		Theme.bordure(case, BORDURE_CASE, 3)
		local plus = Theme.texte({
			Texte = "+",
			Taille = math.floor(mise.Case * 0.4),
			Couleur = BORDURE_CASE,
			Alignement = Enum.TextXAlignment.Center,
			TailleCadre = UDim2.fromScale(1, 1),
			Parent = case,
		})
		plus.Name = "Plus"
		case.Parent = panneau
		cases[i] = case
	end
	interface.cases = cases

	local function fleche(x)
		local f = Theme.texte({
			Texte = "→",
			Taille = mise.TailleFleche,
			Alignement = Enum.TextXAlignment.Center,
			Parent = panneau,
			Position = UDim2.fromOffset(x, mise.CasesY + mise.Case / 2 - mise.TailleFleche / 2 - 4),
			TailleCadre = UDim2.fromOffset(mise.TailleFleche * 1.6, mise.TailleFleche + 8),
		})
		f.Name = "Fleche"
	end
	fleche(mise.Fleche1X)
	fleche(mise.Fleche2X)

	-- Le chaudron (formes simples) avec des bulles qui montent pendant la transformation
	local ch = mise.Chaudron
	local chaudron = Instance.new("Frame")
	chaudron.Name = "Chaudron"
	chaudron.BackgroundTransparency = 1
	chaudron.Position = UDim2.fromOffset(ch.X, ch.Y)
	chaudron.Size = UDim2.fromOffset(ch.Largeur, ch.Hauteur)
	chaudron.Parent = panneau
	local function forme(nom, couleur, x, y, l, h, rayon)
		local f = Instance.new("Frame")
		f.Name = nom
		f.BackgroundColor3 = couleur
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromScale(l, h)
		Theme.arrondir(f, rayon)
		f.Parent = chaudron
		return f
	end
	forme("PiedGauche", C.Texte, 0.12, 0.78, 0.08, 0.2, 6).Rotation = 12
	forme("PiedDroit", C.Texte, 0.8, 0.78, 0.08, 0.2, 6).Rotation = -12
	forme("Cuve", Color3.fromHex("3D2466"), 0.04, 0.32, 0.92, 0.58, math.floor(ch.Largeur * 0.3))
	forme("Bord", C.Texte, 0, 0.27, 1, 0.14, math.floor(ch.Hauteur * 0.07))
	forme("Potion", Color3.fromHex("8BE36A"), 0.06, 0.29, 0.88, 0.09, math.floor(ch.Hauteur * 0.05))
	local bulles = {}
	for i = 1, 3 do
		local b = forme("Bulle" .. i, Color3.fromHex("C7F5B5"), 0.3 + (i - 1) * 0.18, 0.18, 0.08, 0.08, math.floor(ch.Largeur * 0.04))
		b.BackgroundTransparency = 0.2
		bulles[i] = b
	end

	-- La case du résultat
	local r = mise.Resultat
	local caseResultat = Instance.new("Frame")
	caseResultat.Name = "Resultat"
	caseResultat.BackgroundColor3 = C.FondZone
	caseResultat.Position = UDim2.fromOffset(r.X, r.Y)
	caseResultat.Size = UDim2.fromOffset(r.Taille, r.Taille)
	Theme.arrondir(caseResultat, math.floor(r.Taille * 0.22))
	local traitResultat = Theme.bordure(caseResultat, Color3.fromHex("E3D5F7"), 8)
	caseResultat.Parent = panneau
	local interrogation = Theme.texte({
		Texte = "?",
		Taille = math.floor(r.Taille * 0.36),
		Couleur = C.Principal,
		Alignement = Enum.TextXAlignment.Center,
		TailleCadre = UDim2.fromScale(1, 1),
		Parent = caseResultat,
	})
	interrogation.Name = "Interrogation"
	interface.caseResultat = caseResultat

	-- Les informations du bas : palier, taux, barre, pitié
	local inf = mise.Info
	local lignePalier = Instance.new("Frame")
	lignePalier.Name = "Palier"
	lignePalier.BackgroundTransparency = 1
	lignePalier.Position = UDim2.fromOffset(mise.Marge, inf.Y)
	lignePalier.Size = UDim2.fromOffset(inf.BarreL + 120, inf.Texte + 8)
	lignePalier.Parent = panneau
	local rangement = Instance.new("UIListLayout")
	rangement.FillDirection = Enum.FillDirection.Horizontal
	rangement.VerticalAlignment = Enum.VerticalAlignment.Center
	rangement.Padding = UDim.new(0, 8)
	rangement.SortOrder = Enum.SortOrder.LayoutOrder
	rangement.Parent = lignePalier
	local pastille = Theme.pastille(lignePalier, "Commun", math.floor(inf.Texte * 0.75))
	local textePalier = Theme.texte({ Texte = "", Taille = inf.Texte, Parent = lignePalier })
	textePalier.AutomaticSize = Enum.AutomaticSize.X
	textePalier.Size = UDim2.fromOffset(0, inf.Texte + 4)
	textePalier.LayoutOrder = 2
	interface.textePalier = textePalier

	local barre = Instance.new("Frame")
	barre.Name = "Barre"
	barre.BackgroundColor3 = C.BordureCarte
	barre.BorderSizePixel = 0
	barre.Position = UDim2.fromOffset(mise.Marge, inf.BarreY)
	barre.Size = UDim2.fromOffset(inf.BarreL, inf.BarreH)
	Theme.arrondir(barre, inf.BarreH / 2)
	barre.Parent = panneau
	local remplissage = Instance.new("Frame")
	remplissage.Name = "Remplissage"
	remplissage.BorderSizePixel = 0
	remplissage.Size = UDim2.fromScale(0, 1)
	Theme.arrondir(remplissage, inf.BarreH / 2)
	remplissage.Parent = barre
	local textePitie = Theme.texte({
		Texte = "",
		Taille = inf.PetitTexte,
		Couleur = C.TexteSecondaire,
		Parent = panneau,
		Position = UDim2.fromOffset(mise.Marge, inf.PetitY),
		TailleCadre = UDim2.fromOffset(mise.Largeur - 2 * mise.Marge - mise.Muter.Largeur - 16, inf.PetitTexte + 4),
	})
	textePitie.Name = "Pitie"
	interface.textePitie = textePitie

	local boutonMuter = Theme.bouton({
		Nom = "Muter",
		Texte = "Muter",
		TailleTexte = mise.Muter.Texte,
		Couleur = C.Principal,
		Taille = Vector2.new(mise.Muter.Largeur, mise.Muter.Hauteur),
		Position = UDim2.fromOffset(mise.Largeur - mise.Marge - mise.Muter.Largeur, mise.Muter.Y),
		Parent = panneau,
	})
	interface.boutonMuter = boutonMuter

	-- Fenêtre de choix des bonbons (par-dessus le panneau)
	local cx = mise.Choix
	local voileChoix = Instance.new("TextButton")
	voileChoix.Name = "Choix"
	voileChoix.Text = ""
	voileChoix.AutoButtonColor = false
	voileChoix.BackgroundColor3 = C.Voile
	voileChoix.BackgroundTransparency = 0.5
	voileChoix.Size = UDim2.fromScale(1, 1)
	voileChoix.Visible = false
	voileChoix.ZIndex = 20
	Theme.arrondir(voileChoix)
	voileChoix.Parent = panneau
	local boite = Theme.panneau(voileChoix, UDim2.fromOffset(cx.Largeur, cx.Hauteur), C.Panneau, C.OmbrePanneau, 8)
	boite.Active = true
	boite.Parent.AnchorPoint = Vector2.new(0.5, 0.5)
	boite.Parent.Position = UDim2.fromScale(0.5, 0.5)
	local titreChoix = Theme.texte({
		Texte = "Choisis un bonbon",
		Taille = cx.TailleTexte + 6,
		Parent = boite,
		Position = UDim2.fromOffset(20, 14),
		TailleCadre = UDim2.fromOffset(cx.Largeur - 110, cx.TailleTexte + 12),
	})
	titreChoix.Name = "TitreChoix"
	local fermerChoix = Theme.bouton({
		Nom = "FermerChoix",
		Texte = "×",
		TailleTexte = 34,
		Couleur = C.Fermer,
		Taille = Vector2.new(52, 52),
		EpaisseurOmbre = 4,
		Position = UDim2.fromOffset(cx.Largeur - 70, 8),
		Parent = boite,
	})
	local liste = Instance.new("ScrollingFrame")
	liste.Name = "Liste"
	liste.BackgroundTransparency = 1
	liste.BorderSizePixel = 0
	liste.Position = UDim2.fromOffset(16, 70)
	liste.Size = UDim2.fromOffset(cx.Largeur - 32, cx.Hauteur - 86)
	liste.AutomaticCanvasSize = Enum.AutomaticSize.Y
	liste.CanvasSize = UDim2.new()
	liste.ScrollBarThickness = 6
	liste.ScrollBarImageColor3 = C.OmbrePanneau
	liste.Parent = boite
	local margesListe = Instance.new("UIPadding")
	margesListe.PaddingTop = UDim.new(0, 4)
	margesListe.PaddingLeft = UDim.new(0, 4)
	margesListe.Parent = liste
	local grilleListe = Instance.new("UIGridLayout")
	grilleListe.CellSize = UDim2.fromOffset(cx.CarteL, cx.CarteH)
	grilleListe.CellPadding = UDim2.fromOffset(10, 10)
	grilleListe.SortOrder = Enum.SortOrder.LayoutOrder
	grilleListe.Parent = liste
	local videChoix = Theme.texte({
		Texte = "Aucun bonbon ne convient.\nIl en faut 3 de la même rareté (pas Mythique, pas raté).",
		Taille = cx.TailleTexte,
		Couleur = C.TexteSecondaire,
		Alignement = Enum.TextXAlignment.Center,
		Parent = boite,
		Position = UDim2.fromOffset(16, 70),
		TailleCadre = UDim2.fromOffset(cx.Largeur - 32, cx.Hauteur - 90),
	})
	videChoix.Name = "VideChoix"
	videChoix.TextWrapped = true
	interface.voileChoix, interface.listeChoix = voileChoix, liste

	----------------------------------------------------------------------------
	-- Mise à jour de l'affichage
	----------------------------------------------------------------------------

	local function lireCle(cle)
		local morceaux = string.split(cle, "|")
		return morceaux[1], morceaux[2]
	end

	-- Combien de bonbons d'une pile sont déjà posés dans les emplacements
	local function dejaChoisis(cle)
		local n = 0
		for i = 1, 3 do
			if choisis[i] == cle then
				n += 1
			end
		end
		return n
	end

	local function rareteChoisie()
		for i = 1, 3 do
			if choisis[i] then
				local _, nomRarete = lireCle(choisis[i])
				return nomRarete
			end
		end
		return nil
	end

	local function quantitePossedee(cle)
		if inventaire == nil then
			return 0
		end
		for _, pile in inventaire.Piles do
			if pile.Cle == cle then
				return pile.Quantite
			end
		end
		return 0
	end

	local function majInfos()
		local nomRarete = rareteChoisie()
		local rang = nomRarete and rangs[nomRarete]
		local cible = rang and Reglages.Raretes[rang + 1]
		if cible == nil then
			pastille.BackgroundColor3 = Theme.Raretes["Commun"]
			textePalier.Text = "Choisis 3 bonbons de même rareté"
			remplissage.Size = UDim2.fromScale(0, 1)
			textePitie.Text = "Échec : tu reçois un bonbon raté"
		else
			local taux = REGLAGES.Taux[cible.Nom] or 0
			local echecs = pitie[nomRarete] or 0
			local garanti = echecs >= REGLAGES.EchecsAvantGarantie
			pastille.BackgroundColor3 = Theme.Raretes[cible.Nom]
			remplissage.BackgroundColor3 = Theme.Raretes[cible.Nom]
			textePalier.Text = nomRarete .. " vers " .. cible.Nom .. " · " .. (if garanti then "100" else tostring(taux)) .. (if options.Telephone then " %" else " % de réussite")
			remplissage.Size = UDim2.fromScale(if garanti then 1 else taux / 100, 1)
			local essais = REGLAGES.EchecsAvantGarantie - echecs + 1
			if garanti then
				textePitie.Text = "Réussite garantie cette fois !"
			elseif options.Telephone then
				textePitie.Text = "Échec : bonbon raté · garanti dans " .. essais .. " essais"
			else
				textePitie.Text = "Échec : tu reçois un bonbon raté · Chance garantie dans " .. essais .. " essais"
			end
		end
		local complet = choisis[1] and choisis[2] and choisis[3]
		boutonMuter.BackgroundTransparency = if complet and not enCours then 0 else 0.45
	end

	local function majCases()
		for i, case in cases do
			local ancienne = case:FindFirstChild("Icone")
			if ancienne then
				ancienne:Destroy()
			end
			case.Plus.Visible = choisis[i] == nil
			if choisis[i] then
				local typeBonbon, nomRarete = lireCle(choisis[i])
				local taille = math.floor(mise.Case * 0.8)
				Icones.creer(case, typeBonbon, nomRarete, taille, UDim2.fromOffset((mise.Case - taille) / 2, (mise.Case - taille) / 2))
				Icones.remplir(case.Icone, ouvert)
			end
		end
		majInfos()
	end

	local function viderResultat()
		local ancienne = caseResultat:FindFirstChild("Icone")
		if ancienne then
			ancienne:Destroy()
		end
		interrogation.Visible = true
		interrogation.Text = "?"
		traitResultat.Color = Color3.fromHex("E3D5F7")
	end

	-- Liste des piles qu'on peut encore poser (même rareté que celles déjà posées)
	local function remplirChoix()
		for _, enfant in liste:GetChildren() do
			if enfant:IsA("GuiButton") then
				enfant:Destroy()
			end
		end
		local rareteImposee = rareteChoisie()
		local possibles = {}
		for _, pile in (inventaire and inventaire.Piles or {}) do
			local reste = pile.Quantite - dejaChoisis(pile.Cle)
			local rang = rangs[pile.Rarete]
			if reste > 0 and rang and Reglages.Raretes[rang + 1] and Reglages.Types[pile.Type]
				and (rareteImposee == nil or pile.Rarete == rareteImposee) then
				table.insert(possibles, { pile = pile, reste = reste })
			end
		end
		table.sort(possibles, function(a, b)
			if a.pile.Rarete ~= b.pile.Rarete then
				return rangs[a.pile.Rarete] > rangs[b.pile.Rarete]
			end
			return a.pile.Cle < b.pile.Cle
		end)
		for ordre, possible in possibles do
			local pile = possible.pile
			local carte = Instance.new("TextButton")
			carte.Name = pile.Cle
			carte.Text = ""
			carte.AutoButtonColor = false
			carte.BackgroundColor3 = C.Panneau
			carte.LayoutOrder = ordre
			Theme.arrondir(carte, 18)
			Theme.bordure(carte, Theme.Raretes[pile.Rarete] or C.BordureCarte, 3)
			Icones.creer(carte, pile.Type, pile.Rarete, 48, UDim2.fromOffset(6, (cx.CarteH - 48) / 2))
			Icones.remplir(carte.Icone, true)
			Theme.texte({ Texte = pile.Type .. " ×" .. possible.reste, Taille = cx.TailleTexte, Parent = carte, Position = UDim2.fromOffset(60, 8), TailleCadre = UDim2.fromOffset(cx.CarteL - 64, cx.TailleTexte + 4) })
			local r2 = Theme.texte({ Texte = pile.Rarete, Taille = cx.TailleTexte, Couleur = C.TexteSecondaire, Parent = carte, Position = UDim2.fromOffset(60, 32), TailleCadre = UDim2.fromOffset(cx.CarteL - 64, cx.TailleTexte + 4) })
			r2.Name = "Rarete"
			carte.Activated:Connect(function()
				for i = 1, 3 do
					if choisis[i] == nil then
						choisis[i] = pile.Cle
						break
					end
				end
				majCases()
				if choisis[1] and choisis[2] and choisis[3] then
					voileChoix.Visible = false
				else
					remplirChoix()
				end
			end)
			carte.Parent = liste
		end
		videChoix.Visible = #possibles == 0
	end

	function interface.afficherInventaire(donnees)
		inventaire = donnees
		-- Un bonbon choisi qui n'est plus dans l'inventaire est retiré de son emplacement
		for i = 1, 3 do
			if choisis[i] and dejaChoisis(choisis[i]) > quantitePossedee(choisis[i]) then
				choisis[i] = nil
			end
		end
		if ouvert and not enCours then
			majCases()
			if voileChoix.Visible then
				remplirChoix()
			end
		end
	end

	function interface.afficherPitie(nouvellePitie)
		if typeof(nouvellePitie) == "table" then
			pitie = nouvellePitie
		end
		majInfos()
	end

	-- Le serveur a répondu
	function interface.afficherResultat(donnees)
		enCours = false
		interface.afficherPitie(donnees.Pitie)
		if not donnees.Accepte then
			parole.Text = tostring(donnees.Message)
			viderResultat()
			majCases()
			return
		end
		parole.Text = donnees.Phrase
		interrogation.Visible = false
		local taille = math.floor(r.Taille * 0.8)
		Icones.creer(caseResultat, donnees.Type, donnees.Rarete, taille, UDim2.fromOffset((r.Taille - taille) / 2, (r.Taille - taille) / 2))
		Icones.remplir(caseResultat.Icone, ouvert)
		traitResultat.Color = if donnees.Reussi then (Theme.Raretes[donnees.Rarete] or C.Principal) else Color3.fromHex("9C8F86")
		majCases()
	end

	-- Bulles qui montent pendant la mise en scène
	local function animerChaudron()
		for i, b in bulles do
			task.spawn(function()
				task.wait((i - 1) * 0.25)
				while enCours do
					b.Position = UDim2.fromScale(0.3 + (i - 1) * 0.18, 0.25)
					b.BackgroundTransparency = 0.2
					local montee = TweenService:Create(b, TweenInfo.new(0.8), { Position = UDim2.fromScale(0.3 + (i - 1) * 0.18, -0.1), BackgroundTransparency = 1 })
					montee:Play()
					montee.Completed:Wait()
				end
				b.Position = UDim2.fromScale(0.3 + (i - 1) * 0.18, 0.18)
				b.BackgroundTransparency = 0.2
			end)
		end
	end

	----------------------------------------------------------------------------
	-- Ouverture, fermeture, taille
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
		support.Position = UDim2.new(0.5, 0, 0, margeHaut + hauteurDispo / 2)
	end

	function interface.ouvrir()
		ouvert = true
		voile.Visible = true
		support.Visible = true
		voileChoix.Visible = false
		if not enCours then
			parole.Text = if options.Telephone then REGLAGES.Phrases.AccueilCourt else REGLAGES.Phrases.Accueil
			viderResultat()
		end
		interface.adapter()
		majCases()
	end

	function interface.fermer()
		ouvert = false
		voile.Visible = false
		support.Visible = false
		voileChoix.Visible = false
	end

	function interface.estOuvert()
		return ouvert
	end

	-- Ouvre la fenêtre de choix des bonbons (comme un clic sur un emplacement vide)
	function interface.ouvrirChoix()
		remplirChoix()
		voileChoix.Visible = true
	end

	voile.Activated:Connect(interface.fermer)
	fermer.Activated:Connect(interface.fermer)
	fermerChoix.Activated:Connect(function()
		voileChoix.Visible = false
	end)
	voileChoix.Activated:Connect(function()
		voileChoix.Visible = false
	end)

	for i, case in cases do
		case.Activated:Connect(function()
			if enCours then
				return
			end
			if choisis[i] then
				choisis[i] = nil -- un clic sur un emplacement rempli le vide
				majCases()
			else
				viderResultat()
				remplirChoix()
				voileChoix.Visible = true
			end
		end)
	end

	boutonMuter.Activated:Connect(function()
		if enCours or not (choisis[1] and choisis[2] and choisis[3]) then
			return
		end
		enCours = true
		local cles = { choisis[1], choisis[2], choisis[3] }
		choisis = { nil, nil, nil }
		parole.Text = "Bouillonne, chaudron, bouillonne…"
		interrogation.Text = "…"
		majCases()
		animerChaudron()
		options.Muter(cles)
	end)

	return interface
end

function InterfaceSorciere.demarrer()
	local joueur = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local ouvrirSorciere = remotes:WaitForChild("SorciereOuvrir")
	local muter = remotes:WaitForChild("SorciereMuter")
	local resultat = remotes:WaitForChild("SorciereResultat")
	local majInventaire = remotes:WaitForChild("InventaireMaj")
	local demanderInventaire = remotes:WaitForChild("DemanderInventaire")

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "Sorciere"
	ecran.ResetOnSpawn = false
	ecran.IgnoreGuiInset = true
	ecran.DisplayOrder = 12
	ecran.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ecran.Parent = joueur:WaitForChild("PlayerGui")

	local interface = InterfaceSorciere.creer(ecran, {
		Telephone = UserInputService.TouchEnabled,
		MargeHaut = function()
			return math.max(GuiService:GetGuiInset().Y, MARGE_HAUT_MIN)
		end,
		Muter = function(cles)
			muter:FireServer(cles)
		end,
	})

	majInventaire.OnClientEvent:Connect(interface.afficherInventaire)
	resultat.OnClientEvent:Connect(interface.afficherResultat)
	ouvrirSorciere.OnClientEvent:Connect(function(donnees)
		interface.afficherPitie(donnees and donnees.Pitie)
		interface.ouvrir()
		demanderInventaire:FireServer()
	end)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if interface.estOuvert() then
			interface.adapter()
		end
	end)
end

return InterfaceSorciere
