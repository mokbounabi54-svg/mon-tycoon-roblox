-- Rareté des bonbons : tirage au sort, pitié, bonus de chance et apparence.
--
-- Chaque bonbon tire sa rareté quand il sort du mélangeur. Sa valeur est tout
-- de suite multipliée par celui de sa rareté, et comme les machines multiplient
-- ensuite cette valeur, la rareté compte jusqu'à la vente.
-- Le bonbon garde le nom de sa rareté dans son attribut "Rarete".
--
-- Tous les chiffres (chances, multiplicateurs, couleurs...) sont dans
-- ReplicatedStorage/Shared/Reglages. Le tirage se fait uniquement ici, sur le serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local Remotes = require(script.Parent.Parent:WaitForChild("Remotes"))

local RARETES = Reglages.Raretes
local annonce = Remotes.obtenir("Annonce") -- messages à l'écran des joueurs
local aleatoire = Random.new()

local Rarete = {}

-- rangs["Rare"] = 3 : la position de chaque rareté dans la liste (1 = Commun)
local rangs = {}
for rang, infos in RARETES do
	rangs[infos.Nom] = rang
end

-- On vérifie les réglages au démarrage, pour repérer tout de suite une faute de frappe
local totalChances = 0
for rang, infos in RARETES do
	if rang > 1 then
		totalChances += infos.Chance or 0
	end
	if infos.Matiere then
		local trouvee, matiere = pcall(function()
			return Enum.Material[infos.Matiere]
		end)
		if trouvee then
			infos.MatiereEnum = matiere
		else
			warn("Reglages : matière '" .. infos.Matiere .. "' inconnue pour la rareté " .. infos.Nom)
		end
	end
end
if totalChances > 100 then
	warn("Reglages : les chances des raretés dépassent 100 % (" .. totalChances .. " %)")
end
local rangPitie = rangs[Reglages.Pitie.Rarete]
if rangPitie == nil then
	warn("Reglages : la rareté de pitié '" .. tostring(Reglages.Pitie.Rarete) .. "' n'existe pas")
end

-- Renvoie les réglages d'une rareté d'après son nom (Commun si le nom est inconnu ou nil)
function Rarete.infos(nom)
	return RARETES[rangs[nom] or 1]
end

-- Renvoie le rang d'une rareté (1 = Commun, 2 = Peu commun...), nil si le nom est inconnu
function Rarete.rang(nom)
	return rangs[nom]
end

-- Tire un rang au hasard, en tenant compte du bonus de chance du joueur
local function tirerRang(joueur)
	local bonus = joueur and joueur:GetAttribute("BonusChance")
	if typeof(bonus) ~= "number" then
		bonus = 0
	end
	local facteur = math.max(1 + bonus, 0)

	-- Chance de chaque rareté au-dessus de Commun, avec le bonus
	local chances = {}
	local total = 0
	for rang = 2, #RARETES do
		chances[rang] = (RARETES[rang].Chance or 0) * facteur
		total += chances[rang]
	end
	-- Avec un très gros bonus, on ne peut pas dépasser 100 % : on remet à l'échelle
	local echelle = if total > 100 then 100 / total else 1

	-- On tire un nombre entre 0 et 100 et on regarde dans quelle « tranche » il tombe
	local tirage = aleatoire:NextNumber() * 100
	local cumul = 0
	for rang = #RARETES, 2, -1 do
		cumul += chances[rang] * echelle
		if tirage < cumul then
			return rang
		end
	end
	return 1 -- Commun : le reste
end

-- Choisit la rareté d'un nouveau bonbon du joueur (peut être nil si le joueur est parti).
-- Renvoie le rang. Met à jour le compteur de pitié du joueur.
function Rarete.tirer(joueur)
	local rang = tirerRang(joueur)

	-- Réglage de test (seulement dans Studio) : toujours la même rareté
	local forcee = Reglages.Test.RareteForcee
	if forcee ~= nil and RunService:IsStudio() then
		if rangs[forcee] then
			rang = rangs[forcee]
		else
			warn("Reglages.Test.RareteForcee : rareté '" .. tostring(forcee) .. "' inconnue")
		end
	end

	-- Pitié : après trop de bonbons sous la rareté de pitié, le suivant l'atteint
	if joueur and rangPitie then
		local compteur = joueur:GetAttribute("CompteurPitie") or 0
		if rang < rangPitie and compteur >= Reglages.Pitie.Nombre then
			rang = rangPitie
		end
		if rang >= rangPitie then
			joueur:SetAttribute("CompteurPitie", 0)
		else
			joueur:SetAttribute("CompteurPitie", compteur + 1)
		end
	end

	return rang
end

local function ajouterParticules(bonbon, couleur)
	local particules = Instance.new("ParticleEmitter")
	particules.Name = "Etincelles"
	particules.Color = ColorSequence.new(couleur)
	particules.LightEmission = 1
	particules.Rate = 8
	particules.Lifetime = NumberRange.new(0.5, 0.9)
	particules.Speed = NumberRange.new(1, 2)
	particules.SpreadAngle = Vector2.new(180, 180)
	particules.Size = NumberSequence.new(0.35, 0)
	particules.Parent = bonbon
end

local function jouerSon(bonbon, idSon)
	local son = Instance.new("Sound")
	son.SoundId = idSon
	son.Volume = 0.6
	son.RollOffMaxDistance = 100 -- on ne l'entend pas depuis les autres parcelles
	son.Parent = bonbon
	son:Play()
end

local function ajouterLumiere(bonbon, couleur, portee)
	local lumiere = Instance.new("PointLight")
	lumiere.Color = couleur
	lumiere.Range = portee
	lumiere.Brightness = Reglages.LuminositeLumiere
	lumiere.Parent = bonbon
end

-- Un bonbon est soit un modèle (ServerStorage/ModelesBonbons), soit une simple
-- boule (ancien rendu). Pour un modèle, les effets vont sur sa pièce "Corps"...
local function corpsDe(bonbon)
	return if bonbon:IsA("Model") then bonbon.PrimaryPart else bonbon
end

-- ... et la couleur de rareté seulement sur les pièces qui ont l'attribut Teinte
-- (le bonbon lui-même ; le papier, les reflets et les pépins gardent leur couleur).
local function piecesTeintees(bonbon)
	if not bonbon:IsA("Model") then
		return { bonbon }
	end
	local pieces = {}
	for _, piece in bonbon:GetDescendants() do
		if piece:IsA("BasePart") and piece:GetAttribute("Teinte") == true then
			table.insert(pieces, piece)
		end
	end
	return pieces
end

-- Apparence de la rareté : couleur et matière (pièces Teinte), particules et
-- lumière (Corps). Appelé à la création du bonbon, puis à chaque changement de
-- modèle (voir Production). Les machines ne changent que ce que la rareté laisse libre.
function Rarete.habiller(bonbon)
	local infos = Rarete.infos(bonbon:GetAttribute("Rarete"))
	for _, piece in piecesTeintees(bonbon) do
		if infos.Couleur then
			piece.Color = infos.Couleur
		end
		if infos.MatiereEnum then
			piece.Material = infos.MatiereEnum
		end
	end

	local corps = corpsDe(bonbon)
	local couleur = infos.Couleur or corps.Color
	if infos.Particules then
		ajouterParticules(corps, couleur)
	end
	if infos.Lumiere then
		ajouterLumiere(corps, couleur, infos.Lumiere)
	end
end

-- Donne la rareté "rang" à un bonbon déjà posé dans l'usine de "proprietaire" :
-- valeur, apparence, son et messages.
function Rarete.appliquer(bonbon, rang, proprietaire)
	local infos = RARETES[rang]
	bonbon:SetAttribute("Rarete", infos.Nom)
	bonbon:SetAttribute("Valeur", bonbon:GetAttribute("Valeur") * infos.Multiplicateur)
	Rarete.habiller(bonbon)

	local couleur = infos.Couleur or Color3.new(1, 1, 1)
	if infos.Son then
		jouerSon(corpsDe(bonbon), infos.Son)
	end

	if proprietaire == nil then
		return
	end
	if infos.MessageProprietaire then
		annonce:FireClient(proprietaire, infos.MessageProprietaire, couleur)
	end
	if infos.AnnonceServeur then
		local texte = infos.AnnonceServeur:gsub("{joueur}", function()
			return proprietaire.DisplayName
		end)
		annonce:FireAllClients(texte, couleur)
	end
end

return Rarete
