-- CONSTRUIRE L'ÎLE DU VERGER (mode hybride) — à lancer dans Studio, en mode ÉDITION.
--
-- Comment : Affichage → Barre de commande, coller TOUT ce fichier, Entrée (ou par la
-- connexion Studio). Le script peut être relancé autant de fois qu'on veut :
--   1. il range l'ancienne version (Workspace/Monde, ServerStorage/ModelesRecolte) dans
--      ServerStorage/Decor_Anciens, avec la date dans le nom (rien n'est supprimé) ;
--   2. il range aussi dans Decor_Anciens, s'ils sont encore là : le mur invisible MurEst et
--      les 3 falaises de l'est en (277, 0) et (277/280, ±55,7) ;
--   3. il reconstruit tout : modèles de récolte, sentier, pont, île, mer, murs.
-- Plan complet : docs/design_hybride.md (section b) et docs/decor-carte.md.
--
-- Tout est ancré. Décor : CanCollide, CanQuery et CanTouch à false, sans ombre.
-- Seuls les SOLS (pont, île, fond de la mer, pentes) et les MURS ont des collisions.

local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

pcall(function()
	ChangeHistoryService:SetWaypoint("Avant construction du verger")
end)

local anciens = ServerStorage:FindFirstChild("Decor_Anciens")
if anciens == nil then
	anciens = Instance.new("Folder")
	anciens.Name = "Decor_Anciens"
	anciens.Parent = ServerStorage
end
local horodatage = os.date("%Y%m%d_%H%M%S")
local journal = {}
local function noter(texte)
	table.insert(journal, texte)
end

-- Couleurs (palette « Palette et ambiance » + bonbon Fraise)
local C = {
	Herbe = Color3.fromHex("8FE04F"),
	Feuille = Color3.fromHex("6CCB4A"),
	Caramel = Color3.fromHex("E5B084"),
	CaramelFonce = Color3.fromHex("C98F5E"),
	Sable = Color3.fromHex("F2D3A0"),
	SableMouille = Color3.fromHex("E2BE85"),
	Eau = Color3.fromHex("7FD3EE"),
	Rose = Color3.fromHex("FF8FB8"),
	Blanc = Color3.fromHex("FFFFFF"),
	Fraise = Color3.fromHex("F0476B"),
	Tronc = Color3.fromHex("8A5A3C"),
}

-- Une pièce de décor (sans collision) ou de sol (avec collision)
local function piece(options)
	local p = Instance.new(options.Classe or "Part")
	p.Name = options.Nom
	p.Anchored = true
	p.Material = options.Matiere or Enum.Material.SmoothPlastic
	p.Color = options.Couleur or C.Blanc
	p.Size = options.Taille
	p.CFrame = options.CFrame
	p.Transparency = options.Transparence or 0
	p.CastShadow = false
	if options.Forme then
		p.Shape = options.Forme
	end
	if options.Sol then
		p.CanCollide = true -- on marche dessus
	elseif options.Mur then
		p.CanCollide = true
		p.CanQuery = false
		p.CanTouch = false
	else
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
	end
	p.Parent = options.Parent
	return p
end

local function dossier(nom, parent, classe)
	local d = Instance.new(classe or "Folder")
	d.Name = nom
	d.Parent = parent
	return d
end

--------------------------------------------------------------------------------
-- 1. Ranger l'ancienne version et ce que le verger remplace
--------------------------------------------------------------------------------
local ancienMonde = workspace:FindFirstChild("Monde")
if ancienMonde then
	ancienMonde.Name = "Monde_" .. horodatage
	ancienMonde.Parent = anciens
	noter("ancien Workspace/Monde rangé dans Decor_Anciens/" .. ancienMonde.Name)
end
local anciensModeles = ServerStorage:FindFirstChild("ModelesRecolte")
if anciensModeles then
	anciensModeles.Name = "ModelesRecolte_" .. horodatage
	anciensModeles.Parent = anciens
	noter("ancien ServerStorage/ModelesRecolte rangé dans Decor_Anciens/" .. anciensModeles.Name)
end

local bordure = workspace:FindFirstChild("Decor") and workspace.Decor:FindFirstChild("1_SolEtBordure")
local murs = bordure and bordure:FindFirstChild("Murs")
local murEst = murs and murs:FindFirstChild("MurEst")
if murEst then
	murEst.Parent = anciens -- garde son nom : MurEst
	noter("MurEst rangé dans Decor_Anciens")
end
local falaises = bordure and bordure:FindFirstChild("Falaises")
if falaises then
	local cibles = { Vector3.new(277, 0, 0), Vector3.new(277, 0, -55.7), Vector3.new(280, 0, 55.7) }
	for _, falaise in falaises:GetChildren() do
		local p = falaise:GetPivot().Position
		for _, cible in cibles do
			if math.abs(p.X - cible.X) < 4 and math.abs(p.Z - cible.Z) < 4 then
				falaise.Name = string.format("Falaise_%d_%d", math.round(p.X), math.round(p.Z))
				falaise.Parent = anciens
				noter("falaise " .. falaise.Name .. " rangée dans Decor_Anciens")
			end
		end
	end
end

--------------------------------------------------------------------------------
-- 2. Les modèles de récolte (ServerStorage/ModelesRecolte), faciles à remplacer.
-- Règle : PrimaryPart "Base" à plat sous le pied (bas de la Base = le sol), une Part
-- "Prompt", les fruits avec l'attribut Fruit = true, attribut Sorte.
--------------------------------------------------------------------------------
local modeles = dossier("ModelesRecolte", ServerStorage)

local function nouveauModele(nom, sorte)
	local m = Instance.new("Model")
	m.Name = nom
	if sorte then
		m:SetAttribute("Sorte", sorte)
	end
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- arrive en entier sur l'écran
	return m
end

local function base(m, taille)
	local b = piece({ Nom = "Base", Taille = Vector3.new(taille, 0.2, taille), CFrame = CFrame.new(0, 0.1, 0), Transparence = 1, Parent = m })
	m.PrimaryPart = b
	return b
end

local function fruit(m, position, diametre)
	local f = piece({ Nom = "Fraise", Forme = Enum.PartType.Ball, Couleur = C.Fraise, Taille = Vector3.one * diametre, CFrame = CFrame.new(position), Parent = m })
	f:SetAttribute("Fruit", true)
	return f
end

-- Arbre à fraises (8 pièces, ≈ 9 studs de haut, style « low-poly » en blocs tournés)
local arbre = nouveauModele("ArbreFraise", "ArbreFraise")
base(arbre, 3)
piece({ Nom = "Tronc", Couleur = C.Tronc, Taille = Vector3.new(1, 4.6, 1), CFrame = CFrame.new(0, 2.3, 0), Parent = arbre })
piece({ Nom = "Feuillage", Couleur = C.Feuille, Taille = Vector3.new(5, 3.6, 5), CFrame = CFrame.new(0, 5.6, 0) * CFrame.Angles(0, math.rad(45), 0), Parent = arbre })
piece({ Nom = "FeuillageHaut", Couleur = C.Herbe, Taille = Vector3.new(3.4, 2.6, 3.4), CFrame = CFrame.new(0.2, 7.8, -0.1) * CFrame.Angles(math.rad(12), math.rad(20), math.rad(8)), Parent = arbre })
fruit(arbre, Vector3.new(2.3, 5.0, 1.0), 0.9)
fruit(arbre, Vector3.new(-1.4, 5.3, 2.2), 0.9)
fruit(arbre, Vector3.new(0.4, 4.4, -2.5), 0.9)
piece({ Nom = "Prompt", Taille = Vector3.one, CFrame = CFrame.new(0, 3, 0), Transparence = 1, Parent = arbre })
arbre.Parent = modeles

-- Buisson de fraises (5 pièces, ≈ 2,5 studs de haut)
local buisson = nouveauModele("BuissonFraise", "BuissonFraise")
base(buisson, 3)
piece({ Nom = "Feuillage", Couleur = C.Feuille, Taille = Vector3.new(3, 2, 3), CFrame = CFrame.new(0, 1.1, 0) * CFrame.Angles(0, math.rad(45), 0), Parent = buisson })
fruit(buisson, Vector3.new(1.3, 1.7, 0.4), 0.8)
fruit(buisson, Vector3.new(-0.6, 2.0, 1.1), 0.8)
piece({ Nom = "Prompt", Taille = Vector3.one, CFrame = CFrame.new(0, 1.6, 0), Transparence = 1, Parent = buisson })
buisson.Parent = modeles

-- Bac de dépôt (6 pièces). La Part "Zone" est la seule qui détecte le joueur (CanTouch).
local bac = nouveauModele("BacDepot", nil)
base(bac, 6)
piece({ Nom = "Cuve", Couleur = C.CaramelFonce, Taille = Vector3.new(6, 2, 4), CFrame = CFrame.new(0, 1.2, 0), Parent = bac })
piece({ Nom = "Bord", Couleur = C.Rose, Taille = Vector3.new(6.4, 0.4, 4.4), CFrame = CFrame.new(0, 2.3, 0), Parent = bac })
piece({ Nom = "FraiseDecor1", Forme = Enum.PartType.Ball, Couleur = C.Fraise, Taille = Vector3.one * 1.1, CFrame = CFrame.new(-1, 2.4, 0.3), Parent = bac })
piece({ Nom = "FraiseDecor2", Forme = Enum.PartType.Ball, Couleur = C.Fraise, Taille = Vector3.one * 1.1, CFrame = CFrame.new(1.2, 2.5, -0.4), Parent = bac })
local zone = piece({ Nom = "Zone", Taille = Vector3.new(7, 5, 5), CFrame = CFrame.new(0, 2.6, 0), Transparence = 1, Parent = bac })
zone.CanTouch = true
bac.Parent = modeles
noter("ServerStorage/ModelesRecolte : ArbreFraise (8 pièces), BuissonFraise (5), BacDepot (6)")

--------------------------------------------------------------------------------
-- 3. Le monde : Workspace/Monde/Iles/Verger
--------------------------------------------------------------------------------
local SOL = 0.05 -- dessus de l'herbe de la carte
local Z_PONT = -15 -- le sentier et le pont passent ici (évite l'arbre en (230, 0))
local CENTRE_ILE = Vector3.new(530, 0, 0)
local RAYON_ILE = 80

local monde = dossier("Monde", workspace)
local iles = dossier("Iles", monde)
local verger = dossier("Verger", iles)
verger:SetAttribute("Quartier", "Verger")

-- Les 2 morceaux du mur est de la carte, avec une ouverture de 14 studs pour le pont
local mursCarte = dossier("MursCarte", monde)
local DEMI_OUVERTURE = 7
local zMin, zMax = -199, 199 -- comme l'ancien MurEst (398 de long)
local basOuverture, hautOuverture = Z_PONT - DEMI_OUVERTURE, Z_PONT + DEMI_OUVERTURE
piece({ Nom = "MurEst_Sud", Mur = true, Transparence = 1, Taille = Vector3.new(4, 80, basOuverture - zMin), CFrame = CFrame.new(264, 40, (zMin + basOuverture) / 2), Parent = mursCarte })
piece({ Nom = "MurEst_Nord", Mur = true, Transparence = 1, Taille = Vector3.new(4, 80, zMax - hautOuverture), CFrame = CFrame.new(264, 40, (hautOuverture + zMax) / 2), Parent = mursCarte })

-- La barrière de verrou (invisible, sans collision pour le serveur ; l'écran d'un joueur
-- pour qui l'île serait fermée la rend solide chez lui seulement)
local barriere = piece({ Nom = "Barriere", Transparence = 1, Taille = Vector3.new(2, 10, 14), CFrame = CFrame.new(268, 5, Z_PONT), Parent = verger })
barriere:SetAttribute("Quartier", "Verger")

-- Sentier de caramel, du bord de la place du hub jusqu'au pont
local sentier = dossier("Sentier", verger)
piece({ Nom = "SentierVersPont", Couleur = C.Caramel, Taille = Vector3.new(226, 0.2, 10), CFrame = CFrame.new(149, 0.01, Z_PONT), Parent = sentier })

-- Le pont de bonbon (Model « Persistent » : toujours chargé sur l'écran, pour ne jamais
-- marcher sur un pont pas encore arrivé)
local pont = dossier("Pont", verger, "Model")
pont.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
local X_DEBUT, X_FIN = 262, 451.4
local NB_PLANCHES = 32
local longueurPlanche = (X_FIN - X_DEBUT) / NB_PLANCHES
local DESSUS_PONT = 0.2
for i = 1, NB_PLANCHES do
	local x = X_DEBUT + (i - 0.5) * longueurPlanche
	piece({ Nom = "Planche", Sol = true, Couleur = if i % 2 == 0 then C.Blanc else C.Rose,
		Taille = Vector3.new(longueurPlanche, 0.6, 12), CFrame = CFrame.new(x, DESSUS_PONT - 0.3, Z_PONT), Parent = pont })
end
for _, cote in { -1, 1 } do
	local z = Z_PONT + cote * 5.6
	piece({ Nom = "Rambarde", Couleur = C.Blanc, Taille = Vector3.new(X_FIN - X_DEBUT, 0.4, 0.4), CFrame = CFrame.new((X_DEBUT + X_FIN) / 2, DESSUS_PONT + 1.6, z), Parent = pont })
	for k = 0, 8 do
		local x = X_DEBUT + 4 + k * ((X_FIN - X_DEBUT - 8) / 8)
		piece({ Nom = "Poteau", Couleur = C.Rose, Forme = Enum.PartType.Cylinder, Taille = Vector3.new(1.6, 0.5, 0.5),
			CFrame = CFrame.new(x, DESSUS_PONT + 0.8, z) * CFrame.Angles(0, 0, math.rad(90)), Parent = pont })
	end
end

-- La mer : surface décorative SANS collision, fond de sable solide, murs invisibles au large
local FOND = -3.5 -- dessus du fond de la mer
local mer = dossier("Mer", verger, "Model")
mer.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
piece({ Nom = "SurfaceEau", Couleur = C.Eau, Transparence = 0.2, Taille = Vector3.new(1100, 0.4, 1000), CFrame = CFrame.new(266 + 550, -1.2, 0), Parent = mer })
piece({ Nom = "FondDeSable", Sol = true, Couleur = C.SableMouille, Matiere = Enum.Material.Sand, Taille = Vector3.new(460, 2, 380), CFrame = CFrame.new(266 + 230, FOND - 1, 0), Parent = mer })
local X_LARGE, Z_LARGE = 712, 180
piece({ Nom = "MurLargeEst", Mur = true, Transparence = 1, Taille = Vector3.new(4, 80, 2 * Z_LARGE), CFrame = CFrame.new(X_LARGE, 36, 0), Parent = mer })
piece({ Nom = "MurLargeNord", Mur = true, Transparence = 1, Taille = Vector3.new(X_LARGE - 266, 80, 4), CFrame = CFrame.new((266 + X_LARGE) / 2, 36, Z_LARGE), Parent = mer })
piece({ Nom = "MurLargeSud", Mur = true, Transparence = 1, Taille = Vector3.new(X_LARGE - 266, 80, 4), CFrame = CFrame.new((266 + X_LARGE) / 2, 36, -Z_LARGE), Parent = mer })

-- Pente de sable : le haut contre le bord de ce qui est au-dessus (pont ou île), le bas sur
-- le fond. Une WedgePart descend vers sa face avant : on la tourne vers l'extérieur.
local function pente(nom, hautDuBord, direction, dessus, largeur, parent)
	local longueur = 8
	local hauteur = dessus - FOND
	local centre = hautDuBord + direction * (longueur / 2)
	local cf = CFrame.lookAt(Vector3.new(centre.X, FOND + hauteur / 2, centre.Z), Vector3.new(centre.X, FOND + hauteur / 2, centre.Z) + direction)
	return piece({ Nom = nom, Classe = "WedgePart", Sol = true, Couleur = C.Sable, Matiere = Enum.Material.Sand,
		Taille = Vector3.new(largeur, hauteur, longueur), CFrame = cf, Parent = parent })
end

-- Sable de remontée le long de tout le pont, des deux côtés, tous les ≈ 38 studs
for _, x in { 282, 320, 358, 396, 434 } do
	pente("PenteNord", Vector3.new(x, 0, Z_PONT + 6), Vector3.new(0, 0, 1), DESSUS_PONT, 6, mer)
	pente("PenteSud", Vector3.new(x, 0, Z_PONT - 6), Vector3.new(0, 0, -1), DESSUS_PONT, 6, mer)
end

-- L'île : herbe + anneau de sable, posés sur le fond ; 8 pentes de sable autour
local ile = dossier("Ile", verger, "Model")
ile.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
local VERTICAL = CFrame.Angles(0, 0, math.rad(90)) -- un cylindre debout
local hauteurIle = SOL - (FOND - 0.5)
piece({ Nom = "Herbe", Sol = true, Couleur = C.Herbe, Forme = Enum.PartType.Cylinder, Taille = Vector3.new(hauteurIle, 2 * RAYON_ILE, 2 * RAYON_ILE),
	CFrame = CFrame.new(CENTRE_ILE.X, SOL - hauteurIle / 2, CENTRE_ILE.Z) * VERTICAL, Parent = ile })
local hauteurSable = (SOL - 0.15) - (FOND - 0.5)
piece({ Nom = "Plage", Sol = true, Couleur = C.Sable, Matiere = Enum.Material.Sand, Forme = Enum.PartType.Cylinder, Taille = Vector3.new(hauteurSable, 2 * RAYON_ILE + 12, 2 * RAYON_ILE + 12),
	CFrame = CFrame.new(CENTRE_ILE.X, (SOL - 0.15) - hauteurSable / 2, CENTRE_ILE.Z) * VERTICAL, Parent = ile })
for k = 0, 7 do
	local angle = math.rad(22.5 + 45 * k)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	pente("PenteIle", CENTRE_ILE + direction * (RAYON_ILE + 6), direction, SOL - 0.15, 8, ile)
end
piece({ Nom = "SentierIle", Couleur = C.Caramel, Taille = Vector3.new(150, 0.2, 8), CFrame = CFrame.new(X_FIN + 75, SOL + 0.06, Z_PONT), Parent = ile })

-- Les points de récolte (posés à la main ici : on peut les déplacer dans Studio)
local recolte = dossier("Recolte", verger)
local numero = 0
local function poser(modele, nom, position, angle)
	numero += 1
	local copie = modele:Clone()
	copie.Name = nom
	copie:PivotTo(CFrame.new(position.X, SOL + 0.1, position.Z) * CFrame.Angles(0, math.rad(angle or 0), 0))
	CollectionService:AddTag(copie, "PointRecolte")
	copie.Parent = recolte
end
-- 5 buissons le long du sentier de la carte (en quinconce)
for i, x in { 70, 110, 150, 190, 230 } do
	poser(buisson, "BuissonSentier" .. i, Vector3.new(x, 0, Z_PONT + (if i % 2 == 1 then -8 else 8)), 20 * i)
end
-- 2 buissons au bout du pont, 3 sur le sentier de l'île
poser(buisson, "BuissonPont1", Vector3.new(458, 0, Z_PONT + 11), 10)
poser(buisson, "BuissonPont2", Vector3.new(458, 0, Z_PONT - 11), 70)
poser(buisson, "BuissonIle1", Vector3.new(592, 0, Z_PONT + 11), 30)
poser(buisson, "BuissonIle2", Vector3.new(592, 0, Z_PONT - 11), 50)
poser(buisson, "BuissonIle3", Vector3.new(603, 0, Z_PONT), 0)
-- 8 arbres : 2 rangées de 4 de part et d'autre du sentier de l'île
for i, x in { 486, 516, 546, 576 } do
	poser(arbre, "ArbreNord" .. i, Vector3.new(x, 0, Z_PONT + 14), 15 * i)
	poser(arbre, "ArbreSud" .. i, Vector3.new(x, 0, Z_PONT - 14), 40 + 15 * i)
end

-- Un peu de décor sur l'île (copies des modèles de la carte), loin du sentier
local decor = dossier("Decor", verger)
local modelesDecor = ServerStorage:FindFirstChild("ModelesDecor")
local function copierDecor(nom, position, angle, echelle)
	local modele = modelesDecor and modelesDecor:FindFirstChild(nom)
	if modele == nil then
		return
	end
	local copie = modele:Clone()
	copie:PivotTo(CFrame.new(position.X, SOL, position.Z) * CFrame.Angles(0, math.rad(angle), 0))
	if echelle then
		copie:ScaleTo(echelle)
	end
	for _, p in copie:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
		end
	end
	copie.Parent = decor
end
copierDecor("Sucette", Vector3.new(520, 0, 52), 0, 1.2)
copierDecor("Sucette", Vector3.new(585, 0, 40), 30, 1)
copierDecor("Sucette", Vector3.new(500, 0, -62), 180, 1.1)
copierDecor("Champignon", Vector3.new(470, 0, 28), 0, 1.3)
copierDecor("Champignon", Vector3.new(560, 0, 45), 40, 1)
copierDecor("Champignon", Vector3.new(540, 0, -55), 80, 1.4)
copierDecor("Champignon", Vector3.new(590, 0, -45), 120, 1.1)

-- Comptage
local nombre = 0
for _, p in monde:GetDescendants() do
	if p:IsA("BasePart") then
		nombre += 1
	end
end
noter("Workspace/Monde construit : " .. nombre .. " pièces ; " .. #recolte:GetChildren() .. " points de récolte")

pcall(function()
	ChangeHistoryService:SetWaypoint("Verger construit")
end)
print("Construction du verger :\n  " .. table.concat(journal, "\n  "))
return table.concat(journal, "\n")
