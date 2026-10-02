-- Le style de TOUTES les interfaces du jeu : police, couleurs, arrondis, et
-- quelques « briques » toutes prêtes (bouton à ombre épaisse, carte, pastille).
-- Changer une couleur ou la police ici la change partout (inventaire, et plus
-- tard carnet, sorcière, boutique).

local Theme = {}

Theme.Police = Enum.Font.FredokaOne

Theme.Couleurs = {
	Texte = Color3.fromHex("2A1B3D"),
	TexteSecondaire = Color3.fromHex("5B4778"),
	TexteClair = Color3.fromHex("FFFFFF"),
	Panneau = Color3.fromHex("FFFFFF"),
	FondZone = Color3.fromHex("F6EEFF"),
	OmbrePanneau = Color3.fromHex("CDB8EA"),
	BordureCarte = Color3.fromHex("ECE2F8"),
	Voile = Color3.fromHex("2A1B3D"), -- fond assombri derrière un panneau
	Principal = Color3.fromHex("7A4DD8"), -- violet : bouton principal, sélection
	Vendre = Color3.fromHex("178A4B"),
	ToutVendre = Color3.fromHex("FF8A1F"),
	TexteToutVendre = Color3.fromHex("2A1B3D"),
	Fermer = Color3.fromHex("FF5C7A"),
	Badge = Color3.fromHex("2A1B3D"),
}

-- Couleur de chaque rareté dans les interfaces (pastilles, bordures)
Theme.Raretes = {
	["Commun"] = Color3.fromHex("CFC3DD"),
	["Peu commun"] = Color3.fromHex("58D45A"),
	["Rare"] = Color3.fromHex("3F8CFF"),
	["Épique"] = Color3.fromHex("A855F7"),
	["Légendaire"] = Color3.fromHex("FFA21A"),
	["Mythique"] = Color3.fromHex("FF3EA5"),
}

Theme.Arrondi = 30 -- coins des panneaux (px)
Theme.ArrondiCarte = 24
Theme.EpaisseurOmbre = 6 -- l'« ombre » épaisse sous les boutons (px)

-- Sons courts et discrets (fournis avec Roblox, à remplacer par de vrais sons plus tard)
Theme.Sons = {
	Vente = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Vitesse = 1.5 },
	-- Joués avec les messages en haut de l'écran (le serveur dit lequel)
	Legendaire = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.22, Vitesse = 1.25 },
	Mythique = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Vitesse = 0.85 },
	Nouveau = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.15, Vitesse = 1.7 },
}

-- Une couleur un peu plus sombre (pour l'ombre d'un bouton)
function Theme.assombrir(couleur, quantite)
	return couleur:Lerp(Color3.new(0, 0, 0), quantite or 0.22)
end

function Theme.arrondir(objet, rayon)
	local coin = Instance.new("UICorner")
	coin.CornerRadius = UDim.new(0, rayon or Theme.Arrondi)
	coin.Parent = objet
	return coin
end

function Theme.bordure(objet, couleur, epaisseur)
	local trait = Instance.new("UIStroke")
	trait.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	trait.Color = couleur
	trait.Thickness = epaisseur or 3
	trait.Parent = objet
	return trait
end

-- Un texte avec la police et la couleur du thème.
-- options : Texte, Taille (px), Couleur, Parent, Position, TailleCadre (UDim2), Alignement
function Theme.texte(options)
	local etiquette = Instance.new("TextLabel")
	etiquette.BackgroundTransparency = 1
	etiquette.Font = Theme.Police
	etiquette.Text = options.Texte or ""
	etiquette.TextSize = options.Taille or 18
	etiquette.TextColor3 = options.Couleur or Theme.Couleurs.Texte
	etiquette.TextXAlignment = options.Alignement or Enum.TextXAlignment.Left
	etiquette.Size = options.TailleCadre or UDim2.new(1, 0, 0, etiquette.TextSize + 4)
	etiquette.Position = options.Position or UDim2.new()
	etiquette.Name = options.Nom or "Texte"
	etiquette.Parent = options.Parent
	return etiquette
end

-- Un panneau blanc arrondi avec une « ombre » colorée en dessous.
-- Renvoie le panneau (on y range le contenu) ; l'ombre est un frère placé derrière.
function Theme.panneau(parent, taille, couleur, couleurOmbre, epaisseurOmbre)
	local support = Instance.new("Frame")
	support.Name = "Support"
	support.BackgroundTransparency = 1
	support.Size = taille
	support.Parent = parent

	local ombre = Instance.new("Frame")
	ombre.Name = "Ombre"
	ombre.BackgroundColor3 = couleurOmbre or Theme.Couleurs.OmbrePanneau
	ombre.BorderSizePixel = 0
	ombre.Size = UDim2.fromScale(1, 1)
	ombre.Position = UDim2.fromOffset(0, epaisseurOmbre or 10)
	Theme.arrondir(ombre)
	ombre.Parent = support

	local panneau = Instance.new("Frame")
	panneau.Name = "Panneau"
	panneau.BackgroundColor3 = couleur or Theme.Couleurs.Panneau
	panneau.BorderSizePixel = 0
	panneau.Size = UDim2.fromScale(1, 1)
	Theme.arrondir(panneau)
	panneau.Parent = support

	return panneau, support
end

-- Un bouton arrondi avec une ombre épaisse en dessous, qui s'enfonce quand on appuie.
-- options : Texte, TailleTexte, Couleur, CouleurTexte, Taille (Vector2, sans l'ombre),
--           Position (UDim2), AnchorPoint, Parent, Arrondi, Nom
-- Renvoie le bouton cliquable (TextButton) et son support (à déplacer / cacher).
function Theme.bouton(options)
	local couleur = options.Couleur or Theme.Couleurs.Principal
	local taille = options.Taille or Vector2.new(200, 52)
	local epaisseur = options.EpaisseurOmbre or Theme.EpaisseurOmbre
	local arrondi = options.Arrondi or math.floor(taille.Y / 2)

	local support = Instance.new("Frame")
	support.Name = options.Nom or "Bouton"
	support.BackgroundTransparency = 1
	support.Size = UDim2.fromOffset(taille.X, taille.Y + epaisseur)
	support.Position = options.Position or UDim2.new()
	support.AnchorPoint = options.AnchorPoint or Vector2.zero
	support.Parent = options.Parent

	local ombre = Instance.new("Frame")
	ombre.Name = "Ombre"
	ombre.BackgroundColor3 = options.CouleurOmbre or Theme.assombrir(couleur)
	ombre.BorderSizePixel = 0
	ombre.Size = UDim2.fromOffset(taille.X, taille.Y)
	ombre.Position = UDim2.fromOffset(0, epaisseur)
	Theme.arrondir(ombre, arrondi)
	ombre.Parent = support

	local bouton = Instance.new("TextButton")
	bouton.Name = "Clic"
	bouton.AutoButtonColor = false
	bouton.BackgroundColor3 = couleur
	bouton.BorderSizePixel = 0
	bouton.Size = UDim2.fromOffset(taille.X, taille.Y)
	bouton.Font = Theme.Police
	bouton.Text = options.Texte or ""
	bouton.TextSize = options.TailleTexte or 22
	bouton.TextColor3 = options.CouleurTexte or Theme.Couleurs.TexteClair
	Theme.arrondir(bouton, arrondi)
	bouton.Parent = support

	-- Le bouton descend sur son ombre quand on appuie, puis remonte
	bouton.MouseButton1Down:Connect(function()
		bouton.Position = UDim2.fromOffset(0, epaisseur / 2)
	end)
	local function remonter()
		bouton.Position = UDim2.new()
	end
	bouton.MouseButton1Up:Connect(remonter)
	bouton.MouseLeave:Connect(remonter)

	return bouton, support
end

-- Une petite pastille ronde de la couleur d'une rareté
function Theme.pastille(parent, nomRarete, diametre)
	local rond = Instance.new("Frame")
	rond.Name = "Pastille"
	rond.BackgroundColor3 = Theme.Raretes[nomRarete] or Theme.Raretes["Commun"]
	rond.BorderSizePixel = 0
	rond.Size = UDim2.fromOffset(diametre, diametre)
	Theme.arrondir(rond, math.ceil(diametre / 2))
	rond.Parent = parent
	return rond
end

return Theme
