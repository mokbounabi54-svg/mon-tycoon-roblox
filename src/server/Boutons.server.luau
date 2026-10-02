-- Système de boutons d'achat.
--
-- Dans Studio :
--   Workspace/Boutons : un dossier qui contient les boutons (des Parts).
--                       Chaque bouton a un attribut "Prix" (nombre).
--   Workspace/Achats  : un dossier qui contient les objets à acheter, déjà placés
--                       à leur position finale. Chaque objet porte EXACTEMENT
--                       le même nom que son bouton.
--
-- Au lancement du jeu, les objets à acheter sont cachés. Quand un joueur marche
-- sur un bouton et a assez d'argent, on lui retire le prix, l'objet apparaît
-- à sa place et le bouton disparaît.

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local COULEUR_PAS_ASSEZ = Color3.fromRGB(255, 80, 80) -- clignotement si pas assez d'argent

local dossierBoutons = workspace:WaitForChild("Boutons")
local dossierAchats = workspace:WaitForChild("Achats")

-- Les objets pas encore achetés sont rangés ici, invisibles pour les joueurs
local achatsCaches = Instance.new("Folder")
achatsCaches.Name = "AchatsCaches"
achatsCaches.Parent = ServerStorage

for _, objet in dossierAchats:GetChildren() do
	objet.Parent = achatsCaches -- l'objet garde sa position pour plus tard
end

local function ajouterPanneau(bouton, prix)
	local panneau = Instance.new("BillboardGui")
	panneau.Size = UDim2.fromScale(6, 2)
	panneau.StudsOffset = Vector3.new(0, 3, 0)
	panneau.MaxDistance = 60
	panneau.Parent = bouton

	local texte = Instance.new("TextLabel")
	texte.Size = UDim2.fromScale(1, 1)
	texte.BackgroundTransparency = 1
	texte.TextScaled = true
	texte.Font = Enum.Font.FredokaOne
	texte.TextColor3 = Color3.fromRGB(255, 255, 255)
	texte.TextStrokeTransparency = 0
	texte.Text = bouton.Name .. "\n" .. prix .. " $"
	texte.Parent = panneau
end

local function preparerBouton(bouton)
	if not bouton:IsA("BasePart") then
		return
	end

	local prix = bouton:GetAttribute("Prix")
	if typeof(prix) ~= "number" then
		warn("Le bouton '" .. bouton.Name .. "' n'a pas d'attribut Prix (nombre) : ignoré")
		return
	end

	local objet = achatsCaches:FindFirstChild(bouton.Name)
	if objet == nil then
		warn("Aucun objet nommé '" .. bouton.Name .. "' dans Workspace/Achats : bouton ignoré")
		return
	end

	ajouterPanneau(bouton, prix)

	local couleurNormale = bouton.Color
	local achete = false
	local enAttente = false -- évite que le bouton clignote en boucle

	bouton.Touched:Connect(function(objetQuiTouche)
		if achete or enAttente then
			return
		end

		local joueur = Players:GetPlayerFromCharacter(objetQuiTouche.Parent)
		local leaderstats = joueur and joueur:FindFirstChild("leaderstats")
		local argent = leaderstats and leaderstats:FindFirstChild("Argent")
		if argent == nil then
			return
		end

		if argent.Value < prix then
			-- Pas assez d'argent : le bouton devient rouge une seconde
			enAttente = true
			bouton.Color = COULEUR_PAS_ASSEZ
			task.wait(1)
			bouton.Color = couleurNormale
			enAttente = false
			return
		end

		achete = true
		argent.Value -= prix
		objet.Parent = dossierAchats
		bouton:Destroy()
	end)
end

for _, bouton in dossierBoutons:GetChildren() do
	preparerBouton(bouton)
end
