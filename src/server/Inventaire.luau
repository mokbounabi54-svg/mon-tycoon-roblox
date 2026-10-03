-- L'inventaire des joueurs : les bonbons gardés au lieu d'être vendus.
--
-- Il est rangé en PILES : une pile par combinaison type + rareté + mutation,
-- avec une quantité. La clé d'une pile ressemble à "Fraise|Rare|Normal".
--   piles = { ["Fraise|Rare|Normal"] = 4, ["Menthe|Épique|Normal"] = 1 }
--
-- Ce module est le SEUL à modifier l'inventaire. L'écran du joueur ne fait
-- qu'envoyer des demandes (vendre, tout vendre, changer le seuil) : ici on vérifie
-- que la demande est possible (le joueur a-t-il ces bonbons ?) et on calcule le
-- prix nous-mêmes. Le joueur n'envoie jamais de prix.
--
-- Les chiffres (capacité, seuil par défaut...) sont dans Reglages.Inventaire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local Usine = script.Parent:WaitForChild("Usine")
local Rarete = require(Usine:WaitForChild("Rarete"))
local Prix = require(Usine:WaitForChild("Prix"))

local REGLAGES = Reglages.Inventaire
local COULEUR_MESSAGE_PLEIN = Color3.fromHex("FF8A1F")

-- Canaux avec l'écran des joueurs
local majInventaire = Remotes.obtenir("InventaireMaj") -- serveur -> écran : l'inventaire à jour
local demanderInventaire = Remotes.obtenir("DemanderInventaire") -- écran -> serveur
local vendreBonbons = Remotes.obtenir("VendreBonbons") -- écran -> serveur : (clé, quantité)
local toutVendre = Remotes.obtenir("ToutVendre") -- écran -> serveur
local choisirSeuil = Remotes.obtenir("ChoisirSeuil") -- écran -> serveur : (nom de rareté)
local annonce = Remotes.obtenir("Annonce")

-- L'écran du joueur ne voit pas ServerStorage : on copie les modèles de bonbons
-- dans ReplicatedStorage pour qu'il puisse en faire des icônes.
local modelesBonbons = ServerStorage:FindFirstChild("ModelesBonbons")
if modelesBonbons and not ReplicatedStorage:FindFirstChild("ModelesBonbons") then
	modelesBonbons:Clone().Parent = ReplicatedStorage
end

-- etats[joueur] = { usine, piles, seuil, derniereDemande, dernierMessagePlein }
local etats = {}

local Inventaire = {}

function Inventaire.cle(typeBonbon, nomRarete, mutation)
	return typeBonbon .. "|" .. nomRarete .. "|" .. (mutation or "Normal")
end

-- Découpe une clé "Type|Rareté|Mutation". Renvoie nil si elle n'est pas valable.
local function lireCle(cle)
	if typeof(cle) ~= "string" then
		return nil
	end
	local morceaux = string.split(cle, "|")
	local typeBonbon, nomRarete, mutation = morceaux[1], morceaux[2], morceaux[3]
	-- Un type connu, ou le « Bonbon raté » de la sorcière
	local typeConnu = Reglages.Types[typeBonbon] ~= nil or typeBonbon == Reglages.Sorciere.TypeRate
	if #morceaux ~= 3 or not typeConnu or Rarete.rang(nomRarete) == nil or Reglages.Mutations[mutation] == nil then
		return nil
	end
	return typeBonbon, nomRarete, mutation
end

local function compterBonbons(piles)
	local total = 0
	for _, quantite in piles do
		total += quantite
	end
	return total
end

local function estUnEntierPositif(nombre)
	return typeof(nombre) == "number" and nombre >= 1 and nombre == math.floor(nombre) and nombre < math.huge
end

local function trouverArgent(joueur)
	local leaderstats = joueur:FindFirstChild("leaderstats")
	return leaderstats and leaderstats:FindFirstChild("Argent")
end

-- Envoie l'inventaire à jour à l'écran du joueur, avec le prix de chaque pile
-- (calculé ici). "montantVendu" (optionnel) : ce qu'une vente vient de rapporter.
local function envoyer(joueur, montantVendu)
	local etat = etats[joueur]
	if etat == nil then
		return
	end
	local liste = {}
	for cle, quantite in etat.piles do
		local typeBonbon, nomRarete, mutation = lireCle(cle)
		table.insert(liste, {
			Cle = cle,
			Type = typeBonbon,
			Rarete = nomRarete,
			Mutation = mutation,
			Quantite = quantite,
			PrixUnitaire = Prix.calculer(etat.usine, typeBonbon, nomRarete, mutation),
		})
	end
	majInventaire:FireClient(joueur, {
		Piles = liste,
		Total = compterBonbons(etat.piles),
		Capacite = REGLAGES.Capacite,
		Seuil = etat.seuil,
		Vente = montantVendu,
	})
end

-- Prépare l'inventaire d'un joueur qui arrive, à partir de sa sauvegarde
-- (donnees.Inventaire et donnees.SeuilGarde). Les piles abîmées sont ignorées.
function Inventaire.demarrer(joueur, usine, donnees)
	local piles = {}
	if typeof(donnees.Inventaire) == "table" then
		for cle, quantite in donnees.Inventaire do
			if lireCle(cle) and estUnEntierPositif(quantite) then
				piles[cle] = quantite
			else
				warn("Inventaire de " .. joueur.Name .. " : pile '" .. tostring(cle) .. "' ignorée (abîmée)")
			end
		end
	end
	local seuil = donnees.SeuilGarde
	if not table.find(REGLAGES.ChoixSeuil, seuil) then
		seuil = REGLAGES.SeuilParDefaut
	end

	etats[joueur] = {
		usine = usine,
		piles = piles,
		seuil = seuil,
		derniereDemande = 0,
		dernierMessagePlein = -math.huge,
	}

	-- Le prix des piles change quand le joueur achète une machine : on renvoie l'inventaire
	usine:WaitForChild("Achats").ChildAdded:Connect(function()
		envoyer(joueur)
	end)
	envoyer(joueur)
end

-- Le joueur part : on oublie son inventaire (à appeler APRÈS avoir lu sa sauvegarde)
function Inventaire.arreter(joueur)
	etats[joueur] = nil
end

-- Ce qu'il faut sauvegarder : { Inventaire = { [clé] = quantité }, SeuilGarde = "..." }
function Inventaire.lire(joueur)
	local etat = etats[joueur]
	if etat == nil then
		return nil
	end
	return { Inventaire = table.clone(etat.piles), SeuilGarde = etat.seuil }
end

-- Appelé par le point de vente. Garde le bonbon dans l'inventaire si sa rareté
-- atteint le seuil du joueur et s'il reste de la place. Renvoie true s'il est gardé,
-- false s'il faut le vendre (rareté trop basse, inventaire plein, pas de joueur).
function Inventaire.essayerDeGarder(joueur, typeBonbon, nomRarete, mutation)
	local etat = joueur and etats[joueur]
	if etat == nil then
		return false
	end
	local rangBonbon = Rarete.rang(nomRarete)
	if rangBonbon == nil or rangBonbon < Rarete.rang(etat.seuil) then
		return false
	end
	local cle = Inventaire.cle(typeBonbon, nomRarete, mutation)
	if lireCle(cle) == nil then
		return false
	end

	if compterBonbons(etat.piles) >= REGLAGES.Capacite then
		-- Plein : le bonbon sera vendu (jamais perdu). On prévient, sans inonder l'écran.
		if os.clock() - etat.dernierMessagePlein >= REGLAGES.DelaiMessagePlein then
			etat.dernierMessagePlein = os.clock()
			annonce:FireClient(joueur, "Inventaire plein : les bonbons en trop sont vendus", COULEUR_MESSAGE_PLEIN)
		end
		return false
	end

	etat.piles[cle] = (etat.piles[cle] or 0) + 1
	envoyer(joueur)
	return true
end

--------------------------------------------------------------------------------
-- Pour la sorcière (module Sorciere) : lire, retirer et ajouter des bonbons
--------------------------------------------------------------------------------

Inventaire.lireCle = lireCle

-- Nombre de bonbons d'une pile (0 si le joueur n'en a pas)
function Inventaire.quantite(joueur, cle)
	local etat = etats[joueur]
	return etat and etat.piles[cle] or 0
end

-- Nombre total de bonbons du joueur (nil s'il n'a pas d'inventaire)
function Inventaire.total(joueur)
	local etat = etats[joueur]
	return etat and compterBonbons(etat.piles)
end

-- Retire "quantite" bonbons d'une pile. Renvoie false (sans rien retirer) s'il n'y en a pas assez.
function Inventaire.retirer(joueur, cle, quantite)
	local etat = etats[joueur]
	local possedes = etat and etat.piles[cle] or 0
	if etat == nil or not estUnEntierPositif(quantite) or quantite > possedes then
		return false
	end
	local reste = possedes - quantite
	etat.piles[cle] = if reste > 0 then reste else nil
	envoyer(joueur)
	return true
end

-- Ajoute 1 bonbon, sans regarder la capacité : la sorcière en retire toujours 3
-- avant d'en rendre 1, donc il y a forcément la place. Renvoie true si c'est fait.
function Inventaire.ajouter(joueur, cle)
	local etat = etats[joueur]
	if etat == nil or lireCle(cle) == nil then
		return false
	end
	etat.piles[cle] = (etat.piles[cle] or 0) + 1
	envoyer(joueur)
	return true
end

--------------------------------------------------------------------------------
-- Pour le panneau de debug (module PanneauDebug, seulement dans Studio)
--------------------------------------------------------------------------------

-- Remplit l'inventaire jusqu'à la capacité en ajoutant 1 bonbon à tour de rôle
-- dans chaque pile de "cles". Renvoie le nombre de bonbons ajoutés.
function Inventaire.remplir(joueur, cles)
	local etat = etats[joueur]
	if etat == nil or #cles == 0 then
		return 0
	end
	local ajoutes = 0
	local numero = 1
	while compterBonbons(etat.piles) < REGLAGES.Capacite do
		local cle = cles[numero]
		if lireCle(cle) then
			etat.piles[cle] = (etat.piles[cle] or 0) + 1
			ajoutes += 1
		end
		numero = numero % #cles + 1
		if ajoutes == 0 and numero == 1 then
			break -- aucune clé valable : on évite de tourner en rond
		end
	end
	envoyer(joueur)
	return ajoutes
end

-- Vide l'inventaire sans rien vendre. Renvoie le nombre de bonbons retirés.
function Inventaire.vider(joueur)
	local etat = etats[joueur]
	if etat == nil then
		return 0
	end
	local retires = compterBonbons(etat.piles)
	table.clear(etat.piles)
	envoyer(joueur)
	return retires
end

-- Une demande du joueur est acceptée si son inventaire existe et s'il n'en
-- envoie pas trop vite (anti-spam). Renvoie son état, ou nil.
local function accepterDemande(joueur)
	local etat = etats[joueur]
	if etat == nil then
		return nil
	end
	local maintenant = os.clock()
	if maintenant - etat.derniereDemande < REGLAGES.DelaiEntreDemandes then
		return nil
	end
	etat.derniereDemande = maintenant
	return etat
end

demanderInventaire.OnServerEvent:Connect(function(joueur)
	envoyer(joueur)
end)

-- Vendre "quantite" bonbons de la pile "cle"
vendreBonbons.OnServerEvent:Connect(function(joueur, cle, quantite)
	local etat = accepterDemande(joueur)
	if etat == nil then
		return
	end
	local typeBonbon, nomRarete, mutation = lireCle(cle)
	local possedes = if typeBonbon then etat.piles[cle] or 0 else 0
	local argent = trouverArgent(joueur)
	local prix = typeBonbon and Prix.calculer(etat.usine, typeBonbon, nomRarete, mutation)
	if argent == nil or prix == nil or not estUnEntierPositif(quantite) or quantite > possedes then
		envoyer(joueur) -- demande refusée : l'écran se remet à jour avec le vrai inventaire
		return
	end

	-- Rien ne peut s'intercaler ici (pas d'attente) : retrait et paiement vont ensemble
	local reste = possedes - quantite
	etat.piles[cle] = if reste > 0 then reste else nil
	local montant = prix * quantite
	argent.Value += montant
	envoyer(joueur, montant)
end)

-- Vendre tout l'inventaire (l'écran demande une confirmation avant, s'il y a des bonbons rares)
toutVendre.OnServerEvent:Connect(function(joueur)
	local etat = accepterDemande(joueur)
	local argent = etat and trouverArgent(joueur)
	if argent == nil then
		return
	end
	local montant = 0
	for cle, quantite in etat.piles do
		local typeBonbon, nomRarete, mutation = lireCle(cle)
		local prix = typeBonbon and Prix.calculer(etat.usine, typeBonbon, nomRarete, mutation)
		if prix then
			montant += prix * quantite
			etat.piles[cle] = nil
		end
	end
	argent.Value += montant
	envoyer(joueur, montant)
end)

-- Changer le seuil « Garder à partir de »
choisirSeuil.OnServerEvent:Connect(function(joueur, nomRarete)
	local etat = accepterDemande(joueur)
	if etat == nil then
		return
	end
	if table.find(REGLAGES.ChoixSeuil, nomRarete) then
		etat.seuil = nomRarete
	end
	envoyer(joueur)
end)

return Inventaire
