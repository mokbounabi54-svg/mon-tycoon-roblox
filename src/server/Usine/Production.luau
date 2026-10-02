-- La chaîne de production d'une usine.
--
-- Chaque machine est un Model. Le script ne regarde QUE ses attributs et une ou
-- deux pièces au nom précis : tout le reste est de la décoration, que tu peux
-- remplacer par tes propres modèles 3D sans rien casser.
--
--   Role = "Melangeur"      crée des bonbons (de la pâte) à intervalle régulier
--     attributs : ValeurDepart (nombre), Intervalle (secondes)
--     pièce     : "Sortie" = l'endroit où la pâte apparaît (juste au-dessus du tapis)
--
--   Role = "Tapis"          fait avancer les bonbons posés dessus
--     attributs : Vitesse (studs par seconde)
--     pièce     : "Surface" = la Part qui avance, dans le sens de sa face avant (Front)
--
--   Role = "Transformation" cuiseur, mouleur, emballeuse...
--     attributs : Etape (texte, ex : "Cuisson"), Multiplicateur (nombre),
--                 et pour l'apparence (optionnels) : CouleurBonbon (couleur),
--                 FormeBonbon ("Boule", "Cube" ou "Cylindre"), MatiereBonbon (ex : "Foil")
--     pièce     : "Zone" = une boîte invisible ; chaque bonbon qui la traverse est
--                 transformé UNE seule fois par étape
--
--   Role = "PointDeVente"   vend les bonbons et met l'argent dans la caisse
--     pièce     : "Zone"
--
-- Les machines du dossier "Machines" de l'usine marchent dès le départ ;
-- celles du dossier "Achats" démarrent quand elles sont achetées.
-- Un Model sans Role est un groupe : chaque machine qu'il contient démarre.

local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

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

local function estUnBonbonDe(usine, piece)
	return piece.Name == "Bonbon" and typeof(piece:GetAttribute("Valeur")) == "number" and piece:IsDescendantOf(usine)
end

local function creerBonbon(dossierBonbons, sortie, valeur)
	local bonbon = Instance.new("Part")
	bonbon.Name = "Bonbon"
	bonbon.Shape = Enum.PartType.Ball
	bonbon.Size = Vector3.new(1, 1, 1)
	bonbon.Material = Enum.Material.SmoothPlastic
	bonbon.Color = COULEUR_PATE
	bonbon.CollisionGroup = "Bonbons"
	bonbon.Position = sortie.Position - Vector3.new(0, sortie.Size.Y / 2 + 0.6, 0)
	bonbon:SetAttribute("Valeur", valeur)
	bonbon.Parent = dossierBonbons

	-- C'est le serveur qui calcule la physique du bonbon (pas l'ordinateur du joueur) :
	-- plus fluide pour tout le monde, et impossible de tricher en le déplaçant.
	bonbon:SetNetworkOwner(nil)
	Debris:AddItem(bonbon, DUREE_DE_VIE_BONBON)
end

local function demarrerMelangeur(usine, dossierBonbons, machine)
	local sortie = trouverPiece(machine, "Sortie")
	if sortie == nil then
		return
	end
	local valeur = machine:GetAttribute("ValeurDepart") or 1
	local intervalle = machine:GetAttribute("Intervalle") or 2

	-- task.spawn lance la boucle à côté, sans bloquer le reste du script.
	-- Elle s'arrête quand la machine est détruite (avec l'usine).
	task.spawn(function()
		while machine.Parent ~= nil do
			if #dossierBonbons:GetChildren() < MAX_BONBONS_PAR_USINE then
				creerBonbon(dossierBonbons, sortie, valeur)
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

	zone.Touched:Connect(function(piece)
		if not estUnBonbonDe(usine, piece) or piece:GetAttribute(etape) then
			return -- pas un bonbon de cette usine, ou déjà passé par cette étape
		end
		piece:SetAttribute(etape, true)
		piece:SetAttribute("Valeur", piece:GetAttribute("Valeur") * multiplicateur)

		if typeof(couleur) == "Color3" then
			piece.Color = couleur
		end
		if forme then
			piece.Shape = forme
		end
		if matiere then
			piece.Material = matiere
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
		if not estUnBonbonDe(usine, piece) then
			return
		end
		local valeur = math.floor(piece:GetAttribute("Valeur") + 0.5) -- arrondi au $ près
		piece:SetAttribute("Valeur", nil) -- pour ne pas le vendre deux fois
		piece:Destroy()
		caisse:SetAttribute("Stock", (caisse:GetAttribute("Stock") or 0) + valeur)
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
