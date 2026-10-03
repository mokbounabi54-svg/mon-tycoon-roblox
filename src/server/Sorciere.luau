-- La sorcière : le joueur lui donne 3 bonbons de la MÊME rareté (depuis son inventaire).
--   Réussite : 1 bonbon de la rareté au-dessus, d'un type tiré parmi les 3 donnés.
--   Échec    : 1 « Bonbon raté » (type à part, prix fixe, hors carnet).
-- Taux, pitié, phrases... : Reglages.Sorciere.
--
-- Pitié : un compteur d'échecs de suite PAR PALIER (la rareté donnée). Après
-- EchecsAvantGarantie échecs, la réussite suivante est garantie. Les compteurs sont
-- sauvegardés (champ PitieSorciere, version 5).
--
-- Anti-triche :
--   - l'écran n'envoie que la liste des 3 piles choisies ; tout est vérifié ici
--     (mêmes raretés, quantités possédées, joueur près de la sorcière...) ;
--   - une seule transformation à la fois par joueur ;
--   - le retrait des 3 bonbons, le tirage et l'ajout du résultat se font d'un seul
--     bloc, sans attente au milieu : rien ne peut s'intercaler, et si le joueur part
--     pendant la fumée, sa sauvegarde est déjà juste. Seule la RÉVÉLATION du
--     résultat attend DureeMiseEnScene secondes (fumée, son).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local Inventaire = require(script.Parent:WaitForChild("Inventaire"))
local Carnet = require(script.Parent:WaitForChild("Carnet"))
local Rarete = require(script.Parent:WaitForChild("Usine"):WaitForChild("Rarete"))

local REGLAGES = Reglages.Sorciere
local RARETES = Reglages.Raretes

local ouvrirSorciere = Remotes.obtenir("SorciereOuvrir") -- serveur -> écran : { Pitie }
local muter = Remotes.obtenir("SorciereMuter") -- écran -> serveur : { clé, clé, clé }
local resultat = Remotes.obtenir("SorciereResultat") -- serveur -> écran

local aleatoire = Random.new()

-- etats[joueur] = { usine, pnj, pitie = { [rareté donnée] = échecs de suite }, enCours }
local etats = {}

local Sorciere = {}

local function phraseAuHasard(liste)
	return liste[aleatoire:NextInteger(1, #liste)]
end

-- La copie de la sorcière posée dans l'usine (dossier PNJ), d'après le modèle
-- ServerStorage/PNJ/Sorciere (créé dans Studio, facile à remplacer). Ce que le
-- script attend du modèle (voir aussi CLAUDE.md, « Remplacer le modèle de la sorcière ») :
--   - PrimaryPart = une Part posée à plat sous ses pieds (la « Base ») : le bas de
--     cette Part est le niveau du sol, et sa face avant (-Z) est la direction du regard ;
--   - une Part "Prompt" contenant une ProximityPrompt ;
--   - (optionnel) une Part "Chaudron" où sort la fumée.
-- Toutes les pièces sont ancrées par le script, au cas où.
local function poserSorciere(usine)
	local dossierPNJ = ServerStorage:FindFirstChild("PNJ")
	local modele = dossierPNJ and dossierPNJ:FindFirstChild("Sorciere")
	if modele == nil or modele.PrimaryPart == nil then
		warn("ServerStorage/PNJ/Sorciere introuvable ou sans PrimaryPart : pas de sorcière dans les usines")
		return nil
	end
	local copie = modele:Clone()
	local base = copie.PrimaryPart
	base.PivotOffset = CFrame.new() -- le repère est le centre de la Base, quelle que soit la retouche dans Studio
	for _, piece in copie:GetDescendants() do
		if piece:IsA("BasePart") then
			piece.Anchored = true -- une sorcière ne doit ni tomber ni être poussée
		end
	end

	-- Position : Reglages.Sorciere.Position (repère de la parcelle), le bas de la Base sur le sol
	local hauteur = usine.Sol.Size.Y / 2 + base.Size.Y / 2
	local position = (usine.Sol.CFrame * CFrame.new(REGLAGES.Position + Vector3.new(0, hauteur, 0))).Position
	-- Orientation : debout, face au point d'entrée de la parcelle (la Part "Apparition"),
	-- en ne tournant qu'autour de l'axe vertical
	local apparition = usine:FindFirstChild("Apparition")
	local regard = if apparition
		then Vector3.new(apparition.Position.X, position.Y, apparition.Position.Z)
		else position + usine.Sol.CFrame.LookVector -- sinon : vers le côté -Z (l'entrée) de la parcelle
	copie:PivotTo(CFrame.lookAt(position, regard))
	local dossier = Instance.new("Folder")
	dossier.Name = "PNJ"
	dossier.Parent = usine
	copie.Parent = dossier
	return copie
end

-- Fumée et son au-dessus du chaudron pendant la mise en scène
local function mettreEnScene(pnj)
	local chaudron = pnj and pnj:FindFirstChild("Chaudron", true)
	if chaudron == nil then
		return
	end
	local fumee = chaudron:FindFirstChildOfClass("Smoke")
	if fumee == nil then
		fumee = Instance.new("Smoke")
		fumee.Color = Color3.fromHex("B9F5A0")
		fumee.Opacity = 0.35
		fumee.RiseVelocity = 4
		fumee.Size = 2
		fumee.Enabled = false
		fumee.Parent = chaudron
	end
	fumee.Enabled = true
	local son = Instance.new("Sound")
	son.SoundId = REGLAGES.Son.Id
	son.Volume = REGLAGES.Son.Volume
	son.PlaybackSpeed = REGLAGES.Son.Vitesse
	son.RollOffMaxDistance = 60
	son.Parent = chaudron
	son:Play()
	task.delay(REGLAGES.DureeMiseEnScene, function()
		fumee.Enabled = false
		son:Destroy()
	end)
end

function Sorciere.demarrer(joueur, usine, donnees)
	local pitie = {}
	if typeof(donnees.PitieSorciere) == "table" then
		for nomRarete, echecs in donnees.PitieSorciere do
			if Rarete.rang(nomRarete) and typeof(echecs) == "number" and echecs >= 0 then
				pitie[nomRarete] = math.floor(echecs)
			end
		end
	end
	local etat = { usine = usine, pitie = pitie, enCours = false }
	etats[joueur] = etat

	etat.pnj = poserSorciere(usine)
	local prompt = etat.pnj and etat.pnj:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.Triggered:Connect(function(qui)
			if qui == joueur then -- seul le propriétaire parle à SA sorcière
				ouvrirSorciere:FireClient(joueur, { Pitie = table.clone(etat.pitie) })
			end
		end)
	end
end

function Sorciere.arreter(joueur)
	etats[joueur] = nil
end

-- Panneau de debug (seulement dans Studio) : impose le résultat de la PROCHAINE
-- transformation du joueur (true = réussite, false = échec). Renvoie true si c'est noté.
function Sorciere.imposerResultat(joueur, reussite)
	local etat = etats[joueur]
	if etat == nil or not RunService:IsStudio() or typeof(reussite) ~= "boolean" then
		return false
	end
	etat.resultatImpose = reussite
	return true
end

-- Ce qu'il faut sauvegarder : { [rareté donnée] = échecs de suite }
function Sorciere.lire(joueur)
	local etat = etats[joueur]
	return etat and table.clone(etat.pitie)
end

-- Vérifie une demande. Renvoie la rareté donnée et le compte par pile, ou nil + raison.
local function verifierDemande(joueur, etat, cles)
	if etat.enCours then
		return nil, "Patience, le chaudron bout encore !"
	end
	if typeof(cles) ~= "table" or #cles ~= 3 then
		return nil, "Il me faut exactement 3 bonbons."
	end
	-- Il faut être près de la sorcière
	local personnage = joueur.Character
	local racine = personnage and personnage:FindFirstChild("HumanoidRootPart")
	local prompt = etat.pnj and etat.pnj:FindFirstChild("Prompt", true)
	if racine == nil or prompt == nil or (racine.Position - prompt.Position).Magnitude > REGLAGES.DistanceMax then
		return nil, "Approche-toi du chaudron !"
	end

	local rareteDonnee = nil
	local parPile = {}
	for i = 1, 3 do
		local cle = cles[i]
		local typeBonbon, nomRarete = Inventaire.lireCle(cle)
		if typeBonbon == nil or typeBonbon == REGLAGES.TypeRate then
			return nil, "Je ne travaille pas avec ça."
		end
		if rareteDonnee ~= nil and nomRarete ~= rareteDonnee then
			return nil, "Les 3 bonbons doivent avoir la même rareté."
		end
		rareteDonnee = nomRarete
		parPile[cle] = (parPile[cle] or 0) + 1
	end
	local rangCible = Rarete.rang(rareteDonnee) + 1
	if RARETES[rangCible] == nil then
		return nil, "Un Mythique ? Même moi, je ne fais pas mieux."
	end
	for cle, nombre in parPile do
		if Inventaire.quantite(joueur, cle) < nombre then
			return nil, "Tu n'as pas tous ces bonbons."
		end
	end
	return rareteDonnee, parPile
end

muter.OnServerEvent:Connect(function(joueur, cles)
	local etat = etats[joueur]
	if etat == nil then
		return
	end
	local rareteDonnee, parPile = verifierDemande(joueur, etat, cles)
	if rareteDonnee == nil then
		resultat:FireClient(joueur, { Accepte = false, Message = parPile, Pitie = table.clone(etat.pitie) })
		return
	end

	-- === Échange d'un seul bloc (aucune attente jusqu'à la fin de ce bloc) ===
	local totalAvant = Inventaire.total(joueur)
	for cle, nombre in parPile do
		Inventaire.retirer(joueur, cle, nombre)
	end
	if Inventaire.total(joueur) ~= totalAvant - 3 then
		-- Ne devrait jamais arriver (tout a été vérifié juste avant) : on rend tout
		warn("Sorcière : quantités incohérentes pour " .. joueur.Name .. ", annulation")
		for cle, nombre in parPile do
			for _ = 1, nombre do
				Inventaire.ajouter(joueur, cle)
			end
		end
		resultat:FireClient(joueur, { Accepte = false, Message = "Mon chaudron a fait des siennes, rien n'a changé.", Pitie = table.clone(etat.pitie) })
		return
	end

	local rareteVisee = RARETES[Rarete.rang(rareteDonnee) + 1].Nom
	local echecs = etat.pitie[rareteDonnee] or 0
	local garantie = echecs >= REGLAGES.EchecsAvantGarantie
	local reussi = garantie or aleatoire:NextNumber() * 100 < (REGLAGES.Taux[rareteVisee] or 0)
	-- Panneau de debug (seulement dans Studio) : résultat imposé, utilisé une seule fois
	if etat.resultatImpose ~= nil and RunService:IsStudio() then
		reussi = etat.resultatImpose
		garantie = false
		etat.resultatImpose = nil
	end

	local typeObtenu, rareteObtenue
	if reussi then
		-- Le type du nouveau bonbon est tiré parmi les 3 donnés
		typeObtenu = Inventaire.lireCle(cles[aleatoire:NextInteger(1, 3)])
		rareteObtenue = rareteVisee
		etat.pitie[rareteDonnee] = nil
		Carnet.decouvrir(joueur, typeObtenu, rareteObtenue)
	else
		typeObtenu = REGLAGES.TypeRate
		rareteObtenue = "Commun"
		etat.pitie[rareteDonnee] = echecs + 1
	end
	local cleObtenue = Inventaire.cle(typeObtenu, rareteObtenue, "Normal")
	Inventaire.ajouter(joueur, cleObtenue)
	if Inventaire.total(joueur) ~= totalAvant - 2 then
		warn("Sorcière : total inattendu après la transformation de " .. joueur.Name)
	end
	-- === Fin de l'échange ===

	etat.enCours = true
	mettreEnScene(etat.pnj)
	task.wait(REGLAGES.DureeMiseEnScene)
	etat.enCours = false
	if joueur.Parent == nil then
		return -- parti pendant la fumée : son inventaire est déjà à jour
	end
	resultat:FireClient(joueur, {
		Accepte = true,
		Reussi = reussi,
		Garanti = garantie,
		Type = typeObtenu,
		Rarete = rareteObtenue,
		Phrase = phraseAuHasard(if reussi then REGLAGES.Phrases.Reussite else REGLAGES.Phrases.Echec),
		Pitie = table.clone(etat.pitie),
	})
end)

return Sorciere
