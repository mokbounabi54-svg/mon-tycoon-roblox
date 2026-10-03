-- Le panneau de debug, côté serveur : SEULEMENT dans Studio (voir ModeDebug).
--
-- Il permet, pour tester vite :
--   - de se donner de l'argent (1 000, 100 000 ou 10 000 000 $) ;
--   - de débloquer une zone (Zone2, Zone3) sans payer ;
--   - d'imposer la rareté du PROCHAIN bonbon ;
--   - de remplir ou vider l'inventaire ;
--   - d'imposer la réussite ou l'échec de la PROCHAINE transformation de la sorcière.
--
-- Sécurité :
--   - si le mode debug n'est pas actif (jeu publié, ou attribut PanneauDebug absent),
--     ce module ne fait RIEN : le canal "Debug" n'est même pas créé, donc aucun
--     joueur ne peut lui envoyer de demande ;
--   - chaque demande est revérifiée (Studio, action connue, montant prévu dans la liste) ;
--   - en mode debug, la sauvegarde va dans un DataStore de test (voir ModeDebug et Sauvegarde).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Reglages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reglages"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local ModeDebug = require(script.Parent:WaitForChild("ModeDebug"))
local Remotes = require(script.Parent:WaitForChild("Remotes"))
local Inventaire = require(script.Parent:WaitForChild("Inventaire"))
local Sorciere = require(script.Parent:WaitForChild("Sorciere"))
local Rarete = require(script.Parent:WaitForChild("Usine"):WaitForChild("Rarete"))

-- Les seules valeurs acceptées (l'écran ne peut rien demander d'autre)
local MONTANTS = { 1000, 100000, 10000000 }
local ZONES = { "Zone2", "Zone3" }
local COULEUR_MESSAGE = Color3.fromHex("FF8A1F")

local PanneauDebug = {}

-- achatsGratuits[joueur] = la fonction qui pose un achat sans payer dans SON usine
local achatsGratuits = {}

-- Appelé par Parcelles quand l'usine d'un joueur est prête. Ne fait rien hors mode debug.
function PanneauDebug.brancher(joueur, acheterSansPayer)
	if ModeDebug.actif then
		achatsGratuits[joueur] = acheterSansPayer
	end
end

function PanneauDebug.debrancher(joueur)
	achatsGratuits[joueur] = nil
end

-- Hors mode debug : on s'arrête ici, sans créer de canal
if not ModeDebug.actif then
	return PanneauDebug
end

-- L'écran lit cet attribut pour savoir qu'il peut afficher le panneau (et le nom du DataStore)
ReplicatedStorage:SetAttribute("PanneauDebug", ModeDebug.nomDataStore)

local canal = Remotes.obtenir("Debug") -- écran -> serveur : (action, valeur)
local annonce = Remotes.obtenir("Annonce")

local function prevenir(joueur, texte)
	annonce:FireClient(joueur, "[Debug] " .. texte, COULEUR_MESSAGE)
end

-- Les clés utilisées pour remplir l'inventaire : chaque type, de Commun à Légendaire
-- (15 piles, environ 3 bonbons chacune : de quoi tester la sorcière)
local function clesPourRemplir()
	local cles = {}
	for rang = 1, #Reglages.Raretes - 1 do
		for _, typeBonbon in Reglages.OrdreTypes do
			table.insert(cles, Inventaire.cle(typeBonbon, Reglages.Raretes[rang].Nom, "Normal"))
		end
	end
	return cles
end

local actions = {}

function actions.Argent(joueur, montant)
	if not table.find(MONTANTS, montant) then
		return
	end
	local leaderstats = joueur:FindFirstChild("leaderstats")
	local argent = leaderstats and leaderstats:FindFirstChild("Argent")
	if argent then
		argent.Value += montant
		prevenir(joueur, "+" .. Format.nombre(montant) .. " $")
	end
end

function actions.Zone(joueur, nom)
	local acheter = achatsGratuits[joueur]
	if not table.find(ZONES, nom) or acheter == nil then
		return
	end
	if acheter(nom) then
		prevenir(joueur, nom .. " débloquée")
	else
		prevenir(joueur, nom .. " est déjà débloquée")
	end
end

function actions.Rarete(joueur, nom)
	if Rarete.forcerProchaine(joueur, nom) then
		prevenir(joueur, "Prochain bonbon : " .. nom)
	end
end

function actions.Inventaire(joueur, quoi)
	if quoi == "Remplir" then
		prevenir(joueur, Inventaire.remplir(joueur, clesPourRemplir()) .. " bonbon(s) ajouté(s)")
	elseif quoi == "Vider" then
		prevenir(joueur, Inventaire.vider(joueur) .. " bonbon(s) retiré(s)")
	end
end

function actions.Sorciere(joueur, quoi)
	if quoi ~= "Reussite" and quoi ~= "Echec" then
		return
	end
	if Sorciere.imposerResultat(joueur, quoi == "Reussite") then
		prevenir(joueur, "Prochaine transformation : " .. (if quoi == "Reussite" then "réussite" else "échec"))
	end
end

canal.OnServerEvent:Connect(function(joueur, action, valeur)
	-- Revérifié à chaque demande, au cas où
	if not ModeDebug.actif or not RunService:IsStudio() then
		return
	end
	local faire = typeof(action) == "string" and actions[action]
	if faire then
		faire(joueur, valeur)
	end
end)

Players.PlayerRemoving:Connect(PanneauDebug.debrancher)

return PanneauDebug
