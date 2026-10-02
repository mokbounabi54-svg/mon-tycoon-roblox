-- La chaîne de production d'une usine.
--
-- Chaque machine est un Model. Le script ne regarde QUE ses attributs et une ou
-- deux pièces au nom précis : tout le reste est de la décoration, que tu peux
-- remplacer par tes propres modèles 3D sans rien casser.
--
--   Role = "Melangeur"      crée des bonbons (de la pâte) à intervalle régulier ;
--                           chaque bonbon tire sa rareté à ce moment-là (voir Rarete)
--     attributs : Intervalle (secondes), TypeBonbon (ex : "Fraise" ; le bonbon copie
--                 le modèle <Type>/Pate). La valeur de départ est dans Reglages.Types.
--     pièce     : "Sortie" = l'endroit où la pâte apparaît (juste au-dessus du tapis)
--
--   Role = "Tapis"          fait avancer les bonbons posés dessus
--     attributs : Vitesse (studs par seconde)
--     pièce     : "Surface" = la Part qui avance, dans le sens de sa face avant (Front)
--
--   Role = "Transformation" cuiseur, mouleur, emballeuse...
--     attributs : Etape (texte, ex : "Cuisson"), Multiplicateur (nombre),
--                 EtapeBonbon (ex : "Cuit" : le bonbon-modèle prend le modèle <Type>/Cuit),
--                 et pour l'ancien rendu (optionnels) : CouleurBonbon (couleur),
--                 FormeBonbon ("Boule", "Cube" ou "Cylindre"), MatiereBonbon (ex : "Foil")
--     pièce     : "Zone" = une boîte invisible ; chaque bonbon qui la traverse est
--                 transformé UNE seule fois par étape
--
--   Role = "PointDeVente"   garde les bonbons assez rares dans l'inventaire du joueur,
--                           vend les autres (prix : module Prix) et met l'argent dans la caisse
--     pièce     : "Zone"
--
-- Les machines du dossier "Machines" de l'usine marchent dès le départ ;
-- celles du dossier "Achats" démarrent quand elles sont achetées.
-- Un Model sans Role est un groupe : chaque machine qu'il contient démarre.

local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local Rarete = require(script.Parent:WaitForChild("Rarete"))
local Prix = require(script.Parent:WaitForChild("Prix"))
local Inventaire = require(script.Parent.Parent:WaitForChild("Inventaire"))
local Carnet = require(script.Parent.Parent:WaitForChild("Carnet"))

-- Les modèles des bonbons (créés dans Studio, pas dans les fichiers)
local dossierModeles = ServerStorage:FindFirstChild("ModelesBonbons")

local MAX_BONBONS_PAR_USINE = 80 -- au-delà, les mélangeurs attendent (pour ne pas faire ramer le jeu)
local DUREE_DE_VIE_BONBON = 30 -- un bonbon tombé du tapis disparaît au bout de ce temps
local COULEUR_PATE = Color3.fromRGB(255, 200, 215)

local FORMES = {
	Boule = Enum.PartType.Ball,
	Cube = Enum.PartType.Block,
	Cylindre = Enum.PartType.Cylinder,
}

-- Groupes de collision : les bonbons ne se cognent ni entre eux (pas de bouchons
-- sur les tapis), ni contre les joueurs (impossible de les faire tomber du tapis).
PhysicsService:RegisterCollisionGroup("Bonbons")
PhysicsService:RegisterCollisionGroup("Joueurs")
PhysicsService:CollisionGroupSetCollidable("Bonbons", "Bonbons", false)
PhysicsService:CollisionGroupSetCollidable("Bonbons", "Joueurs", false)

local function rangerDansGroupeJoueurs(piece)
	if piece:IsA("BasePart") then
		piece.CollisionGroup = "Joueurs"
	end
end

local function quandUnPersonnageApparait(personnage)
	for _, piece in personnage:GetDescendants() do
		rangerDansGroupeJoueurs(piece)
	end
	personnage.DescendantAdded:Connect(rangerDansGroupeJoueurs)
end

local function surveillerJoueur(joueur)
	joueur.CharacterAdded:Connect(quandUnPersonnageApparait)
	if joueur.Character then
		quandUnPersonnageApparait(joueur.Character)
	end
end

Players.PlayerAdded:Connect(surveillerJoueur)
for _, joueur in Players:GetPlayers() do
	surveillerJoueur(joueur)
end

-- Cherche dans la machine la pièce qui porte ce nom (même rangée dans un sous-modèle)
local function trouverPiece(machine, nom)
	local piece = machine:FindFirstChild(nom, true)
	if piece == nil or not piece:IsA("BasePart") then
		warn("La machine '" .. machine.Name .. "' n'a pas de Part nommée '" .. nom .. "' : elle ne fonctionnera pas")
		return nil
	end
	return piece
end

-- Le modèle de bonbon d'un type et d'une étape (ex : "Fraise", "Cuit"), rangé dans
-- ServerStorage/ModelesBonbons/<Type>/<Etape>. Renvoie nil s'il n'existe pas :
-- le bonbon garde alors l'ancien rendu (une simple boule).
local function trouverModele(typeBonbon, etape)
	if dossierModeles == nil or typeof(typeBonbon) ~= "string" or typeof(etape) ~= "string" then
		return nil
	end
	local dossierType = dossierModeles:FindFirstChild(typeBonbon)
	local modele = dossierType and dossierType:FindFirstChild(etape)
	if modele == nil or not modele:IsA("Model") or modele.PrimaryPart == nil then
		return nil
	end
	return modele
end

-- Retrouve le bonbon à partir de la pièce qui touche une zone de machine.
-- Pour un bonbon-modèle, seule sa pièce "Corps" peut toucher : le bonbon est son parent.
-- Renvoie nil si ce n'est pas un bonbon de cette usine.
local function trouverBonbon(usine, piece)
	local bonbon = piece
	if piece.Name == "Corps" and piece.Parent and piece.Parent:IsA("Model") then
		bonbon = piece.Parent
	end
	if bonbon.Name == "Bonbon" and typeof(bonbon:GetAttribute("Valeur")) == "number" and bonbon:IsDescendantOf(usine) then
		return bonbon
	end
	return nil
end

-- Copie un modèle de bonbon et le place à "position", tourné comme la parcelle
-- (pour que le cœur et la papillote soient toujours dans le bon sens).
-- Le bonbon n'est pas encore rangé dans l'usine : c'est à l'appelant de le faire.
local function copierModele(usine, modele, position)
	local bonbon = modele:Clone()
	bonbon.Name = "Bonbon"
	for _, piece in bonbon:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.CollisionGroup = "Bonbons"
		end
	end
	bonbon:PivotTo(CFrame.new(position) * usine.Sol.CFrame.Rotation)
	return bonbon
end

-- C'est le serveur qui calcule la physique du bonbon (pas l'ordinateur du joueur) :
-- plus fluide pour tout le monde, et impossible de tricher en le déplaçant.
local function lancerPhysique(bonbon)
	local corps = if bonbon:IsA("Model") then bonbon.PrimaryPart else bonbon
	corps:SetNetworkOwner(nil)
	Debris:AddItem(bonbon, DUREE_DE_VIE_BONBON)
end

-- L'ancien rendu : une boule rose, que les machines déforment et recolorent
local function creerBouleDePate(position)
	local bonbon = Instance.new("Part")
	bonbon.Name = "Bonbon"
	bonbon.Shape = Enum.PartType.Ball
	bonbon.Size = Vector3.new(1, 1, 1)
	bonbon.Material = Enum.Material.SmoothPlastic
	bonbon.Color = COULEUR_PATE
	bonbon.CollisionGroup = "Bonbons"
	bonbon.Position = position
	return bonbon
end

local function creerBonbon(usine, dossierBonbons, sortie, valeur, typeBonbon)
	local position = sortie.Position - Vector3.new(0, sortie.Size.Y / 2 + 0.6, 0)
	local modele = trouverModele(typeBonbon, "Pate")
	local bonbon = if modele then copierModele(usine, modele, position) else creerBouleDePate(position)
	bonbon:SetAttribute("Type", typeBonbon) -- déjà mis par le modèle, mais pas sur une boule
	bonbon:SetAttribute("Valeur", valeur)
	bonbon.Parent = dossierBonbons

	-- Tirage de la rareté (sur le serveur) : elle multiplie la valeur et change l'apparence
	local proprietaire = Players:GetPlayerByUserId(usine:GetAttribute("Proprietaire") or 0)
	Rarete.appliquer(bonbon, Rarete.tirer(proprietaire), proprietaire)
	-- Première fois que le joueur obtient ce type dans cette rareté ? (carnet de collection)
	Carnet.decouvrir(proprietaire, typeBonbon, bonbon:GetAttribute("Rarete"))

	lancerPhysique(bonbon)
end

-- Remplace un bonbon-modèle par le modèle de l'étape suivante, au même endroit et à
-- la même vitesse. Le nouveau garde tout ce que l'ancien avait : valeur, rareté,
-- étapes déjà franchies...
local function changerDeModele(usine, ancien, modele)
	local ancienCorps = ancien.PrimaryPart
	local nouveau = copierModele(usine, modele, ancienCorps.Position)
	for nom, valeur in ancien:GetAttributes() do
		if nom ~= "Type" and nom ~= "Etape" then -- ceux-là viennent du nouveau modèle
			nouveau:SetAttribute(nom, valeur)
		end
	end
	Rarete.habiller(nouveau) -- couleur, matière, effets de la rareté (sans rejouer le son)
	nouveau.Parent = ancien.Parent
	nouveau.PrimaryPart.AssemblyLinearVelocity = ancienCorps.AssemblyLinearVelocity
	ancien:Destroy()
	lancerPhysique(nouveau)
end

local function demarrerMelangeur(usine, dossierBonbons, machine)
	local sortie = trouverPiece(machine, "Sortie")
	if sortie == nil then
		return
	end
	local intervalle = machine:GetAttribute("Intervalle") or 2
	local typeBonbon = machine:GetAttribute("TypeBonbon") -- ex : "Fraise"
	local infosType = Reglages.Types[typeBonbon]
	if infosType == nil then
		warn("Le mélangeur '" .. machine.Name .. "' n'a pas de TypeBonbon connu (voir Reglages.Types) : il ne produit rien")
		return
	end
	local valeur = infosType.ValeurDepart

	-- task.spawn lance la boucle à côté, sans bloquer le reste du script.
	-- Elle s'arrête quand la machine est détruite (avec l'usine).
	task.spawn(function()
		while machine.Parent ~= nil do
			if #dossierBonbons:GetChildren() < MAX_BONBONS_PAR_USINE then
				creerBonbon(usine, dossierBonbons, sortie, valeur, typeBonbon)
			end
			task.wait(intervalle)
		end
	end)
end

local function demarrerTapis(machine)
	local surface = trouverPiece(machine, "Surface")
	if surface == nil then
		return
	end
	-- Une Part ancrée avec une vitesse "fait glisser" ce qui est posé dessus,
	-- sans bouger elle-même : c'est l'astuce classique des tapis roulants.
	surface.Anchored = true
	surface.AssemblyLinearVelocity = surface.CFrame.LookVector * (machine:GetAttribute("Vitesse") or 8)
end

local function demarrerTransformation(usine, machine)
	local zone = trouverPiece(machine, "Zone")
	if zone == nil then
		return
	end
	local etape = machine:GetAttribute("Etape") or machine.Name
	local multiplicateur = machine:GetAttribute("Multiplicateur") or 1
	local couleur = machine:GetAttribute("CouleurBonbon")
	local forme = FORMES[machine:GetAttribute("FormeBonbon")]
	local matiere = nil
	local nomMatiere = machine:GetAttribute("MatiereBonbon")
	if typeof(nomMatiere) == "string" then
		local trouvee, resultat = pcall(function()
			return Enum.Material[nomMatiere]
		end)
		if trouvee then
			matiere = resultat
		else
			warn("MatiereBonbon '" .. nomMatiere .. "' inconnue sur '" .. machine.Name .. "'")
		end
	end

	local etapeBonbon = machine:GetAttribute("EtapeBonbon") -- modèle à prendre (ex : "Cuit")

	zone.Touched:Connect(function(piece)
		local bonbon = trouverBonbon(usine, piece)
		if bonbon == nil or bonbon:GetAttribute(etape) then
			return -- pas un bonbon de cette usine, ou déjà passé par cette étape
		end
		bonbon:SetAttribute(etape, true)
		bonbon:SetAttribute("Valeur", bonbon:GetAttribute("Valeur") * multiplicateur)

		if bonbon:IsA("Model") then
			-- Bonbon-modèle : il prend le modèle de cette étape (s'il existe)
			local modele = trouverModele(bonbon:GetAttribute("Type"), etapeBonbon)
			if modele then
				changerDeModele(usine, bonbon, modele)
			end
			return
		end

		-- Ancien rendu. La couleur et la matière d'une rareté passent avant celles
		-- de la machine : seul un bonbon Commun prend les couleurs de la chaîne.
		local rarete = Rarete.infos(bonbon:GetAttribute("Rarete"))
		if typeof(couleur) == "Color3" and rarete.Couleur == nil then
			bonbon.Color = couleur
		end
		if forme then
			bonbon.Shape = forme
		end
		if matiere and rarete.Matiere == nil then
			bonbon.Material = matiere
		end
	end)
end

local function demarrerPointDeVente(usine, machine)
	local zone = trouverPiece(machine, "Zone")
	local caisse = usine:FindFirstChild("Caisse")
	if zone == nil or caisse == nil then
		return
	end

	zone.Touched:Connect(function(piece)
		local bonbon = trouverBonbon(usine, piece)
		if bonbon == nil then
			return
		end
		local typeBonbon = bonbon:GetAttribute("Type")
		local nomRarete = bonbon:GetAttribute("Rarete")
		local mutation = bonbon:GetAttribute("Mutation") or "Normal"
		bonbon:SetAttribute("Valeur", nil) -- pour ne pas le compter deux fois
		bonbon:Destroy()

		-- Rareté assez haute (seuil du joueur) et de la place : il part dans l'inventaire
		local proprietaire = Players:GetPlayerByUserId(usine:GetAttribute("Proprietaire") or 0)
		if Inventaire.essayerDeGarder(proprietaire, typeBonbon, nomRarete, mutation) then
			return
		end

		-- Sinon il est vendu, au même prix que s'il était vendu depuis l'inventaire
		local prix = Prix.calculer(usine, typeBonbon, nomRarete, mutation)
		if prix == nil then
			warn("Bonbon de type '" .. tostring(typeBonbon) .. "' inconnu : vendu 0 $")
			prix = 0
		end
		caisse:SetAttribute("Stock", (caisse:GetAttribute("Stock") or 0) + prix)
	end)
end

-- Démarre la production de l'usine "usine"
return function(usine)
	local dossierBonbons = Instance.new("Folder")
	dossierBonbons.Name = "Bonbons"
	dossierBonbons.Parent = usine

	local demarrerMachine -- déclarée avant pour pouvoir s'appeler elle-même (groupes de machines)
	function demarrerMachine(machine)
		local role = machine:GetAttribute("Role")
		if role == "Melangeur" then
			demarrerMelangeur(usine, dossierBonbons, machine)
		elseif role == "Tapis" then
			demarrerTapis(machine)
		elseif role == "Transformation" then
			demarrerTransformation(usine, machine)
		elseif role == "PointDeVente" then
			demarrerPointDeVente(usine, machine)
		elseif role ~= nil then
			warn("Role '" .. tostring(role) .. "' inconnu sur la machine '" .. machine.Name .. "'")
		elseif machine:IsA("Model") or machine:IsA("Folder") then
			-- Pas de Role : c'est un groupe de machines (ex : l'achat "Zone2", qui
			-- contient le mélangeur, les tapis et le point de vente de la zone 2).
			-- On démarre chaque machine qu'il contient.
			for _, enfant in machine:GetChildren() do
				demarrerMachine(enfant)
			end
		end
	end

	for _, machine in usine:WaitForChild("Machines"):GetChildren() do
		demarrerMachine(machine)
	end

	-- Le module des boutons remet l'objet dans le dossier Achats au moment de l'achat
	usine:WaitForChild("Achats").ChildAdded:Connect(demarrerMachine)
end
