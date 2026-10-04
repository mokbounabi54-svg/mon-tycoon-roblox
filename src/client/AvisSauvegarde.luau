-- Prévient le joueur, calmement et honnêtement, quand sa partie ne sera PAS enregistrée.
--
-- C'est le serveur qui décide (attribut "PartieNonSauvegardee" du joueur, posé par
-- Parcelles) :
--   "Chargement" : sa sauvegarde n'a pas pu être lue (souci chez Roblox) ;
--   "Probleme"   : une partie du démarrage a planté (l'usine marche quand même).
-- Dans les deux cas, sa sauvegarde n'est pas touchée : le serveur n'écrit rien.
--
-- Un panneau s'affiche avec un bouton « J'ai compris », puis un petit rappel reste
-- discrètement en haut à droite. Textes d'au moins 13 px, même sur téléphone.

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent:WaitForChild("Theme"))

local C = Theme.Couleurs

local TEXTES = {
	Chargement = {
		Titre = "Ta sauvegarde n'a pas pu être lue",
		Texte = "Pas d'inquiétude, elle est à l'abri : on n'y touche pas. Tu peux jouer, mais ce que tu fais "
			.. "pendant cette partie ne sera pas enregistré. Pour retrouver ta progression, reconnecte-toi dans un petit moment.",
	},
	Probleme = {
		Titre = "Un petit souci au démarrage",
		Texte = "Ton usine fonctionne, et ta sauvegarde est à l'abri : on n'y touche pas. Mais ce que tu fais "
			.. "pendant cette partie ne sera pas enregistré. Pour que tout soit à nouveau enregistré, reconnecte-toi.",
	},
}
local TEXTE_RAPPEL = "Cette partie n'est pas enregistrée"

return function()
	local joueur = Players.LocalPlayer
	local telephone = UserInputService.TouchEnabled
	local tailleTitre = if telephone then 20 else 26
	local tailleTexte = if telephone then 16 else 19 -- jamais sous 13 px
	local tailleRappel = if telephone then 14 else 16

	local ecran = Instance.new("ScreenGui")
	ecran.Name = "AvisSauvegarde"
	ecran.ResetOnSpawn = false
	ecran.DisplayOrder = 30 -- au-dessus des autres panneaux
	ecran.Parent = joueur:WaitForChild("PlayerGui")

	-- Le petit rappel discret, après la fermeture du panneau
	local function afficherRappel()
		local rappel = Instance.new("TextLabel")
		rappel.Name = "Rappel"
		rappel.AnchorPoint = Vector2.new(1, 0)
		rappel.Position = UDim2.new(1, -16, 0, 64) -- sous la barre de Roblox
		rappel.AutomaticSize = Enum.AutomaticSize.XY
		rappel.Size = UDim2.new()
		rappel.BackgroundColor3 = C.Panneau
		rappel.BackgroundTransparency = 0.1
		rappel.Font = Theme.Police
		rappel.TextSize = tailleRappel
		rappel.TextColor3 = C.TexteSecondaire
		rappel.Text = TEXTE_RAPPEL
		Theme.arrondir(rappel, 14)
		local marge = Instance.new("UIPadding")
		marge.PaddingLeft = UDim.new(0, 12)
		marge.PaddingRight = UDim.new(0, 12)
		marge.PaddingTop = UDim.new(0, 6)
		marge.PaddingBottom = UDim.new(0, 6)
		marge.Parent = rappel
		rappel.Parent = ecran
	end

	local function afficher(raison)
		local textes = TEXTES[raison] or TEXTES.Probleme
		local tailleEcran = workspace.CurrentCamera.ViewportSize
		local largeur = math.min(560, tailleEcran.X - 32)
		local margeInterieure = 24

		-- Hauteur du texte une fois coupé en lignes, pour que le panneau soit à la bonne taille
		local hauteurTexte = TextService:GetTextSize(textes.Texte, tailleTexte, Theme.Police, Vector2.new(largeur - 2 * margeInterieure, 2000)).Y
		local hauteur = margeInterieure + (tailleTitre + 6) + 10 + hauteurTexte + 18 + 58 + margeInterieure

		local panneau, support = Theme.panneau(ecran, UDim2.fromOffset(largeur, hauteur), nil, nil, 8)
		support.AnchorPoint = Vector2.new(0.5, 0.5)
		support.Position = UDim2.fromScale(0.5, 0.5)

		Theme.texte({
			Parent = panneau,
			Texte = textes.Titre,
			Taille = tailleTitre,
			Alignement = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(margeInterieure, margeInterieure),
			TailleCadre = UDim2.new(1, -2 * margeInterieure, 0, tailleTitre + 6),
		}).TextWrapped = true

		local texte = Theme.texte({
			Parent = panneau,
			Texte = textes.Texte,
			Taille = tailleTexte,
			Couleur = C.TexteSecondaire,
			Alignement = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(margeInterieure, margeInterieure + tailleTitre + 16),
			TailleCadre = UDim2.new(1, -2 * margeInterieure, 0, hauteurTexte),
		})
		texte.TextWrapped = true

		local bouton = Theme.bouton({
			Parent = panneau,
			Nom = "Compris",
			Texte = "J'ai compris",
			TailleTexte = if telephone then 18 else 22,
			Taille = Vector2.new(200, 52), -- zone cliquable ≥ 44 px
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -margeInterieure + 6),
		})
		bouton.Activated:Connect(function()
			support:Destroy()
			afficherRappel()
		end)
	end

	-- L'attribut peut déjà être là, ou arriver un peu plus tard (chargement en cours)
	local raison = joueur:GetAttribute("PartieNonSauvegardee")
	if raison then
		afficher(raison)
	else
		joueur:GetAttributeChangedSignal("PartieNonSauvegardee"):Once(function()
			afficher(joueur:GetAttribute("PartieNonSauvegardee"))
		end)
	end
end
