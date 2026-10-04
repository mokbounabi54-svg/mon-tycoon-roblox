-- Les ingrédients des joueurs (mode hybride, voir docs/design_hybride.md).
--
-- Chaque joueur a deux réserves, rangées comme { Fraise = 12 } :
--   - le PANIER : ce qu'il porte sur lui (rempli par la récolte) ;
--   - le BAC (« Reserve » dans la sauvegarde) : la réserve de son usine, où les
--     mélangeurs prennent une fraise par bonbon (rempli quand il dépose son panier).
--
-- Ce module est le SEUL à modifier le panier et le bac. L'écran du joueur n'envoie
-- jamais de quantité : il ne peut que demander « renvoie-moi l'état ».
--
-- Les chiffres (capacités, cadeau...) sont dans Reglages.Hybride.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))

local REGLAGES = Reglages.Hybride
local INTERVALLE_ENVOI = 0.5 -- secondes minimum entre deux envois à l'écran (les mélangeurs consomment souvent)

-- Canaux avec l'écran : créés seulement si le mode hybride est actif, pour que le jeu
-- reste exactement le même quand il est éteint.
local majIngredients = nil -- serveur -> écran : { Panier, CapacitePanier, Reserve, CapaciteReserve }
if Reglages.HYBRIDE_ACTIF then
	majIngredients = Remotes.obtenir("IngredientsMaj")
end

-- etats[joueur] = { panier = {}, reserve = {}, cadeauRecu, derniereDemande, envoiPrevu }
local etats = {}

local Ingredients = {}

local function estUnEntierPositifOuNul(nombre)
	return typeof(nombre) == "number" and nombre >= 0 and nombre == math.floor(nombre) and nombre < math.huge
end

local function compter(reserve)
	local total = 0
	for _, quantite in reserve do
		total += quantite
	end
	return total
end

-- Vérifie une réserve venant de la sauvegarde et renvoie une version propre :
--   - un ingrédient inconnu (absent de Reglages.Hybride.Ingredients) est retiré ;
--   - une quantité qui n'est pas un entier ≥ 0 (texte, nombre à virgule, négatif, infini) est retirée ;
--   - une quantité trop grande est ramenée à la capacité.
-- "capaciteParIngredient" : maximum pour chaque ingrédient ; "capaciteTotale" : maximum pour
-- la somme (nil = pas de limite totale). "corrections" reçoit une ligne par correction faite.
-- (Rangée dans Ingredients pour pouvoir la tester toute seule.)
function Ingredients.nettoyer(reserve, capaciteParIngredient, capaciteTotale, corrections)
	local propre = {}
	if typeof(reserve) ~= "table" then
		if reserve ~= nil then
			table.insert(corrections, "pas une table (" .. typeof(reserve) .. ") : vidée")
		end
		return propre
	end
	for nom, quantite in reserve do
		if REGLAGES.Ingredients[nom] == nil then
			table.insert(corrections, "ingrédient inconnu '" .. tostring(nom) .. "' retiré")
		elseif not estUnEntierPositifOuNul(quantite) then
			table.insert(corrections, tostring(nom) .. " = " .. tostring(quantite) .. " : quantité invalide, retirée")
		elseif quantite > capaciteParIngredient then
			table.insert(corrections, tostring(nom) .. " = " .. quantite .. " : ramené à " .. capaciteParIngredient)
			propre[nom] = capaciteParIngredient
		elseif quantite > 0 then
			propre[nom] = quantite
		end
	end
	-- Total trop grand (plusieurs ingrédients) : on retire du plus gros d'abord
	if capaciteTotale then
		while compter(propre) > capaciteTotale do
			local plusGros, quantiteMax = nil, 0
			for nom, quantite in propre do
				if quantite > quantiteMax then
					plusGros, quantiteMax = nom, quantite
				end
			end
			local enTrop = compter(propre) - capaciteTotale
			local reste = math.max(quantiteMax - enTrop, 0)
			table.insert(corrections, plusGros .. " = " .. quantiteMax .. " : ramené à " .. reste .. " (total trop grand)")
			propre[plusGros] = if reste > 0 then reste else nil
		end
	end
	return propre
end

-- Lit le champ Ingredients d'une sauvegarde et renvoie une version propre :
-- { Panier, Reserve, CadeauRecu }. En cas de doute sur CadeauRecu (absent, pas un
-- booléen), on considère que le cadeau a déjà été donné : on ne le redonne jamais par erreur.
function Ingredients.lireSauvegarde(champ, corrections)
	if typeof(champ) ~= "table" then
		table.insert(corrections, "champ Ingredients absent ou abîmé : panier et bac vides, cadeau considéré comme reçu")
		champ = { CadeauRecu = true }
	end
	local cadeauRecu = champ.CadeauRecu
	if typeof(cadeauRecu) ~= "boolean" then
		table.insert(corrections, "CadeauRecu = " .. tostring(cadeauRecu) .. " : considéré comme reçu")
		cadeauRecu = true
	end
	return {
		Panier = Ingredients.nettoyer(champ.Panier, REGLAGES.CapacitePanier, REGLAGES.CapacitePanier, corrections),
		Reserve = Ingredients.nettoyer(champ.Reserve, REGLAGES.CapaciteReserve, nil, corrections),
		CadeauRecu = cadeauRecu,
	}
end

-- Envoie l'état à l'écran du joueur, au plus une fois toutes les INTERVALLE_ENVOI secondes
-- (les envois rapprochés sont regroupés en un seul).
local function envoyer(joueur)
	local etat = etats[joueur]
	if etat == nil or majIngredients == nil or etat.envoiPrevu then
		return
	end
	etat.envoiPrevu = true
	task.delay(INTERVALLE_ENVOI, function()
		if etats[joueur] ~= etat then
			return -- le joueur est parti entre-temps
		end
		etat.envoiPrevu = false
		majIngredients:FireClient(joueur, {
			Panier = table.clone(etat.panier),
			CapacitePanier = REGLAGES.CapacitePanier,
			Reserve = table.clone(etat.reserve),
			CapaciteReserve = REGLAGES.CapaciteReserve,
		})
	end)
end

-- Prépare les ingrédients d'un joueur qui arrive, à partir de sa sauvegarde (donnees.Ingredients).
-- Donne le cadeau de départ s'il ne l'a jamais reçu (seulement si le mode hybride est actif).
function Ingredients.demarrer(joueur, donnees)
	local corrections = {}
	local propre = Ingredients.lireSauvegarde(donnees.Ingredients, corrections)
	for _, correction in corrections do
		warn("Ingrédients de " .. joueur.Name .. " : " .. correction)
	end

	local etat = {
		panier = propre.Panier,
		reserve = propre.Reserve,
		cadeauRecu = propre.CadeauRecu,
		derniereDemande = 0,
		envoiPrevu = false,
	}
	etats[joueur] = etat

	if Reglages.HYBRIDE_ACTIF and not etat.cadeauRecu then
		local cadeau = REGLAGES.Cadeau
		local dejaLa = etat.reserve[cadeau.Ingredient] or 0
		etat.reserve[cadeau.Ingredient] = math.min(dejaLa + cadeau.Quantite, REGLAGES.CapaciteReserve)
		etat.cadeauRecu = true
		print("Cadeau de départ pour " .. joueur.Name .. " : " .. cadeau.Quantite .. " " .. cadeau.Ingredient .. " dans le bac")
	end
	envoyer(joueur)
end

-- Le joueur part : on oublie ses ingrédients (à appeler APRÈS avoir lu sa sauvegarde)
function Ingredients.arreter(joueur)
	etats[joueur] = nil
end

-- Ce qu'il faut sauvegarder : { Panier, Reserve, CadeauRecu } (nil si le joueur n'est pas prêt)
function Ingredients.lire(joueur)
	local etat = etats[joueur]
	if etat == nil then
		return nil
	end
	return { Panier = table.clone(etat.panier), Reserve = table.clone(etat.reserve), CadeauRecu = etat.cadeauRecu }
end

-- Quantité d'un ingrédient dans le bac (0 si rien, ou joueur inconnu)
function Ingredients.reserve(joueur, ingredient)
	local etat = joueur and etats[joueur]
	return etat and etat.reserve[ingredient] or 0
end

-- Ajoute au panier ce qui y tient (au plus "quantite"). Renvoie la quantité ajoutée.
function Ingredients.ajouterAuPanier(joueur, ingredient, quantite)
	local etat = etats[joueur]
	if etat == nil or REGLAGES.Ingredients[ingredient] == nil or not estUnEntierPositifOuNul(quantite) then
		return 0
	end
	local place = REGLAGES.CapacitePanier - compter(etat.panier)
	local ajoute = math.clamp(quantite, 0, math.max(place, 0))
	if ajoute > 0 then
		etat.panier[ingredient] = (etat.panier[ingredient] or 0) + ajoute
		envoyer(joueur)
	end
	return ajoute
end

-- Vide le panier dans le bac, autant que le bac peut en prendre (le reste reste dans le
-- panier : rien n'est jamais perdu). Renvoie le nombre d'ingrédients déposés.
function Ingredients.deposer(joueur)
	local etat = etats[joueur]
	if etat == nil then
		return 0
	end
	local depose = 0
	for ingredient, quantite in etat.panier do
		local place = REGLAGES.CapaciteReserve - (etat.reserve[ingredient] or 0)
		local transfert = math.min(quantite, math.max(place, 0))
		if transfert > 0 then
			etat.reserve[ingredient] = (etat.reserve[ingredient] or 0) + transfert
			local reste = quantite - transfert
			etat.panier[ingredient] = if reste > 0 then reste else nil
			depose += transfert
		end
	end
	if depose > 0 then
		envoyer(joueur)
	end
	return depose
end

-- Prend 1 ingrédient dans le bac (appelé par la production, une fois par bonbon).
-- Renvoie true s'il y en avait un.
function Ingredients.consommer(joueur, ingredient)
	local etat = joueur and etats[joueur]
	local quantite = etat and etat.reserve[ingredient] or 0
	if quantite <= 0 then
		return false
	end
	etat.reserve[ingredient] = if quantite > 1 then quantite - 1 else nil
	envoyer(joueur)
	return true
end

-- L'écran demande l'état (à son ouverture). Rien d'autre ne peut être demandé.
if Reglages.HYBRIDE_ACTIF then
	Remotes.obtenir("DemanderIngredients").OnServerEvent:Connect(function(joueur)
		local etat = etats[joueur]
		if etat == nil or os.clock() - etat.derniereDemande < REGLAGES.DelaiEntreDemandes then
			return
		end
		etat.derniereDemande = os.clock()
		envoyer(joueur)
	end)
end

return Ingredients
